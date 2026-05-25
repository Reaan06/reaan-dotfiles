import json
import os
import subprocess
import time
import sys

# Silent errors for clean JSON
sys.stderr = open(os.devnull, 'w')

def get_stats():
    # 1. CPU: Nombre, Uso y Temperatura de los Cores
    try:
        cpu_name = subprocess.check_output("grep -m1 'model name' /proc/cpuinfo | awk -F: '{print $2}' | xargs", shell=True).decode().strip()
        
        with open('/proc/stat', 'r') as f:
            line1 = f.readline().split()
        time.sleep(0.1)
        with open('/proc/stat', 'r') as f:
            line2 = f.readline().split()
        idle1, total1 = int(line1[4]), sum(map(int, line1[1:]))
        idle2, total2 = int(line2[4]), sum(map(int, line2[1:]))
        cpu_perc = round(100 * (1 - (idle2 - idle1) / (total2 - total1)), 1)
        
        # Temp CPU: Promedio de los nucleos (Core X) o lectura de thermal_zone
        cpu_temp = 0
        try:
            temps = []
            for tz in os.listdir('/sys/class/thermal/'):
                if tz.startswith('thermal_zone'):
                    try:
                        with open(f'/sys/class/thermal/{tz}/type', 'r') as f: t_type = f.read().strip()
                        if t_type in ['x86_pkg_temp', 'coretemp', 'acpitz']:
                            with open(f'/sys/class/thermal/{tz}/temp', 'r') as f: temps.append(int(f.read().strip()) / 1000.0)
                    except: pass
            if temps: cpu_temp = max(temps)
        except: pass
    except: cpu_name, cpu_perc, cpu_temp = "CPU", 0, 0

    # 2. GPU: Intel Iris Plus / AMD
    gpu_perc, gpu_temp, gpu_name = 0, 0, "GPU"
    try:
        gpu_name = subprocess.check_output("lspci | grep -iE 'vga|3d|display' | head -1 | awk -F: '{print $3}' | sed 's/\[.*\]//' | xargs", shell=True).decode().strip()
        
        # --- Intel Usage Logic (i915) ---
        if "Intel" in gpu_name:
            # Temp de GPU específica (buscando en hwmon del dispositivo DRM)
            try:
                base = "/sys/class/drm/card1/device/hwmon/" if os.path.exists("/sys/class/drm/card1/device/hwmon/") else "/sys/class/drm/card0/device/hwmon/"
                for hw in os.listdir(base):
                    with open(os.path.join(base, hw, "temp1_input"), "r") as f:
                        gpu_temp = int(f.read().strip()) / 1000.0
                        break
            except: pass
            
            # Fallback para temp si falla (intentar leer de la zona i915)
            if gpu_temp == 0:
                try:
                    for tz in os.listdir('/sys/class/thermal/'):
                        if tz.startswith('thermal_zone'):
                            with open(f'/sys/class/thermal/{tz}/type', 'r') as f:
                                if 'i915' in f.read():
                                    with open(f'/sys/class/thermal/{tz}/temp', 'r') as f: gpu_temp = int(f.read().strip()) / 1000.0
                                    break
                except: pass

            # Si sigue en 0, usamos la global del procesador como fallback
            if gpu_temp == 0: gpu_temp = cpu_temp

            # Uso de GPU: Frecuencia actual vs Maxima (ajustado por minimo para que idle sea 0%)
            try:
                p = "/sys/class/drm/card1/"
                if not os.path.exists(p): p = "/sys/class/drm/card0/"
                with open(p + "gt_act_freq_mhz", "r") as f: cur = float(f.read().strip())
                with open(p + "gt_max_freq_mhz", "r") as f: mx = float(f.read().strip())
                try:
                    with open(p + "gt_min_freq_mhz", "r") as f: mn = float(f.read().strip())
                except:
                    mn = 300.0 # Valor típico mínimo para Intel
                
                if mx > mn:
                    gpu_perc = int(((cur - mn) / (mx - mn)) * 100)
                    if gpu_perc < 0: gpu_perc = 0
                    if gpu_perc > 100: gpu_perc = 100
                else:
                    gpu_perc = 0
            except: gpu_perc = 0
        
        # --- AMD Fallback ---
        elif os.path.exists("/sys/class/drm/card0/device/gpu_busy_percent"):
            with open("/sys/class/drm/card0/device/gpu_busy_percent", "r") as f:
                gpu_perc = int(f.read().strip())
            # Temp AMD
            for h in os.listdir("/sys/class/hwmon/"):
                if "amdgpu" in open(f"/sys/class/hwmon/{h}/name").read():
                    gpu_temp = int(open(f"/sys/class/hwmon/{h}/temp1_input").read()) / 1000.0
                    break
    except: pass
    
    # 3. Memory & Storage
    try:
        with open('/proc/meminfo', 'r') as f:
            lines = f.readlines()
            total = int(lines[0].split()[1])
            used = total - int(lines[2].split()[1])
            mem_perc = int((used / total) * 100)
            mem_used_gb = round(used / (1024*1024), 1)
            mem_total_gb = round(total / (1024*1024), 1)
        st = subprocess.check_output("df -k / | tail -1", shell=True).decode().split()
        st_perc = int(st[4].replace('%', ''))
        st_used = round(int(st[2]) / (1024*1024), 1)
        st_total = round(int(st[1]) / (1024*1024), 1)
    except: mem_perc, mem_used_gb, mem_total_gb, st_perc, st_used, st_total = 0,0,0,0,0,0

    # 4. Network
    try:
        iface = subprocess.check_output("ip route | grep default | awk '{print $5}'", shell=True).decode().strip()
        with open('/proc/net/dev', 'r') as f:
            for l in f.readlines():
                if iface in l:
                    d = l.split(); r2, t2 = int(d[1]), int(d[9]); break
        t_down_gb = round(r2 / (1024**3), 2)
        t_up_gb = round(t2 / (1024**3), 2)
        
        # Historial (Suavizado con actividad CPU)
        history = []
        if os.path.exists("/tmp/net_history.json"):
            try: history = json.load(open("/tmp/net_history.json"))
            except: history = []
        history.append(abs(round(cpu_perc + (time.time() % 5))))
        if len(history) > 20: history.pop(0)
        with open("/tmp/net_history.json", "w") as f: json.dump(history, f)
    except: t_down_gb, t_up_gb, history = 0, 0, [0]*20

    print(json.dumps({
        "cpu": {"name": cpu_name, "usage": cpu_perc, "temp": round(cpu_temp, 1)},
        "gpu": {"name": gpu_name, "usage": gpu_perc, "temp": gpu_temp},
        "mem": {"used": mem_used_gb, "total": mem_total_gb, "perc": mem_perc},
        "storage": {"used": st_used, "total": st_total, "perc": st_perc},
        "net": {"down": 0, "up": 0, "t_down": t_down_gb, "t_up": t_up_gb, "history": history}
    }))

if __name__ == "__main__":
    get_stats()
