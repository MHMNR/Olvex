#!/usr/bin/env bash

# Recording script for Olvex using gpu-screen-recorder
# Usage: record [options]
# Options:
#   -r: Select region
#   -s: Include sound
#   -p: Toggle pause
#   (no args): Fullscreen, no sound

REC_DIR="$HOME/Videos/Recordings"
mkdir -p "$REC_DIR"


TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME="$REC_DIR/Recording_$TIMESTAMP.mp4"

# Handle toggle pause
if [ "$1" == "-p" ]; then
    PID=$(pidof gpu-screen-recorder)
    if [ -n "$PID" ]; then
        kill -SIGUSR1 "$PID"
        exit 0
    fi
    exit 1
fi

# Handle stop
if pidof gpu-screen-recorder > /dev/null; then
    killall -INT gpu-screen-recorder
    exit 0
fi

# Parse options
TARGET=""
REGION_GEOM=""
AUDIO=""
FPS=60

while getopts "rsf:" opt; do
  case $opt in
    r)
      # slurp returns "X,Y WxH"
      SLURP_OUT=$(slurp)
      if [ -z "$SLURP_OUT" ]; then exit 1; fi
      
      # Convert "X,Y WxH" to "WxH+X+Y"
      X=$(echo "$SLURP_OUT" | cut -d',' -f1)
      Y=$(echo "$SLURP_OUT" | cut -d',' -f2 | cut -d' ' -f1)
      W=$(echo "$SLURP_OUT" | cut -d' ' -f2 | cut -d'x' -f1)
      H=$(echo "$SLURP_OUT" | cut -d' ' -f2 | cut -d'x' -f2)
      
      TARGET="region"
      REGION_GEOM="-region ${W}x${H}+${X}+${Y}"
      ;;
    s)
      # Get default sink monitor
      DEFAULT_SINK=$(pactl get-default-sink)
      AUDIO="-a $DEFAULT_SINK.monitor"
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
# Note: Using $FPS for dynamic control
gpu-screen-recorder -w "$TARGET" $REGION_GEOM -f "$FPS" $AUDIO -o "$FILENAME" &
