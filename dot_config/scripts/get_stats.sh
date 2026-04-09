#!/bin/bash
# get_stats.sh — Get detailed system stats in JSON format

# CPU Info
CPU_NAME=$(lscpu | grep "Model name" | head -1 | awk -F: '{print $2}' | xargs)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
CPU_TEMP=$(sensors 2>/dev/null | grep -E "Package id 0|Core 0|temp1" | head -1 | awk '{print $4}' | sed 's/+//;s/°C//' || echo "0")

# GPU Info (Try AMD, then Intel, then NVIDIA)
GPU_NAME="N/A"
GPU_USAGE="0"
GPU_TEMP="0"

if [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then
    GPU_NAME=$(lspci | grep -i vga | head -1 | awk -F: '{print $3}' | xargs | sed 's/\[.*\]//')
    GPU_USAGE=$(cat /sys/class/drm/card0/device/gpu_busy_percent)
    GPU_TEMP=$(sensors 2>/dev/null | grep -iE "edge|junction|mem" | head -1 | awk '{print $2}' | sed 's/+//;s/°C//')
elif ls /sys/class/hwmon/hwmon*/name &>/dev/null && grep -q "amdgpu" /sys/class/hwmon/hwmon*/name; then
    HWMON=$(grep -l "amdgpu" /sys/class/hwmon/hwmon*/name | head -1 | xargs dirname)
    GPU_NAME=$(lspci | grep -i vga | head -1 | awk -F: '{print $3}' | xargs | sed 's/\[.*\]//')
    GPU_USAGE=$(cat $HWMON/device/gpu_busy_percent 2>/dev/null || echo "0")
    GPU_TEMP=$(cat $HWMON/temp1_input 2>/dev/null | awk '{print $1/1000}' || echo "0")
elif command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits)
    GPU_USAGE=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
    GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
else
    GPU_NAME=$(lspci | grep -i vga | head -1 | awk -F: '{print $3}' | xargs | sed 's/\[.*\]//')
fi

# Memory Info
MEM_TOTAL=$(free -g | grep Mem | awk '{print $2}')
MEM_USED=$(free -g | grep Mem | awk '{print $3}')
MEM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)
MEM_FRACTION=$(free -h | grep Mem | awk '{print $3 "/" $2}' | sed 's/i//g')

# Storage Info
DISK_NAME=$(df / | tail -1 | awk '{print $1}' | awk -F/ '{print $NF}')
DISK_TOTAL=$(df -h / | tail -1 | awk '{print $2}' | sed 's/i//g')
DISK_USED=$(df -h / | tail -1 | awk '{print $3}' | sed 's/i//g')
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

# Network Info (Approximate by reading /proc/net/dev)
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
R1=$(cat /proc/net/dev | grep $IFACE | awk '{print $2}')
T1=$(cat /proc/net/dev | grep $IFACE | awk '{print $10}')
sleep 0.5
R2=$(cat /proc/net/dev | grep $IFACE | awk '{print $2}')
T2=$(cat /proc/net/dev | grep $IFACE | awk '{print $10}')

DOWN=$(( (R2 - R1) * 2 / 1024 )) # KB/s
UP=$(( (T2 - T1) * 2 / 1024 ))   # KB/s

# Build JSON
jq -n \
  --arg cn "$CPU_NAME" --arg cu "$CPU_USAGE" --arg ct "$CPU_TEMP" \
  --arg gn "$GPU_NAME" --arg gu "$GPU_USAGE" --arg gt "$GPU_TEMP" \
  --arg mu "$MEM_USAGE" --arg mf "$MEM_FRACTION" \
  --arg dn "$DISK_NAME" --arg du "$DISK_USAGE" --arg dt "$DISK_TOTAL" --arg dus "$DISK_USED" \
  --arg nd "$DOWN" --arg nu "$UP" \
  '{
    cpu: { name: $cn, usage: ($cu|tonumber|floor), temp: ($ct|tonumber|floor) },
    gpu: { name: $gn, usage: ($gu|tonumber|floor), temp: ($gt|tonumber|floor) },
    memory: { usage: ($mu|tonumber), fraction: $mf },
    storage: { name: $dn, usage: ($du|tonumber), total: $dt, used: $dus },
    network: { down: ($nd|tonumber), up: ($nu|tonumber) }
  }'
