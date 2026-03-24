#!/usr/bin/env python3
import configparser
import json
import os
import subprocess
import sys
from pathlib import Path

from PyQt6 import QtCore, QtGui, QtWidgets

# ── Config ────────────────────────────────────────────────────────────────────
APP_DIRS = [Path.home() / ".local/share/applications", Path("/usr/share/applications")]
TERMINAL = "kitty"
FONT = "Hack Nerd Font"

# UI Dimensions
ITEM_H = 50
WALL_W = 500
WIN_W = 850
WIN_H = 480

# WALLPAPER JUSTIFICATION: "left", "center", or "right"
WALL_ALIGN = "left"

EXCLUDE = [
    "ssh",
    "server",
    "avahi",
    "helper",
    "setup",
    "settings daemon",
    "gnome-session",
    "xfce",
    "lstopo",
    "qt",
    "xgps",
]
WAL_CACHE = Path.home() / ".cache/wal/colors.json"
WAL_WALL = Path.home() / ".cache/wal/wal"
USAGE_FILE = Path.home() / ".cache/launcher_usage.json"

SHORTCUTS = [
    ("Files", "󰝰", "filemanager.py"),
    ("Terminal", "󰆍", "kitty"),
    ("Browser", "󰖟", "firefox"),
    ("Editor", "󰅩", "zeditor"),
]

# Nerd Font glyph overrides for apps without a proper theme icon
# Add any app here by its Name= from the .desktop file
ICON_OVERRIDES = {
    "Zed": "󰅩",
    "btop": "󰓅",
    "htop": "󰓅",
    "nvim": "󰕷",
    "vim": "󰕷",
}

# ── Helpers ───────────────────────────────────────────────────────────────────


def load_pywal():
    d = ("#1a1a1a", "#c0caf5", "#7aa2f7", "#bb9af7")
    if not WAL_CACHE.exists():
        return d
    try:
        data = json.loads(WAL_CACHE.read_text())
        return (
            data["special"]["background"],
            data["special"]["foreground"],
            data["colors"].get("color4", d[2]),
            data["colors"].get("color5", d[3]),
        )
    except:
        return d


def wal_path():
    return WAL_WALL.read_text().strip() if WAL_WALL.exists() else None


def mk_alpha(hex_c, a):
    c = QtGui.QColor(hex_c)
    c.setAlpha(a)
    return c.name(QtGui.QColor.NameFormat.HexArgb)


