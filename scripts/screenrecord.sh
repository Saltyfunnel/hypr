#!/bin/bash
OUT_DIR="$HOME/Videos/Recordings"
mkdir -p "$OUT_DIR"

refresh_bar() { pkill -RTMIN+8 waybar; }

start_recording() {
    local geom file
    geom=$(slurp) || return          # selection cancelled -> do nothing
    file="$OUT_DIR/recording_$(date +'%Y%m%d_%H%M%S').mp4"

    notify-send "Screen Recorder" "Recording started..." -i media-record
    (
        wf-recorder --geometry "$geom" -f "$file"
        notify-send "Screen Recorder" "Recording saved." -i media-tape
        refresh_bar
    ) &
    sleep 0.3                        # let wf-recorder start so status sees it
    refresh_bar
}

stop_recording() {
    pkill -INT -x wf-recorder        # subshell above notifies and refreshes once it exits
}

case "$1" in
    status)
        if pgrep -x wf-recorder >/dev/null; then
            echo '{"text": "󰑊", "class": "recording", "tooltip": "Recording... Click to stop"}'
        else
            echo '{"text": "󰑊", "class": "", "tooltip": "Click to start recording"}'
        fi
        ;;
    *)  # toggle (or no argument)
        if pgrep -x wf-recorder >/dev/null; then
            stop_recording
        else
            start_recording
        fi
        ;;
esac
