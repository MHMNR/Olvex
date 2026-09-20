#!/usr/bin/env bash

# Recording script for Olvex using gpu-screen-recorder
# Usage: record [options]
# Options:
#   -r: Select region
#   -s: Include sound
#   -p: Toggle pause
#   --stop: Stop recording
#   (no args): Toggle recording fullscreen

REC_DIR="$HOME/Videos/Recordings"
mkdir -p "$REC_DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME="$REC_DIR/Recording_$TIMESTAMP.mp4"

# Handle toggle pause
if [ "$1" == "-p" ]; then
    PID=$(pidof gpu-screen-recorder)
    if [ -n "$PID" ]; then
        kill -SIGUSR2 "$PID"
        exit 0
    fi
    exit 1
fi

# Handle explicit stop
if [ "$1" == "--stop" ] || [ "$1" == "-q" ]; then
    pkill -f slurp 2>/dev/null || true
    if pidof gpu-screen-recorder > /dev/null; then
        killall -INT gpu-screen-recorder
    fi
    exit 0
fi

# If no args given and recorder is running, stop it
if [ $# -eq 0 ] && pidof gpu-screen-recorder > /dev/null; then
    killall -INT gpu-screen-recorder
    exit 0
fi

# If recorder is already running and user tries to start another, don't start duplicate
if pidof gpu-screen-recorder > /dev/null; then
    notify-send -a "olvex-recorder" -u low "Recorder" "Recording is already in progress" 2>/dev/null || true
    exit 0
fi

# Parse options
TARGET=""
AUDIO=""
FPS=60

while getopts "rsf:" opt; do
  case $opt in
    r)
      # Small sleep to allow shell drawers/overlays to close and release focus grab
      sleep 0.15
      # slurp returns "X Y W H"
      SLURP_OUT=$(slurp -d -f "%x %y %w %h")
      if [ -z "$SLURP_OUT" ]; then exit 1; fi
      
      read -r X Y W H <<< "$SLURP_OUT"
      
      # Ensure width and height are positive and even for video encoders
      W=$(( (W / 2) * 2 ))
      H=$(( (H / 2) * 2 ))
      if [ "$W" -le 0 ] || [ "$H" -le 0 ]; then exit 1; fi
      
      TARGET="${W}x${H}+${X}+${Y}"
      ;;
    s)
      # Use default audio output
      AUDIO="-a default_output"
      ;;
    f)
      FPS=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [ -z "$TARGET" ]; then
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        TARGET=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name' | head -n1)
    fi
    TARGET="${TARGET:-screen}"
fi

# Start recording
gpu-screen-recorder -w "$TARGET" -f "$FPS" $AUDIO -o "$FILENAME" &
GSR_PID=$!

sleep 0.3
if ! kill -0 "$GSR_PID" 2>/dev/null; then
    notify-send -a "olvex-recorder" -u critical "Recording failed" "gpu-screen-recorder failed to start" 2>/dev/null || true
    exit 1
fi

notify-send -a "olvex-recorder" -i "media-record" "Recording started" "Screen recording in progress..." 2>/dev/null || true

wait "$GSR_PID"
notify-send -a "olvex-recorder" -i "video-x-generic" "Recording saved" "Saved to $REC_DIR" 2>/dev/null || true
