# ☕ Saltyfunnel’s Hyprland Config

*(Lovingly duct-taped together by me, technically typed by ChatGPT)*

## 🖼️ Screenshots

### **The Pywal Dynamic**
A demonstration of how the **`setwall.sh`** script automatically changes the system's color scheme (Waybar, Terminal, and Pickers) to match the wallpaper, showcasing the fluid nature of the config.

#### **Example 1: Tiled Windows and Waybar**
This shows the clean default layout with Hyprland tiling, the Waybar, and the dynamically generated color scheme.
![Tiled Windows and Dynamic Theme](screenshots/screenshot_2025-12-11_21-40-36.jpg)

#### **Example 2: Theme Change Example (Wallpaper 1)**
A view demonstrating a complete color shift based on a high-contrast wallpaper.
![Pywal Theme Shift Example 1](screenshots/screenshot_2025-12-11_21-41-11.jpg)

#### **Example 3: Theme Change Example (Wallpaper 2)**
Another example of the full system color palette adjusting to a different background image.
![Pywal Theme Shift Example 2](screenshots/screenshot_2025-12-11_21-39-49.jpg)

#### **Example 4: Theme Change Example (Wallpaper 3)**
A simple, minimal aesthetic generated from a monochrome wallpaper.
![Minimal Theme Shift Example](screenshots/screenshot_2025-12-11_21-40-07.jpg)

### **The Custom Picker**
A shot of the homemade PyQt6 Wallpaper Picker in action, which sends the chosen image to the Pywal theme generation script.
![Custom Wallpaper Picker GUI](screenshots/screenshot_2025-12-11_21-41-22.jpg)

## 🧠 What This Repo *Really* Is

This is not a professional Hyprland configuration.
This is a museum exhibit of “I saw this in a screenshot and wanted it too,” built using:

* 10% effort
* 30% stubborn googling
* 60% hoping AI knows what it’s doing

The result is a setup that *looks* clean and minimal… as long as you don’t read the scripts or ask how anything works.

If it runs: credit the robots.
If it doesn’t: I was never here, I deny everything.

## 💡 Startup Notes (a.k.a. How to Ruin Your Day Early)

In `hyprland.conf` there’s a line that runs `setwall.sh` on launch to generate a theme automatically.

I commented it out because I value mental health.
If you want chaos and color changes the moment you log in, just remove the `#`.

It’s your funeral now.

## 🧩 The Stack (AKA “Things I Installed And Pray Don’t Update”)

| Tool           | Description                                                                     |
| -------------- | ------------------------------------------------------------------------------- |
| Hyprland       | The compositor, the only thing here that isn't held together by string and luck |
| swww           | The wallpaper thingy                                                            |
| mako           | For notifications when everything breaks                                        |
| python-pywal16 | The color generator controlling the mood swings                                 |
| PyQt6          | Used for custom GUI pickers nobody asked for                                    |
| Waybar         | The bar that changes themes more often than some people change underwear        |
| Yazi           | File manager that also gets re-themed because why not                           |

## 🛠 The Scripts (Where the Crimes Are Committed)

Everything lives in `~/.config/scripts/` because that felt right at the time.

### 1. `install.sh`

An Arch Linux setup script that:

* Installs dependencies
* Copies configs
* Asks the user to run it with `sudo`, which is always safe and never dangerous at all

Please read it before running. Or don’t. I’m not your mom.

### 2. `setwall.sh`

The “core logic,” if you can call it that. It:

* Picks a wallpaper (or grabs a random one because chaos)
* Runs pywal to generate a palette
* Force-rewrites configs for Waybar, Yazi, and Mako
* Reloads them and hopes nothing crashes

It’s basically a color-themed Rube Goldberg machine.

### 3. `wallpaper-picker.py` & `app-picker.py`

Two PyQt6 scripts replacing good, working tools with homemade knockoffs that match the theme:

* **Wallpaper Picker**: Browse wallpapers and send the chosen one into the theme grinder
* **App Picker**: A Pywal-themed launcher with “please work” energy

## ⌨️ Keybinds

| Shortcut          | What It Does                      | Script              |
| ----------------- | --------------------------------- | ------------------- |
| SUPER + w         | Launch wallpaper picker           | wallpaper-picker.py |
| SUPER + Space     | Launch app picker                 | app-picker.py       |
| SUPER + Shift + s | Screenshot with mako notification | Helper script       |

## ⚠️ Installation

If you’re not on Arch, just stop now.
If you *are* on Arch… still maybe think about your life choices.

```bash
git clone https://github.com/Saltyfunnel/hypr
cd hypr
chmod +x scripts/*.sh
cd scripts
sudo sh install.sh
```

If something breaks, you now own all the pieces.

## 🙌 Credits

* **ChatGPT / Claude / Gemini** — The real developers
* **pywal devs** — Turning questionable color ideas into vibes
* **r/unixporn** — The inspiration for bad decisions at 3AM

## 🔥 Final Thoughts

This repo isn’t about elite Linux mastery.
It’s about proving that with enough AI help, confidence, and blind ambition, anyone can make a desktop that looks like a professional spent weeks on it.

Just… maybe don’t ask me what half the scripts are doing.
