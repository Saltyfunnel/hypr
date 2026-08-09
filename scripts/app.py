#!/usr/bin/env python3
import configparser
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from PyQt6 import QtCore, QtGui, QtWidgets

# ── Config ────────────────────────────────────────────────────────────────────
APP_DIRS = [Path.home() / ".local/share/applications", Path("/usr/share/applications")]
TERMINAL = "kitty"
FONT = "Hack Nerd Font"

ITEM_H = 50
WALL_W = 500
WIN_W = 850
WIN_H = 480

# "left", "center", or "right"
WALL_ALIGN = "left"

EXCLUDE = [
    "ssh", "server", "avahi", "helper", "setup", "settings daemon",
    "gnome-session", "xfce", "lstopo", "qt", "xgps",
]

WAL_CACHE = Path.home() / ".cache/wal/colors.json"
WAL_WALL  = Path.home() / ".cache/wal/wal"
USAGE_FILE = Path.home() / ".cache/launcher_usage.json"

SHORTCUTS = [
    ("Files",    "󰝰", "filemanager.py"),
    ("Terminal", "󰆍", "kitty"),
    ("Browser",  "󰖟", "firefox"),
    ("Editor",   "󰅩", "zeditor"),
]

ICON_OVERRIDES = {
    "Zed":  "󰅩",
    "btop": "󰓅",
    "htop": "󰓅",
    "nvim": "󰕷",
    "vim":  "󰕷",
}

# Strip desktop field codes (%f %F %u %U %c %k %i %d %D %n %N %v %m)
_FIELD_RE = re.compile(r"%[fFuUckidDnNvm]")

# Row stagger fade-in — per-row delay step and cap on how many rows get staggered
ROW_FADE_STEP_MS = 18
ROW_FADE_MAX_STAGGER = 12

# Window open animation duration
OPEN_ANIM_MS = 240

# ── Helpers ───────────────────────────────────────────────────────────────────

def load_pywal():
    fallback = ("#1a1a1a", "#c0caf5", "#7aa2f7", "#bb9af7")
    if not WAL_CACHE.exists():
        return fallback
    try:
        data = json.loads(WAL_CACHE.read_text())
        return (
            data["special"]["background"],
            data["special"]["foreground"],
            data["colors"].get("color4", fallback[2]),
            data["colors"].get("color5", fallback[3]),
        )
    except Exception:
        return fallback


def wal_path():
    return WAL_WALL.read_text().strip() if WAL_WALL.exists() else None


def mk_alpha(hex_c: str, a: int) -> str:
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


def clean_exec(raw: str) -> str:
    """Remove field codes and collapse whitespace from a .desktop Exec value."""
    return _FIELD_RE.sub("", raw.split("%")[0]).strip()


def truncate(text: str, max_chars: int) -> str:
    return text if len(text) <= max_chars else text[: max_chars - 1] + "…"


# ── Cached fonts ──────────────────────────────────────────────────────────────

_FONT_CACHE: dict[tuple, QtGui.QFont] = {}


def get_font(size: int, bold: bool = False) -> QtGui.QFont:
    key = (size, bold)
    if key not in _FONT_CACHE:
        f = QtGui.QFont(FONT, size)
        if bold:
            f.setWeight(QtGui.QFont.Weight.Bold)
        _FONT_CACHE[key] = f
    return _FONT_CACHE[key]


# ── App Row ───────────────────────────────────────────────────────────────────

