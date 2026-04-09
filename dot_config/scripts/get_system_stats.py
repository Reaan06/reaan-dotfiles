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
        
        # Temp CPU: Promedio de los nucleos (Core X)
        cpu_temp = 0
        core_temps = []
        sensors_out = subprocess.check_output("sensors", shell=True).decode()
        for line in sensors_out.split('\n'):
            if 'Core' in line and ':' in line:
                try:
                    t = float(line.split(':')[1].split('(')[0].replace('+', '').replace('°C', '').strip())
                    core_temps.append(t)
                except: pass
        cpu_temp = sum(core_temps) / len(core_temps) if core_temps else 0
    except: cpu_name, cpu_perc, cpu_temp = "CPU", 0, 0

    # 2. GPU: Intel Iris Plus / AMD
    gpu_perc, gpu_temp, gpu_name = 0, 0, "GPU"
    try:
        gpu_name = subprocess.check_output("lspci | grep -iE 'vga|3d|display' | head -1 | awk -F: '{print $3}' | sed 's/\[.*\]//' | xargs", shell=True).decode().strip()
        
        # --- Intel Usage Logic (i915) ---
        if "Intel" in gpu_name:
            # En Intel, el Package Temp es la temp real de la iGPU
            sensors_out = subprocess.check_output("sensors", shell=True).decode()
            for line in sensors_out.split('\n'):
                if 'Package id 0' in line:
                    gpu_temp = float(line.split(':')[1].split('(')[0].replace('+', '').replace('°C', '').strip())
                    break
            
            # Uso de GPU: Frecuencia actual vs Maxima
            try:
                # Buscamos la card correcta (usualmente card1 en tu sistema)
                p = "/sys/class/drm/card1/"
                if not os.path.exists(p): p = "/sys/class/drm/card0/"
                
                with open(p + "gt_act_freq_mhz", "r") as f: cur = int(f.read().strip())
                with open(p + "gt_max_freq_mhz", "r") as f: mx = int(f.read().strip())
                gpu_perc = int((cur / mx) * 100) if mx > 0 else 0
            except: gpu_perc = 0
        
        # --- AMD Fallback ---
        elif os.path.exists("/sys/class/drm/card0/device/gpu_busy_percent"):
            with open("/sys/class/drm/card0/device/gpu_busy_percent", "r") as f:
                gpu_perc = int(f.read().strip())
            # Temp AMD
            for h in os.listdir("/sys/class/hwmon/"):
                if "amdgpu" in open(f"/sys/class/hwmon/{h}/name").read():
                    gpu_temp = int(open(f"/sys/class/hwmon/{h}/temp1_input").read()) / 1000
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
