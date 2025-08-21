#!/bin/bash
# Generate fastfetch config dynamically from Pywal colors + custom text

USER_HOME=$(eval echo "~$USER")
FF_CONFIG="$USER_HOME/.config/fastfetch/fastfetch.config.jsonc"

# Load pywal colors
colors=()
while read -r line; do
    colors+=("${line}")
done < <(grep '^color[0-9]' "$USER_HOME/.cache/wal/colors" | awk '{print $2}')

# Convert hex to RGB
hex_to_rgb() {
    hex=$1
    r=$((16#${hex:1:2}))
    g=$((16#${hex:3:2}))
    b=$((16#${hex:5:2}))
    echo "$r;$g;$b"
}

for i in {0..7}; do
    eval "color${i}_rgb=$(hex_to_rgb ${colors[i]})"
done

# Write the fastfetch config
cat > "$FF_CONFIG" <<EOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "builtin",
    "source": "arch",
    "padding": { "top": 1, "left": 4 },
    "color": { "1": "${color5}" }
  },
  "display": { "separator": "\\u001b[38;2;248;248;242m : " },
  "modules": [
    { "type": "custom", "format": "  \\u001b[38;2;189;147;249m               " },
    { "type": "custom", "format": "" },
    { "type": "custom", "format": "  \\u001b[38;2;80;250;123m   My conscience is clean — I have never used it.  " },
    { "type": "custom", "format": "" },
    { "type": "os", "key": "\\u001b[38;2;139;233;253m   OS" },
    { "type": "kernel", "key": "\\u001b[38;2;189;147;249m   Kernel" },
    { "type": "packages", "key": "\\u001b[38;2;139;233;253m  󰏗 Packages" },
    { "type": "display", "key": "\\u001b[38;2;255;184;108m  󱍜 Display" },
    { "type": "wm", "key": "\\u001b[38;2;189;147;249m   WM" },
    { "type": "terminal", "key": "\\u001b[38;2;80;250;123m   Terminal" },
    { "type": "media", "key": "\\u001b[38;2;139;233;253m  󰝚 Music" },
    { "type": "command", "key": "\\u001b[38;2;255;184;108m  󱦟 OS Age", "text": "birth_install=\$(stat -c %W /); current=\$(date +%s); time_progression=\$((current - birth_install)); days_difference=\$((time_progression / 86400)); echo \$days_difference days" },
    { "type": "uptime", "key": "\\u001b[38;2;139;233;253m  " },
    { "type": "custom", "format": "\\u001b[38;2;255;121;198m  󰊤 GitHub : Saltyfunnel" },
    { "type": "battery", "key": "\\u001b[38;2;255;184;108m   Battery" },
    "break",
    { "type": "title", "key": "\\u001b[38;2;189;147;249m   User" },
    { "type": "custom", "format": "" },
    { "type": "cpu", "format": "{1}", "keyColor": "\\u001b[38;2;189;147;249m" },
    { "type": "gpu", "format": "{2}", "keyColor": "\\u001b[38;2;139;233;253m" },
    { "type": "gpu", "format": "{3}", "keyColor": "\\u001b[38;2;255;184;108m" },
    { "type": "memory", "key": "\\u001b[38;2;189;147;249m   Memory" },
    { "type": "custom", "format": "" },
    "break",
    { "type": "custom", "format": "  \\u001b[38;2;189;147;249m               " },
    "break"
  ]
}
EOF

echo "✅ Fastfetch config regenerated from Pywal colors"
