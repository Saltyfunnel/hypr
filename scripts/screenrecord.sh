#!/bin/bash
OUT_DIR="$HOME/Videos/Recordings"
PIDFILE="/tmp/screenrecord.pid"
mkdir -p "$OUT_DIR"

start_recording() {
    local file="$OUT_DIR/recording_$(date +'%Y%m%d_%H%M%S').mp4"
    wf-recorder --geometry "$(slurp)" -f "$file" &
    echo $! > "$PIDFILE"
    notify-send "Screen Recorder" "Recording started..." -i media-record
}

stop_recording() {
    if [ -f "$PIDFILE" ]; then
        kill -INT "$(cat "$PIDFILE")"
        rm -f "$PIDFILE"
    else
        pkill -INT wf-recorder
    fi
    notify-send "Screen Recorder" "Recording saved." -i media-tape
}

case "$1" in
    toggle)
        if pgrep -x "wf-recorder" > /dev/null; then
            stop_recording
        else
            start_recording
        fi
        ;;
    status)
        if pgrep -x "wf-recorder" > /dev/null; then
            echo '{"text": "󰑊", "class": ["recording"], "tooltip": "Recording... Click to stop"}'
        else
            echo '{"text": "󰑊", "class": [""], "tooltip": "Click to start recording"}'
        fi
        ;;
    *)
        if pgrep -x "wf-recorder" > /dev/null; then
            stop_recording
        else
            start_recording
        fi
        ;;
esac