def load_wall(path, w, h, align="center"):
    if not path or not os.path.exists(path):
        return QtGui.QPixmap()
    src = QtGui.QPixmap(path)
    if src.isNull():
        return QtGui.QPixmap()

    scaled = src.scaledToHeight(h, QtCore.Qt.TransformationMode.SmoothTransformation)
    if scaled.width() < w:
        scaled = src.scaledToWidth(w, QtCore.Qt.TransformationMode.SmoothTransformation)

    if align == "left":
        return scaled.copy(0, 0, w, h)
    elif align == "right":
        return scaled.copy(scaled.width() - w, 0, w, h)
    else:
        return scaled.copy((scaled.width() - w) // 2, 0, w, h)


# ── App Row ───────────────────────────────────────────────────────────────────


class AppRow(QtWidgets.QWidget):
    launched = QtCore.pyqtSignal(dict)

    def __init__(self, app, accent, fg, parent=None):
        super().__init__(parent)
        self._app, self._accent, self._fg = app, accent, fg
        self._hover = False
        self.setFixedHeight(ITEM_H)
        self.setCursor(QtGui.QCursor(QtCore.Qt.CursorShape.PointingHandCursor))

        # Use Nerd Font glyph override if available, otherwise fall back to theme icon
        glyph = ICON_OVERRIDES.get(app.get("Name", ""))
        if glyph:
            self._glyph = glyph
            self._icon = None
        else:
            self._glyph = None
            icon = QtGui.QIcon.fromTheme(app.get("Icon", "application-default-icon"))
            if icon.isNull():
                icon = QtGui.QIcon.fromTheme("application-default-icon")
            self._icon = icon.pixmap(QtCore.QSize(22, 22))

    def update_colors(self, accent, fg):
        self._accent, self._fg = accent, fg
        self.update()

    def enterEvent(self, _):
        self._hover = True
        self.update()

    def leaveEvent(self, _):
        self._hover = False
        self.update()

    def mousePressEvent(self, _):
        self.launched.emit(self._app)

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        rect = self.rect().adjusted(2, 2, -8, -2)
        if self._hover:
            p.setBrush(QtGui.QColor(mk_alpha(self._accent, 80)))
            p.setPen(QtGui.QPen(QtGui.QColor(self._accent), 1))
        else:
            p.setBrush(QtGui.QColor(255, 255, 255, 8))
            p.setPen(QtCore.Qt.PenStyle.NoPen)
        p.drawRoundedRect(rect, 5, 5)

        # Draw glyph or pixmap icon
        if self._glyph:
            p.setFont(QtGui.QFont(FONT, 14))
            p.setPen(QtGui.QColor(self._accent))
            p.drawText(8, (ITEM_H + 14) // 2, self._glyph)
        else:
            p.drawPixmap(10, (ITEM_H - 22) // 2, self._icon)

        p.setPen(QtGui.QColor("#ffffff"))
        p.setFont(QtGui.QFont(FONT, 9, QtGui.QFont.Weight.Bold))
        p.drawText(40, 20, self._app["Name"])
        p.setPen(QtGui.QColor(mk_alpha(self._fg, 110)))
        p.setFont(QtGui.QFont(FONT, 7))
        p.drawText(40, 35, self._app["Exec"][:35] + "...")


# ── Main Launcher ─────────────────────────────────────────────────────────────


class Launcher(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setFixedSize(WIN_W, WIN_H)
        self.setWindowFlags(QtCore.Qt.WindowType.FramelessWindowHint)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        self.watcher = QtCore.QFileSystemWatcher(self)
        for f in [WAL_CACHE, WAL_WALL]:
            if f.exists():
                self.watcher.addPath(str(f))
        self.watcher.fileChanged.connect(self._refresh_theme)

        self.usage = self._load_usage()

        self.frame = QtWidgets.QFrame(self)
        self.frame.setObjectName("MainFrame")
        self.frame.setGeometry(0, 0, WIN_W, WIN_H)

        self.left_img = QtWidgets.QLabel(self.frame)
        self.left_img.setGeometry(0, 0, WALL_W, WIN_H)

        self.left_overlay = QtWidgets.QFrame(self.frame)
        self.left_overlay.setObjectName("LeftOverlay")
        self.left_overlay.setGeometry(0, 0, WALL_W, WIN_H)

        self._clock = QtWidgets.QLabel("00:00", self.frame)
        self._clock.setObjectName("Clock")
        self._clock.setGeometry(35, 40, 250, 60)

        self._date = QtWidgets.QLabel("DATE", self.frame)
        self._date.setObjectName("DateLbl")
        self._date.setGeometry(38, 100, 250, 20)

        self._search = QtWidgets.QLineEdit(self.frame)
        self._search.setObjectName("Search")
        self._search.setPlaceholderText("Search...")
        self._search.setGeometry(35, 140, 280, 38)
        self._search.textChanged.connect(self._filter)

        self.icon_container = QtWidgets.QWidget(self.frame)
        self.icon_container.setGeometry(35, WIN_H - 65, 250, 45)
        self.icon_layout = QtWidgets.QHBoxLayout(self.icon_container)
        self.icon_layout.setContentsMargins(0, 0, 0, 0)
        self.icon_layout.setSpacing(15)

        for label, glyph, cmd in SHORTCUTS:
            btn = QtWidgets.QPushButton(glyph)
            btn.setObjectName("ScBtn")
            btn.setFixedSize(38, 38)
            btn.clicked.connect(lambda _, c=cmd: self._run_cmd(c))
            self.icon_layout.addWidget(btn)

        self.scroll = QtWidgets.QScrollArea(self.frame)
        self.scroll.setObjectName("Scroll")
        self.scroll.setGeometry(WALL_W + 10, 20, WIN_W - WALL_W - 20, WIN_H - 40)
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
        self.scroll.viewport().setStyleSheet("background: transparent;")

        self.list_container = QtWidgets.QWidget()
        self.list_layout = QtWidgets.QVBoxLayout(self.list_container)
        self.list_layout.setContentsMargins(5, 5, 5, 5)
        self.list_layout.setSpacing(5)
        self.list_layout.addStretch()
        self.scroll.setWidget(self.list_container)

        self._refresh_theme()
        self._find_apps()

        t = QtCore.QTimer(self)
        t.timeout.connect(self._tick)
        t.start(1000)
        self._tick()
        self._center()
        self._search.setFocus()
        self.show()

    def _refresh_theme(self):
        self.BG, self.FG, self.ACC, self.ACC2 = load_pywal()
        px = load_wall(wal_path(), WALL_W, WIN_H, align=WALL_ALIGN)
        if not px.isNull():
            self.left_img.setPixmap(px)
        for i in range(self.list_layout.count()):
            w = self.list_layout.itemAt(i).widget()
            if isinstance(w, AppRow):
                w.update_colors(self.ACC, self.FG)
        self._style()

    def _load_usage(self):
        return json.loads(USAGE_FILE.read_text()) if USAGE_FILE.exists() else {}

    def _find_apps(self):
        apps, seen = [], set()
        for d in APP_DIRS:
            if not d.exists():
                continue
            for f in d.glob("*.desktop"):
                cfg = configparser.ConfigParser(interpolation=None)
                try:
                    cfg.read(f, encoding="utf-8")
                    e = cfg["Desktop Entry"]
                    name = e.get("Name", "")
                    if name and name not in seen:
                        if (
                            any(k in name.lower() for k in EXCLUDE)
                            or e.get("NoDisplay") == "true"
                        ):
                            continue
                        apps.append(
                            {
                                "Name": name,
                                "Exec": e.get("Exec", "").split("%")[0].strip(),
                                "Icon": e.get("Icon", ""),
                                "Terminal": e.get("Terminal", "false").lower()
                                == "true",
                            }
                        )
                        seen.add(name)
                except:
                    continue
        self.all_apps = apps
        self._rebuild(apps)

    def _rebuild(self, apps):
        for i in reversed(range(self.list_layout.count())):
            if self.list_layout.itemAt(i).widget():
                self.list_layout.itemAt(i).widget().setParent(None)
        srt = sorted(
            apps, key=lambda a: (-self.usage.get(a["Name"], 0), a["Name"].lower())
        )
        for app in srt:
            row = AppRow(app, self.ACC, self.FG)
            row.launched.connect(self._execute)
            self.list_layout.insertWidget(self.list_layout.count() - 1, row)

    def _filter(self, text):
        self._rebuild([a for a in self.all_apps if text.lower() in a["Name"].lower()])

    def _execute(self, app):
        self.usage[app["Name"]] = self.usage.get(app["Name"], 0) + 1
        USAGE_FILE.write_text(json.dumps(self.usage))
        cmd = app["Exec"]
        if app.get("Terminal"):
            cmd = f"{TERMINAL} -- {cmd}"
        subprocess.Popen(cmd, shell=True)
        QtWidgets.QApplication.quit()

    def _run_cmd(self, cmd):
        subprocess.Popen(cmd, shell=True)
        QtWidgets.QApplication.quit()

    def _tick(self):
        now = QtCore.QDateTime.currentDateTime()
        self._clock.setText(now.toString("HH:mm"))
        self._date.setText(now.toString("dddd, d MMMM").upper())

    def _style(self):
        self.setStyleSheet(f"""
            #MainFrame {{ background: {mk_alpha(self.BG, 240)}; border: 1px solid {self.ACC}; border-radius: 10px; }}
            #LeftOverlay {{ background: rgba(0,0,0,100); border-right: 1px solid {mk_alpha(self.ACC, 80)}; border-top-left-radius: 10px; border-bottom-left-radius: 10px; }}
            #Clock {{ font-family: "{FONT}"; font-size: 52px; font-weight: bold; color: {self.ACC}; }}
            #DateLbl {{ font-family: "{FONT}"; font-size: 10px; color: {self.FG}; letter-spacing: 2px; }}
            #Search {{ background: rgba(255,255,255,10); border: 1px solid {mk_alpha(self.ACC2, 100)}; border-radius: 6px; color: #fff; font-family: "{FONT}"; font-size: 13px; padding-left: 12px; }}
            #ScBtn {{ background: {mk_alpha(self.BG, 150)}; border: 1px solid {mk_alpha(self.ACC, 60)}; border-radius: 6px; color: {self.FG}; font-family: "{FONT}"; font-size: 16px; }}
            #ScBtn:hover {{ background: {self.ACC}; color: #fff; }}
            QScrollBar:vertical {{ width: 2px; background: transparent; }}
            QScrollBar::handle:vertical {{ background: {self.ACC}; }}
        """)

    def _center(self):
        qr = self.frameGeometry()
        qr.moveCenter(
            QtGui.QGuiApplication.primaryScreen().availableGeometry().center()
        )
        self.move(qr.topLeft())


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    w = Launcher()
    sys.exit(app.exec())
