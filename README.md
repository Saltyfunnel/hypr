# Hyprland Installer (2026 Edition)

An automated Arch Linux setup script that installs and configures a complete Hyprland desktop environment with dynamic hardware detection and custom theme integration.

---

## Previews

<p align="center">
  <img src="screenshot/1.jpg" alt="Desktop Preview 1" width="48%">
  <img src="screenshot/2.jpg" alt="Desktop Preview 2" width="48%">
</p>

---

## Features

* **GPU Auto-Detection:** Automatically detects Nvidia, AMD, or Intel graphics cards and installs appropriate drivers and Wayland environment variables.
* **No-AUR Pywal16:** Installs `pywal16` cleanly via `pipx` from PyPI.
* **Theme & Style Integration:** Configures GTK dark themes, installs Colloid Dynamic icons, and links dynamic Pywal colors for Waybar, Mako, and Zed.
* **Local AI Assistant (`chat.py`):** Includes a self-contained Python script to easily set up and run a local AI model on your machine.
* **Full Application Suite:** Sets up SDDM, Waybar, Mako, Kitty, Thunar, Starship, btop, and Fastfetch automatically.
* **Wallpapers Included:** Clones and deploys custom wallpaper collections on setup.

---

## System Requirements

* **OS:** Arch Linux (clean installation recommended)
* **Privileges:** Root / Sudo access
* **Package Manager:** `pacman` with active internet connection

---

## Configuration

### Clock & Weather Module Location
The Waybar `custom/clockweather` module fetches temperature via `wttr.in`. To change the location to your own city, replace `YOUR_CITY` in the command string below inside your Waybar configuration file:

```json
"custom/clockweather": {
    "exec": "python3 -c 'import datetime, urllib.request, subprocess; now=datetime.datetime.now().strftime(\"%H:%M\"); req=urllib.request.Request(\"https://wttr.in/YOUR_CITY?format=%t\", headers={\"User-Agent\": \"curl\"}); temp=urllib.request.urlopen(req, timeout=3).read().decode().strip(); cal=subprocess.check_output([\"cal\"], text=True); text=f\"{now}  󰖐  {temp}\"; import json; print(json.dumps({\"text\": text, \"tooltip\": cal}))'",
    "interval": 1800,
    "return-type": "json"
}
```

---

## Quick Start

```bash
git clone https://github.com/Saltyfunnel/hypr
cd hypr
chmod +x install.sh
sudo ./install.sh
```
