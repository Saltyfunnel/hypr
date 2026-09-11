#!/usr/bin/env bash
# Requires: curl, jq (sudo pacman -S jq)

# Set your location explicitly - blank uses IP geolocation, which is
# unreliable behind VPNs/NAT and is likely why your temp was wrong.
LOCATION="Lhanbryde"

response=$(curl -s --max-time 5 "https://wttr.in/${LOCATION}?format=j1")

if [ -z "$response" ]; then
    echo '󰖐 N/A'
    exit 0
fi

code=$(echo "$response" | jq -r '.current_condition[0].weatherCode')
temp=$(echo "$response" | jq -r '.current_condition[0].temp_C')

if [ -z "$code" ] || [ "$code" = "null" ] || [ -z "$temp" ] || [ "$temp" = "null" ]; then
    echo '󰖐 N/A'
    exit 0
fi

case "$code" in
    113) icon="󰖙" ;;                                           # Clear/Sunny
    116) icon="󰖕" ;;                                           # Partly cloudy
    119|122) icon="󰖐" ;;                                       # Cloudy/Overcast
    143|248|260) icon="󰖑" ;;                                   # Fog/Mist
    176|263|266|293|296|299|302|305|308|311|314|317|350|353|356|359|362|365|368|371|374|377) icon="󰖗" ;; # Rain/Drizzle
    179|182|185|227|230|320|323|326|329|332|335|338|341|344) icon="󰖘" ;;                     # Snow
    200|386|389) icon="󰖓" ;;                                   # Thunder
    *) icon="󰼳" ;;                                             # Fallback
esac

echo "${icon} +${temp}°C"
