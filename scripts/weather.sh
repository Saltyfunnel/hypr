#!/usr/bin/env bash
LOCATION="Lhanbryde"
response=$(curl -s -k --max-time 5 -A "curl" "https://wttr.in/${LOCATION}?format=j1")
if [ -z "$response" ]; then
    echo "󰖐 N/A"
    exit 0
fi
code=$(echo "$response" | jq -r ".current_condition[0].weatherCode")
temp=$(echo "$response" | jq -r ".current_condition[0].temp_C")
if [ -z "$code" ] || [ "$code" = "null" ] || [ -z "$temp" ] || [ "$temp" = "null" ]; then
    echo "󰖐 N/A"
    exit 0
fi
case "$code" in
    113) icon="󰖙" ;;
    116) icon="󰖕" ;;
    119|122) icon="󰖐" ;;
    143|248|260) icon="󰖑" ;;
    176|263|266|293|296|299|302|305|308|311|314|317|350|353|356|359|362|365|368|371|374|377) icon="󰖗" ;;
    179|182|185|227|230|320|323|326|329|332|335|338|341|344) icon="󰖘" ;;
    200|386|389) icon="󰖓" ;;
    *) icon="󰼳" ;;
esac
echo "${icon} +${temp}°C"
