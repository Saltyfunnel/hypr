#!/bin/bash

cpu=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}')
mem=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')

temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
temp=$( [ -n "$temp" ] && echo $((temp/1000)) || echo "N/A")

class="normal"
if [ "$cpu" -gt 80 ]; then
  class="critical"
elif [ "$cpu" -gt 50 ]; then
  class="warning"
fi

echo "{\"text\":\"󰧑\",\"class\":\"$class\",\"tooltip\":\"CPU: ${cpu}%\nRAM: ${mem}%\nTemp: ${temp}°C\"}"
