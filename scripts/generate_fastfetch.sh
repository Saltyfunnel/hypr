#!/bin/bash
# Generate fastfetch config based on Pywal colors

USER_HOME=$(eval echo "~$USER")
FF_CONFIG="$USER_HOME/.config/fastfetch/fastfetch.config.jsonc"

# Parse colors from wal
for i in {0..7}; do
    hex=$(grep "color$i" "$USER_HOME/.cache/wal/colors" | awk '{print $2}')
    r=$((16#${hex:1:2}))
    g=$((16#${hex:3:2}))
    b=$((16#${hex:5:2}))
    eval "color${i}_rgb='${r};${g};${b}'"
done

# Write fastfetch config dynamically
cat > "$FF_CONFIG" <<EOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "builtin",
    "source": "arch",
    "padding": { "top": 1, "left": 4 },
    "color": { "1": "${color5}" }
  },
  "display": { "separator": "\\u001b[38;2;${color7_rgb}m : " },
  "modules": [
    { "type": "os", "key": "\\u001b[38;2;${color3_rgb}m   OS" },
    { "type": "kernel", "key": "\\u001b[38;2;${color5_rgb}m   Kernel" },
    { "type": "packages", "key": "\\u001b[38;2;${color3_rgb}m  󰏗 Packages" },
    { "type": "display", "key": "\\u001b[38;2;${color4_rgb}m  󱍜 Display" },
    { "type": "wm", "key": "\\u001b[38;2;${color5_rgb}m   WM" },
    { "type": "terminal", "key": "\\u001b[38;2;${color2_rgb}m   Terminal" },
    { "type": "memory", "key": "\\u001b[38;2;${color5_rgb}m   Memory" },
    { "type": "battery", "key": "\\u001b[38;2;${color4_rgb}m   Battery" }
  ]
}
EOF

echo "✅ Fastfetch config generated at $FF_CONFIG"
