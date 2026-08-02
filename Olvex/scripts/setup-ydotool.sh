#!/bin/bash
# Setup ydotool for Olvex OSK modifier/Super support.
# Run once after install.

set -e

echo "[1/4] Ensure input group exists..."
if ! getent group input >/dev/null; then
  sudo groupadd input
fi

echo "[2/4] Add current user to input group..."
sudo usermod -aG input "$USER"

echo "[3/4] Install /dev/uinput rule..."
sudo tee /etc/udev/rules.d/80-uinput.rules >/dev/null <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
EOF
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "[4/4] Enable ydotool user service..."
SVC="ydotoold.service"
if ! systemctl --user list-unit-files | grep -q "^ydotoold"; then
  SVC="ydotool.service"
fi
systemctl --user daemon-reload
systemctl --user enable "$SVC"
systemctl --user reset-failed "$SVC" || true
systemctl --user restart "$SVC" || true

echo
echo "Done."
echo "Relogin required for input-group change."
echo "Then verify with:"
echo "  systemctl --user status ydotool.service"
echo "  ydotool key 29:1 29:0"