class AppRow(QtWidgets.QWidget):
    """A single app entry. Selection highlight now lives in a separate sliding
    indicator widget owned by Launcher — this row only draws its own hover state."""

    launched = QtCore.pyqtSignal(dict)

    def __init__(self, app: dict, accent: str, fg: str, parent=None):
        super().__init__(parent)
        self._app = app
        self._accent = accent
        self._fg = fg
        self._hover = False
        self._opacity = 1.0
        self._fade_timer: QtCore.QTimer | None = None
        self._fade_start = None

        self.setFixedHeight(ITEM_H)
        self.setCursor(QtGui.QCursor(QtCore.Qt.CursorShape.PointingHandCursor))

        glyph = ICON_OVERRIDES.get(app.get("Name", ""))
        if glyph:
            self._glyph = glyph
            self._icon = None
        else:
            self._glyph = None
            icon = QtGui.QIcon.fromTheme(app.get("Icon", ""))
            if icon.isNull():
                icon = QtGui.QIcon.fromTheme("application-default-icon")
            self._icon = icon.pixmap(QtCore.QSize(22, 22))

        # Pre-build display strings once
        self._name = app.get("Name", "")
        self._exec_display = truncate(clean_exec(app.get("Exec", "")), 38)

    def update_colors(self, accent: str, fg: str):
        self._accent = accent
        self._fg = fg
        self.update()

    def start_fade_in(self, delay_ms: int = 0):
        """Fade this row in from transparent, after an optional stagger delay."""
        self._opacity = 0.0
        QtCore.QTimer.singleShot(delay_ms, self._begin_fade)

    def _begin_fade(self):
        self._fade_start = QtCore.QTime.currentTime()
        self._fade_timer = QtCore.QTimer(self)
        self._fade_timer.setInterval(12)
        self._fade_timer.timeout.connect(self._fade_tick)
        self._fade_timer.start()

    def _fade_tick(self):
        elapsed = self._fade_start.msecsTo(QtCore.QTime.currentTime())
        t = min(1.0, elapsed / 180.0)
        self._opacity = 1 - (1 - t) ** 3  # ease-out cubic
        self.update()
        if t >= 1.0:
            self._fade_timer.stop()

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
        p.setOpacity(self._opacity)
        rect = self.rect().adjusted(2, 2, -8, -2)

        if self._hover:
            p.setBrush(QtGui.QColor(mk_alpha(self._accent, 70)))
            p.setPen(QtGui.QPen(QtGui.QColor(self._accent), 1))
        else:
            p.setBrush(QtGui.QColor(255, 255, 255, 8))
            p.setPen(QtCore.Qt.PenStyle.NoPen)
        p.drawRoundedRect(rect, 5, 5)

        if self._glyph:
            p.setFont(get_font(14))
            p.setPen(QtGui.QColor(self._accent))
            p.drawText(8, (ITEM_H + 14) // 2, self._glyph)
        elif self._icon and not self._icon.isNull():
            p.drawPixmap(10, (ITEM_H - 22) // 2, self._icon)

        p.setPen(QtGui.QColor("#ffffff"))
        p.setFont(get_font(9, bold=True))
        p.drawText(40, 20, self._name)

        p.setPen(QtGui.QColor(mk_alpha(self._fg, 110)))
        p.setFont(get_font(7))
        p.drawText(40, 35, self._exec_display)


# ── Main Launcher ─────────────────────────────────────────────────────────────

class Launcher(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setFixedSize(WIN_W, WIN_H)
        self.setWindowFlags(QtCore.Qt.WindowType.FramelessWindowHint)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        self._selected_idx = -1   # keyboard selection index into self._rows
        self._rows: list[AppRow] = []
        self._indicator_anim: QtCore.QPropertyAnimation | None = None
        self._wall_anim: QtCore.QPropertyAnimation | None = None

        # Watch pywal files for live theme updates
        self.watcher = QtCore.QFileSystemWatcher(self)
        for f in [WAL_CACHE, WAL_WALL]:
            if f.exists():
                self.watcher.addPath(str(f))
        self.watcher.fileChanged.connect(self._refresh_theme)

        self.usage = self._load_usage()

        # ── Layout ──────────────────────────────────────────────────────────
        self.frame = QtWidgets.QFrame(self)
        self.frame.setObjectName("MainFrame")
        self.frame.setGeometry(0, 0, WIN_W, WIN_H)

        # Wallpaper panel
        self.left_img = QtWidgets.QLabel(self.frame)
        self.left_img.setGeometry(0, 0, WALL_W, WIN_H)

        self.left_overlay = QtWidgets.QFrame(self.frame)
        self.left_overlay.setObjectName("LeftOverlay")
        self.left_overlay.setGeometry(0, 0, WALL_W, WIN_H)

        # Clock
        self._clock = QtWidgets.QLabel("00:00", self.frame)
        self._clock.setObjectName("Clock")
        self._clock.setGeometry(35, 35, WALL_W - 50, 70)
        self._clock.setAlignment(QtCore.Qt.AlignmentFlag.AlignLeft | QtCore.Qt.AlignmentFlag.AlignVCenter)

        # Date
        self._date = QtWidgets.QLabel("DATE", self.frame)
        self._date.setObjectName("DateLbl")
        self._date.setGeometry(38, 108, WALL_W - 60, 22)

        # Search box
        self._search = QtWidgets.QLineEdit(self.frame)
        self._search.setObjectName("Search")
        self._search.setPlaceholderText("  Search...")
        self._search.setGeometry(35, 145, WALL_W - 60, 38)
        self._search.textChanged.connect(self._on_search_changed)
        self._search.installEventFilter(self)   # capture arrow keys before Qt eats them

        # Glowing pulse ring for the search box, breathes while focused
        self._search_glow = QtWidgets.QGraphicsDropShadowEffect(self._search)
        self._search_glow.setOffset(0, 0)
        self._search_glow.setBlurRadius(0)
        self._search_glow.setColor(QtGui.QColor("#7aa2f7"))
        self._search.setGraphicsEffect(self._search_glow)

        glow_up = QtCore.QPropertyAnimation(self._search_glow, b"blurRadius", self)
        glow_up.setDuration(700)
        glow_up.setStartValue(6)
        glow_up.setEndValue(24)
        glow_up.setEasingCurve(QtCore.QEasingCurve.Type.InOutSine)

        glow_down = QtCore.QPropertyAnimation(self._search_glow, b"blurRadius", self)
        glow_down.setDuration(700)
        glow_down.setStartValue(24)
        glow_down.setEndValue(6)
        glow_down.setEasingCurve(QtCore.QEasingCurve.Type.InOutSine)

        self._glow_group = QtCore.QSequentialAnimationGroup(self)
        self._glow_group.addAnimation(glow_up)
        self._glow_group.addAnimation(glow_down)
        self._glow_group.setLoopCount(-1)

        # Shortcut buttons
        icon_container = QtWidgets.QWidget(self.frame)
        icon_container.setGeometry(35, WIN_H - 65, WALL_W - 60, 45)
        icon_layout = QtWidgets.QHBoxLayout(icon_container)
        icon_layout.setContentsMargins(0, 0, 0, 0)
        icon_layout.setSpacing(12)
        for label, glyph, cmd in SHORTCUTS:
            btn = QtWidgets.QPushButton(glyph)
            btn.setObjectName("ScBtn")
            btn.setToolTip(label)
            btn.setFixedSize(38, 38)
            btn.clicked.connect(lambda _, c=cmd: self._run_cmd(c))
            icon_layout.addWidget(btn)
        icon_layout.addStretch()

        # App list (right panel)
        self.scroll = QtWidgets.QScrollArea(self.frame)
        self.scroll.setObjectName("Scroll")
        self.scroll.setGeometry(WALL_W + 10, 15, WIN_W - WALL_W - 20, WIN_H - 30)
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
        self.scroll.viewport().setStyleSheet("background: transparent;")

        self.list_container = QtWidgets.QWidget()
        self.list_layout = QtWidgets.QVBoxLayout(self.list_container)
        self.list_layout.setContentsMargins(5, 5, 5, 5)
        self.list_layout.setSpacing(4)
        self.scroll.setWidget(self.list_container)

        # Sliding selection indicator — glides between rows instead of snapping
        self._sel_indicator = QtWidgets.QFrame(self.list_container)
        self._sel_indicator.setObjectName("SelIndicator")
        self._sel_indicator.hide()

        # Boot
        self._refresh_theme()
        self._find_apps()

        timer = QtCore.QTimer(self)
        timer.timeout.connect(self._tick)
        timer.start(1000)
        self._tick()
        self._center()
        self._search.setFocus()

        # Fade + grow-in on open
        self.opacity_effect = QtWidgets.QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self.opacity_effect)
        self.opacity_effect.setOpacity(0.0)

        shrink = 0.90
        sw, sh = int(WIN_W * shrink), int(WIN_H * shrink)
        start_rect = QtCore.QRect((WIN_W - sw) // 2, (WIN_H - sh) // 2, sw, sh)
        full_rect = QtCore.QRect(0, 0, WIN_W, WIN_H)
        self.frame.setGeometry(start_rect)

        fade_anim = QtCore.QPropertyAnimation(self.opacity_effect, b"opacity", self)
        fade_anim.setDuration(OPEN_ANIM_MS)
        fade_anim.setStartValue(0.0)
        fade_anim.setEndValue(1.0)
        fade_anim.setEasingCurve(QtCore.QEasingCurve.Type.OutCubic)

        grow_anim = QtCore.QPropertyAnimation(self.frame, b"geometry", self)
        grow_anim.setDuration(OPEN_ANIM_MS)
        grow_anim.setStartValue(start_rect)
        grow_anim.setEndValue(full_rect)
        grow_anim.setEasingCurve(QtCore.QEasingCurve.Type.OutCubic)

        self._open_anim = QtCore.QParallelAnimationGroup(self)
        self._open_anim.addAnimation(fade_anim)
        self._open_anim.addAnimation(grow_anim)

        self.show()
        QtCore.QTimer.singleShot(0, self._open_anim.start)

    # ── Theme ────────────────────────────────────────────────────────────────

    def _refresh_theme(self):
        self.BG, self.FG, self.ACC, self.ACC2 = load_pywal()
        px = load_wall(wal_path(), WALL_W, WIN_H, align=WALL_ALIGN)
        if not px.isNull():
            old_px = self.left_img.pixmap()
            self.left_img.setPixmap(px)
            if old_px is not None and not old_px.isNull():
                self._crossfade_wall(old_px)
        self._search_glow.setColor(QtGui.QColor(self.ACC))
        for row in self._rows:
            row.update_colors(self.ACC, self.FG)
        self._apply_style()

    def _crossfade_wall(self, old_px: QtGui.QPixmap):
        """Briefly overlay the previous wallpaper crop and fade it out, revealing
        the freshly set one underneath — avoids a jarring hard-cut on theme change."""
        overlay = QtWidgets.QLabel(self.frame)
        overlay.setPixmap(old_px)
        overlay.setGeometry(self.left_img.geometry())
        overlay.show()
        overlay.stackUnder(self.left_overlay)

        effect = QtWidgets.QGraphicsOpacityEffect(overlay)
        overlay.setGraphicsEffect(effect)

        anim = QtCore.QPropertyAnimation(effect, b"opacity", self)
        anim.setDuration(400)
        anim.setStartValue(1.0)
        anim.setEndValue(0.0)
        anim.setEasingCurve(QtCore.QEasingCurve.Type.OutCubic)
        anim.finished.connect(overlay.deleteLater)
        anim.start(QtCore.QAbstractAnimation.DeletionPolicy.DeleteWhenStopped)
        self._wall_anim = anim

    def _apply_style(self):
        self.setStyleSheet(f"""
            #MainFrame {{
                background: {mk_alpha(self.BG, 240)};
                border: 1px solid {self.ACC};
                border-radius: 10px;
            }}
            #LeftOverlay {{
                background: rgba(0,0,0,110);
                border-right: 1px solid {mk_alpha(self.ACC, 80)};
                border-top-left-radius: 10px;
                border-bottom-left-radius: 10px;
            }}
            #Clock {{
                font-family: "{FONT}";
                font-size: 52px;
                font-weight: bold;
                color: {self.ACC};
            }}
            #DateLbl {{
                font-family: "{FONT}";
                font-size: 10px;
                color: {self.FG};
                letter-spacing: 2px;
            }}
            #Search {{
                background: rgba(255,255,255,12);
                border: 1px solid {mk_alpha(self.ACC2, 120)};
                border-radius: 6px;
                color: #fff;
                font-family: "{FONT}";
                font-size: 13px;
                padding-left: 10px;
            }}
            #Search:focus {{
                border: 1px solid {self.ACC};
                background: rgba(255,255,255,18);
            }}
            #ScBtn {{
                background: {mk_alpha(self.BG, 150)};
                border: 1px solid {mk_alpha(self.ACC, 60)};
                border-radius: 6px;
                color: {self.FG};
                font-family: "{FONT}";
                font-size: 16px;
            }}
            #ScBtn:hover {{
                background: {self.ACC};
                color: #fff;
            }}
            #SelIndicator {{
                background: {mk_alpha(self.ACC, 55)};
                border: 1px solid {self.ACC};
                border-radius: 5px;
            }}
            QScrollBar:vertical {{
                width: 2px;
                background: transparent;
            }}
            QScrollBar::handle:vertical {{
                background: {mk_alpha(self.ACC, 140)};
                border-radius: 1px;
            }}
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
                height: 0px;
            }}
        """)

    # ── Apps ─────────────────────────────────────────────────────────────────

    def _load_usage(self) -> dict:
        try:
            return json.loads(USAGE_FILE.read_text()) if USAGE_FILE.exists() else {}
        except Exception:
            return {}

    def _save_usage(self):
        try:
            USAGE_FILE.write_text(json.dumps(self.usage))
        except Exception:
            pass

    def _find_apps(self):
        apps, seen = [], set()
        for d in APP_DIRS:
            if not d.exists():
                continue
            for f in sorted(d.glob("*.desktop")):
                cfg = configparser.ConfigParser(interpolation=None)
                try:
                    cfg.read(f, encoding="utf-8")
                    if "Desktop Entry" not in cfg:
                        continue
                    e = cfg["Desktop Entry"]
                    if e.get("NoDisplay", "").lower() == "true":
                        continue
                    if e.get("Hidden", "").lower() == "true":
                        continue
                    name = e.get("Name", "").strip()
                    if not name or name in seen:
                        continue
                    if any(k in name.lower() for k in EXCLUDE):
                        continue
                    raw_exec = e.get("Exec", "")
                    if not raw_exec:
                        continue
                    apps.append({
                        "Name":     name,
                        "Exec":     raw_exec,
                        "Icon":     e.get("Icon", ""),
                        "Terminal": e.get("Terminal", "false").lower() == "true",
                    })
                    seen.add(name)
                except Exception:
                    continue
        self.all_apps = apps
        self._rebuild(apps)

    def _rebuild(self, apps: list[dict]):
        self._sel_indicator.hide()

        # Clear existing rows
        while self.list_layout.count():
            item = self.list_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        self._rows = []
        self._selected_idx = -1

        srt = sorted(
            apps,
            key=lambda a: (-self.usage.get(a["Name"], 0), a["Name"].lower()),
        )
        for i, app in enumerate(srt):
            row = AppRow(app, self.ACC, self.FG)
            row.launched.connect(self._execute)
            self.list_layout.addWidget(row)
            self._rows.append(row)

            # Staggered fade-in — earlier rows appear first, capped so long
            # lists don't take forever to finish revealing themselves
            delay = min(i, ROW_FADE_MAX_STAGGER) * ROW_FADE_STEP_MS
            row.start_fade_in(delay)

        # Trailing spacer so items stack from top
        self.list_layout.addStretch()
        self.list_layout.activate()
        self._sel_indicator.lower()

    # ── Search & keyboard nav ────────────────────────────────────────────────

    def _on_search_changed(self, text: str):
        filtered = [a for a in self.all_apps if text.lower() in a["Name"].lower()]
        self._rebuild(filtered)
        # Auto-select first result when searching
        if filtered:
            QtCore.QTimer.singleShot(0, lambda: self._set_selection(0))

    def _move_indicator(self, idx: int, animate: bool = True):
        if not (0 <= idx < len(self._rows)):
            self._sel_indicator.hide()
            return

        row = self._rows[idx]
        r = row.geometry()
        target = QtCore.QRect(r.x() + 2, r.y() + 2, r.width() - 10, r.height() - 4)

        if not animate or not self._sel_indicator.isVisible():
            self._sel_indicator.setGeometry(target)
            self._sel_indicator.show()
            self._sel_indicator.lower()
            self.scroll.ensureWidgetVisible(row)
            return

        anim = QtCore.QPropertyAnimation(self._sel_indicator, b"geometry", self)
        anim.setDuration(160)
        anim.setEasingCurve(QtCore.QEasingCurve.Type.OutCubic)
        anim.setStartValue(self._sel_indicator.geometry())
        anim.setEndValue(target)
        anim.start(QtCore.QAbstractAnimation.DeletionPolicy.DeleteWhenStopped)
        self._indicator_anim = anim
        self.scroll.ensureWidgetVisible(row)

    def _set_selection(self, idx: int):
        if self._rows:
            idx = max(0, min(idx, len(self._rows) - 1))
        else:
            idx = -1

        if self._selected_idx == idx:
            return

        self._selected_idx = idx
        self._move_indicator(idx)

    def eventFilter(self, obj, event):
        if obj is self._search:
            etype = event.type()
            if etype == QtCore.QEvent.Type.FocusIn:
                self._glow_group.start()
            elif etype == QtCore.QEvent.Type.FocusOut:
                self._glow_group.stop()
                self._search_glow.setBlurRadius(0)
            elif etype == QtCore.QEvent.Type.KeyPress:
                key = event.key()
                if key == QtCore.Qt.Key.Key_Down:
                    self._set_selection(max(self._selected_idx, 0) + 1)
                    return True
                if key == QtCore.Qt.Key.Key_Up:
                    self._set_selection(self._selected_idx - 1)
                    return True
                if key in (QtCore.Qt.Key.Key_Return, QtCore.Qt.Key.Key_Enter):
                    if 0 <= self._selected_idx < len(self._rows):
                        self._execute(self._rows[self._selected_idx]._app)
                    elif self._rows:
                        self._execute(self._rows[0]._app)
                    return True
                if key == QtCore.Qt.Key.Key_Escape:
                    QtWidgets.QApplication.quit()
                    return True
        return super().eventFilter(obj, event)

    def keyPressEvent(self, event):
        key = event.key()
        if key == QtCore.Qt.Key.Key_Escape:
            QtWidgets.QApplication.quit()
        else:
            super().keyPressEvent(event)

    # ── Launch ───────────────────────────────────────────────────────────────

    def _execute(self, app: dict):
        self.usage[app["Name"]] = self.usage.get(app["Name"], 0) + 1
        self._save_usage()
        cmd = clean_exec(app["Exec"])
        if app.get("Terminal"):
            cmd = f"{TERMINAL} -- {cmd}"
        subprocess.Popen(cmd, shell=True, start_new_session=True)
        QtWidgets.QApplication.quit()

    def _run_cmd(self, cmd: str):
        subprocess.Popen(cmd, shell=True, start_new_session=True)
        QtWidgets.QApplication.quit()

    # ── Clock ────────────────────────────────────────────────────────────────

    def _tick(self):
        now = QtCore.QDateTime.currentDateTime()
        self._clock.setText(now.toString("HH:mm"))
        self._date.setText(now.toString("dddd, d MMMM").upper())

    # ── Misc ─────────────────────────────────────────────────────────────────

    def _center(self):
        screen = QtGui.QGuiApplication.primaryScreen().availableGeometry()
        self.move(screen.center() - self.rect().center())


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    w = Launcher()
    sys.exit(app.exec())
