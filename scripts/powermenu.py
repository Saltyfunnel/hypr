#!/usr/bin/env python3
"""PyQt6 power/session menu for Hyprland — borderless, pywal-themed,
RGBA transparent, Nerd Font icons. Destructive actions (reboot/shutdown)
require a second click within a few seconds to "arm" before firing, so a
stray click doesn't take the machine down.

Bind it in hyprland.lua/conf to a key of your choice, e.g.:
    bind = $mainMod, Escape, exec, python3 ~/.config/scripts/power_menu.py

The window sets a fixed size, which Hyprland auto-floats on its own — but
if it ever still gets tiled (e.g. after a Hyprland update changes that
heuristic), add an explicit windowrule as a guaranteed fallback:
    windowrule = float, title:^(power_menu)$
    windowrule = center, title:^(power_menu)$
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QFont, QKeyEvent
from PyQt6.QtWidgets import (
    QApplication, QGridLayout, QLabel, QPushButton, QVBoxLayout, QWidget,
)

FONT = "Hack Nerd Font"
CONFIRM_TIMEOUT_MS = 3000

# (icon, label, needs_confirm)
ACTIONS = [
    ("󰌾", "lock", False),
    ("󰍃", "logout", False),
    ("󰤄", "suspend", False),
    ("󰜉", "reboot", True),
    ("󰐥", "shutdown", True),
]


def find_lock_cmd():
    """Prefer hyprlock, fall back to swaylock, then generic loginctl."""
    for name in ("hyprlock", "swaylock"):
        if shutil.which(name):
            return [name]
    return ["loginctl", "lock-session"]


def logout_cmd():
    """Hyprland 0.55+ changed the dispatch syntax for exit — use it when
    hyprctl is present, otherwise fall back to a generic session exit."""
    if shutil.which("hyprctl"):
        return ["hyprctl", "dispatch", "hl.dsp.exit()"]
    return ["loginctl", "terminate-session", ""]


def load_colors():
    c = dict(bg="#1e1e2e", fg="#cdd6f4", accent="#89b4fa", dim="#6c7086", warn="#f38ba8")
    try:
        w = json.loads((Path.home() / ".cache/wal/colors.json").read_text())
        c["bg"] = w["special"]["background"]
        c["fg"] = w["special"]["foreground"]
        c["accent"] = w["colors"]["color4"]
        c["dim"] = w["colors"]["color8"]
        c["warn"] = w["colors"].get("color1", c["warn"])
        if c["bg"].strip() == "#000000":
            c["bg"] = "#181825"
    except Exception:
        pass
    return c


def hex_to_rgba(hex_str, alpha=0.85):
    hex_str = hex_str.lstrip("#")
    if len(hex_str) != 6:
        return f"rgba(30, 30, 46, {alpha})"
    r, g, b = (int(hex_str[i:i + 2], 16) for i in (0, 2, 4))
    return f"rgba({r}, {g}, {b}, {alpha})"


def style(c):
    bg = hex_to_rgba(c["bg"], 0.85)
    surf = hex_to_rgba(c["bg"], 0.55)
    return f"""
    QWidget {{
        background: {bg};
    }}
    QPushButton {{
        background: {surf};
        border: 2px solid {c['dim']};
        border-radius: 18px;
    }}
    QPushButton:hover {{
        border-color: {c['accent']};
    }}
    QPushButton[armed="true"] {{
        border-color: {c['warn']};
    }}
    QLabel#btn_icon {{
        color: {c['fg']};
        background: transparent;
        font-size: 32px;
    }}
    QLabel#btn_label {{
        color: {c['dim']};
        background: transparent;
        font-size: 13px;
        font-weight: 600;
    }}
    QLabel#btn_icon[armed="true"], QLabel#btn_label[armed="true"] {{
        color: {c['warn']};
    }}
    """


class PowerButton(QPushButton):
    def __init__(self, icon, label, cmd_resolver, needs_confirm):
        super().__init__()
        self.icon_char, self.label_text = icon, label
        self.cmd_resolver = cmd_resolver
        self.needs_confirm = needs_confirm
        self.armed = False

        self.setFixedSize(150, 150)
        self.setProperty("armed", False)

        self.icon_lbl = QLabel(icon)
        self.icon_lbl.setObjectName("btn_icon")
        self.icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.icon_lbl.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)

        self.text_lbl = QLabel(label)
        self.text_lbl.setObjectName("btn_label")
        self.text_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.text_lbl.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)

        lay = QVBoxLayout(self)
        lay.setSpacing(8)
        lay.setContentsMargins(6, 14, 6, 14)
        lay.addWidget(self.icon_lbl)
        lay.addWidget(self.text_lbl)

        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.timeout.connect(self._disarm)

        self.clicked.connect(self._on_click)

    def _refresh_style(self):
        for w in (self, self.icon_lbl, self.text_lbl):
            w.style().unpolish(w)
            w.style().polish(w)

    def _on_click(self):
        if not self.needs_confirm or self.armed:
            self._fire()
            return
        self.armed = True
        self.setProperty("armed", True)
        self.icon_lbl.setProperty("armed", True)
        self.text_lbl.setProperty("armed", True)
        self.text_lbl.setText("confirm?")
        self._refresh_style()
        self._timer.start(CONFIRM_TIMEOUT_MS)

    def _disarm(self):
        self.armed = False
        self.setProperty("armed", False)
        self.icon_lbl.setProperty("armed", False)
        self.text_lbl.setProperty("armed", False)
        self.text_lbl.setText(self.label_text)
        self._refresh_style()

    def _fire(self):
        cmd = self.cmd_resolver()
        try:
            subprocess.Popen(cmd)
        except Exception:
            pass
        QApplication.instance().quit()


class Win(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        # Fixed title so a Hyprland windowrule can target this reliably.
        self.setWindowTitle("power_menu")

        colors = load_colors()
        self.setStyleSheet(style(colors))

        resolvers = {
            "lock": find_lock_cmd,
            "logout": logout_cmd,
            "suspend": lambda: ["systemctl", "suspend"],
            "reboot": lambda: ["systemctl", "reboot"],
            "shutdown": lambda: ["systemctl", "poweroff"],
        }

        grid = QGridLayout(self)
        grid.setSpacing(16)
        grid.setContentsMargins(24, 24, 24, 24)

        for i, (icon, label, needs_confirm) in enumerate(ACTIONS):
            btn = PowerButton(icon, label, resolvers[label], needs_confirm)
            grid.addWidget(btn, 0, i)

        n = len(ACTIONS)
        width = n * 150 + (n - 1) * 16 + 48
        # setFixedSize (not resize) sets min==max size, which Hyprland uses
        # as a heuristic to auto-float a window even without a windowrule.
        self.setFixedSize(width, 198)

    def keyPressEvent(self, e: QKeyEvent):
        if e.key() == Qt.Key.Key_Escape:
            QApplication.instance().quit()
        else:
            super().keyPressEvent(e)

    def mousePressEvent(self, e):
        # Clicking empty background (not a button) dismisses the menu.
        if self.childAt(e.position().toPoint()) is None:
            QApplication.instance().quit()
        else:
            super().mousePressEvent(e)


def main():
    app = QApplication(sys.argv)
    app.setFont(QFont(FONT, 11))
    w = Win()
    w.show()

    screen = app.primaryScreen().availableGeometry()
    w.move(
        screen.center().x() - w.width() // 2,
        screen.center().y() - w.height() // 2,
    )
    w.activateWindow()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
