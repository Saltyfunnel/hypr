#!/usr/bin/env python3
import configparser
import json
import subprocess
import sys
from pathlib import Path

from PyQt6 import QtCore, QtGui, QtWidgets

# ── Config ────────────────────────────────────────────────────────────────────
APP_DIRS = [
    Path.home() / ".local/share/applications",
    Path("/usr/share/applications"),
]
TERMINAL = "kitty"
FONT = "Hack Nerd Font"

TILE_W = 110
TILE_H = 230  # full height — no util row below
SKEW = 28
ICON_APP = 72
WALL_W = 220  # left panel width
SEARCH_H = 44

WIN_W = 920
WIN_H = SEARCH_H + 1 + TILE_H

USAGE_FILE = Path.home() / ".cache/launcher_usage.json"

EXCLUDE = [
    "ssh",
    "server",
    "avahi",
    "helper",
    "setup",
    "settings daemon",
    "gnome-session",
    "kde-",
    "xfce-",
    "lstopo",
    "hardware locality",
]

# Shortcuts shown at the bottom of the left panel
SHORTCUTS = [
    ("Files", "󰝰", "python3 ~/.config/scripts/file.py"),
    ("Terminal", "\ue795", "kitty"),  # alt: \uf120  \uf489  \ue7a2
    ("Browser", "󰖟", "firefox"),
    ("Editor", "󰅩", "zeditor"),
]

# Power icons shown in the search bar (right side)
POWER = [
    ("Lock", "󰌾", "hyprlock", False),
    ("Suspend", "󰤄", "systemctl suspend", False),
    ("Reboot", "󰑙", "systemctl reboot", True),
    ("Power", "󰐥", "systemctl poweroff", True),
]


# ── Pywal ─────────────────────────────────────────────────────────────────────


def load_pywal():
    p = Path.home() / ".cache/wal/colors.json"
    d = ("#1a1a1a", "#c0caf5", "#7aa2f7", "#bb9af7")
    if not p.exists():
        return d
    try:
        data = json.loads(p.read_text())
        return (
            data["special"]["background"],
            data["special"]["foreground"],
            data["colors"].get("color4", d[2]),
            data["colors"].get("color5", d[3]),
        )
    except Exception:
        return d


def wal_path():
    p = Path.home() / ".cache/wal/wal"
    return p.read_text().strip() if p.exists() else None


def mk_alpha(hex_c, a):
    c = QtGui.QColor(hex_c)
    c.setAlpha(a)
    return c.name(QtGui.QColor.NameFormat.HexArgb)


def load_wall(path, w, h):
    if not path or not Path(path).exists():
        return QtGui.QPixmap()
    src = QtGui.QPixmap(path)
    if src.isNull():
        return QtGui.QPixmap()
    s = src.scaled(
        w,
        h,
        QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding,
        QtCore.Qt.TransformationMode.SmoothTransformation,
    )
    cx, cy = max(0, (s.width() - w) // 2), max(0, (s.height() - h) // 2)
    r = s.copy(cx, cy, w, h)
    if r.width() < w or r.height() < h:
        out = QtGui.QPixmap(w, h)
        out.fill(QtCore.Qt.GlobalColor.black)
        qp = QtGui.QPainter(out)
        qp.drawPixmap(0, 0, r)
        qp.end()
        return out
    return r


# ── Left panel ────────────────────────────────────────────────────────────────


class WallPanel(QtWidgets.QWidget):
    shortcut_clicked = QtCore.pyqtSignal(str)  # emits command

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedSize(WALL_W, TILE_H)
        self._px = QtGui.QPixmap()
        self._accent = "#7aa2f7"
        self._fg = "#c0caf5"
        self._bg = "#1a1a1a"

        # Clock — top justified
        self._clock = QtWidgets.QLabel(self)
        self._clock.setObjectName("Clock")
        self._clock.setAlignment(
            QtCore.Qt.AlignmentFlag.AlignLeft | QtCore.Qt.AlignmentFlag.AlignTop
        )
        self._clock.setGeometry(16, 14, WALL_W - 32, 80)

        # Date — just below clock
        self._date = QtWidgets.QLabel(self)
        self._date.setObjectName("DateLbl")
        self._date.setAlignment(QtCore.Qt.AlignmentFlag.AlignLeft)
        self._date.setGeometry(18, 90, WALL_W - 32, 20)

        # Shortcut buttons — bottom of panel
        self._sc_btns: list[QtWidgets.QPushButton] = []
        self._build_shortcuts()

        self._tick()
        t = QtCore.QTimer(self)
        t.timeout.connect(self._tick)
        t.start(1000)

    def _build_shortcuts(self):
        n = len(SHORTCUTS)
        btn_w = 36
        btn_h = 36
        gap = 8
        x0 = 16
        y = TILE_H - btn_h - 14

        for i, (label, glyph, cmd) in enumerate(SHORTCUTS):
            btn = QtWidgets.QPushButton(glyph, self)
            btn.setObjectName("ScBtn")
            btn.setToolTip(label)
            btn.setFixedSize(btn_w, btn_h)
            btn.move(x0 + i * (btn_w + gap), y)
            btn.setCursor(QtGui.QCursor(QtCore.Qt.CursorShape.PointingHandCursor))
            btn.clicked.connect(lambda _, c=cmd: self._on_sc(c))
            btn.show()
            self._sc_btns.append(btn)

    def _on_sc(self, cmd):
        self.shortcut_clicked.emit(cmd)

    def set_data(self, px, accent, fg, bg):
        self._px = px
        self._accent = accent
        self._fg = fg
        self._bg = bg
        self._restyle()
        self.update()

    def _restyle(self):
        acc = self._accent
        bg = self._bg
        for btn in self._sc_btns:
            idle_col = mk_alpha(self._fg, 190)
            hover_bg = mk_alpha(acc, 70)
            hover_col = "#ffffff"
            hover_bdr = mk_alpha(acc, 160)
            btn.setStyleSheet(f"""
                QPushButton {{
                    background: {mk_alpha(bg, 120)};
                    border: 1px solid {mk_alpha(acc, 50)};
                    border-radius: 6px;
                    color: {idle_col};
                    font-family: "{FONT}"; font-size: 14px;
                }}
                QPushButton:hover {{
                    background: {hover_bg};
                    color: {hover_col};
                    border: 1px solid {hover_bdr};
                }}
            """)

    def _tick(self):
        now = QtCore.QDateTime.currentDateTime()
        self._clock.setText(now.toString("HH:mm"))
        self._date.setText(now.toString("ddd d MMM"))

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        p.setRenderHint(QtGui.QPainter.RenderHint.SmoothPixmapTransform)
        W, H = self.width(), self.height()

        poly = QtGui.QPolygonF(
            [
                QtCore.QPointF(0, 0),
                QtCore.QPointF(W, 0),
                QtCore.QPointF(W - SKEW, H),
                QtCore.QPointF(0, H),
            ]
        )
        clip = QtGui.QPainterPath()
        clip.addPolygon(poly)
        clip.closeSubpath()

        p.save()
        p.setClipPath(clip)
        if not self._px.isNull():
            scaled = self._px.scaled(
                W + SKEW,
                H,
                QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                QtCore.Qt.TransformationMode.SmoothTransformation,
            )
            p.setOpacity(0.75)
            p.drawPixmap(0, 0, scaled)
            p.setOpacity(1.0)
            dark = QtGui.QColor(self._bg)
            dark.setAlpha(80)
            p.fillPath(clip, dark)
        else:
            p.fillPath(clip, QtGui.QColor(self._bg))
        p.restore()

        # Accent slanted right border
        ac = QtGui.QColor(self._accent)
        ac.setAlpha(190)
        p.setPen(QtGui.QPen(ac, 1.5))
        p.drawLine(QtCore.QPointF(W, 0), QtCore.QPointF(W - SKEW, H))


# ── Icon name overrides (for apps with non-standard theme icon names) ───────────
ICON_OVERRIDES = {
    "zed": "/usr/share/icons/zed.png",
    "zeditor": "/usr/share/icons/zed.png",
}

# ── App tile ──────────────────────────────────────────────────────────────────


class AppTile(QtWidgets.QWidget):
    launched = QtCore.pyqtSignal(dict)

    def __init__(self, app, accent, accent2, fg, bg, parent=None):
        super().__init__(parent)
        self._app = app
        self._accent = accent
        self._accent2 = accent2
        self._fg = fg
        self._bg = bg
        self._hover = False
        self._sel = False
        self.setFixedSize(TILE_W + SKEW, TILE_H)
        self.setCursor(QtGui.QCursor(QtCore.Qt.CursorShape.PointingHandCursor))

        name = app.get("Icon", "")
        override = ICON_OVERRIDES.get(name.lower())
        if override and Path(override).exists():
            icon = QtGui.QIcon(override)
        elif override:
            icon = QtGui.QIcon.fromTheme(override)
        else:
            icon = QtGui.QIcon.fromTheme(name)
        if icon.isNull():
            icon = QtGui.QIcon.fromTheme("application-default-icon")
        self._icon = icon.pixmap(QtCore.QSize(ICON_APP, ICON_APP))

    def set_sel(self, v):
        self._sel = v
        self.update()

    def enterEvent(self, _):
        self._hover = True
        self.update()

    def leaveEvent(self, _):
        self._hover = False
        self.update()

    def mousePressEvent(self, e):
        if e.button() == QtCore.Qt.MouseButton.LeftButton:
            if self._clip().contains(e.position()):
                self.launched.emit(self._app)

    def _poly(self):
        W, H = TILE_W + SKEW, TILE_H
        return QtGui.QPolygonF(
            [
                QtCore.QPointF(SKEW, 0),
                QtCore.QPointF(W, 0),
                QtCore.QPointF(W - SKEW, H),
                QtCore.QPointF(0, H),
            ]
        )

    def _clip(self):
        pp = QtGui.QPainterPath()
        pp.addPolygon(self._poly())
        pp.closeSubpath()
        return pp

    def refresh(self, accent, accent2, fg, bg, _wall=None):
        self._accent = accent
        self._accent2 = accent2
        self._fg = fg
        self._bg = bg
        self.update()

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        p.setRenderHint(QtGui.QPainter.RenderHint.SmoothPixmapTransform)
        clip = self._clip()

        p.save()
        p.setClipPath(clip)

        # Plain bg — no wallpaper
        bg = QtGui.QColor(255, 255, 255)
        bg.setAlpha(18)
        p.fillPath(clip, bg)

        if self._sel:
            t = QtGui.QColor(self._accent)
            t.setAlpha(90)
            p.fillPath(clip, t)
        elif self._hover:
            t = QtGui.QColor(self._accent2)
            t.setAlpha(55)
            p.fillPath(clip, t)

        # Icon centred, nudge up on hover
        W, H = TILE_W + SKEW, TILE_H
        cx = W // 2
        cy = H // 2 - (12 if (self._hover or self._sel) else 0)
        p.drawPixmap(cx - ICON_APP // 2, cy - ICON_APP // 2, self._icon)

        # Name on hover/select
        if self._hover or self._sel:
            font = QtGui.QFont(FONT, 8)
            fm = QtGui.QFontMetrics(font)
            name = fm.elidedText(
                self._app["Name"], QtCore.Qt.TextElideMode.ElideMiddle, TILE_W - 8
            )
            lh = fm.height() + 4
            band = QtGui.QColor(0, 0, 0)
            band.setAlpha(175)
            p.fillRect(QtCore.QRectF(0, H - lh - 6, W, lh + 8), band)
            p.setFont(font)
            p.setPen(QtGui.QColor("#ffffff"))
            p.drawText(
                QtCore.QRect(SKEW + 4, H - lh - 3, TILE_W - 8, lh + 4),
                QtCore.Qt.AlignmentFlag.AlignVCenter,
                name,
            )

        p.restore()

        # Border
        if self._sel:
            pen = QtGui.QPen(QtGui.QColor(self._accent), 2.0)
        elif self._hover:
            pen = QtGui.QPen(QtGui.QColor(self._accent2), 1.5)
        else:
            c = QtGui.QColor(255, 255, 255)
            c.setAlpha(30)
            pen = QtGui.QPen(c, 0.8)
        p.setPen(pen)
        p.setBrush(QtCore.Qt.BrushStyle.NoBrush)
        p.drawPolygon(self._poly())


# ── App strip ─────────────────────────────────────────────────────────────────


class Strip(QtWidgets.QWidget):
    def __init__(self, tiles, parent=None):
        super().__init__(parent)
        self._tiles = tiles
        self._cursor = 0
        total = len(tiles) * TILE_W + SKEW + 8
        self.setFixedSize(total, TILE_H)
        for i, t in enumerate(tiles):
            t.setParent(self)
            t.move(i * TILE_W, 0)
            t.show()
        self._mark()

    def _mark(self):
        for i, t in enumerate(self._tiles):
            t.set_sel(i == self._cursor)

    def move_cursor(self, d):
        self._cursor = max(0, min(self._cursor + d, len(self._tiles) - 1))
        self._mark()
        return self._tiles[self._cursor] if self._tiles else None

    def cur_tile(self):
        return self._tiles[self._cursor] if self._tiles else None

    def count(self):
        return len(self._tiles)


class HScroll(QtWidgets.QScrollArea):
    def wheelEvent(self, e):
        self.horizontalScrollBar().setValue(
            self.horizontalScrollBar().value() - e.angleDelta().y()
        )


# ── Main launcher ─────────────────────────────────────────────────────────────


class Launcher(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("launcher")
        self.setFixedSize(WIN_W, WIN_H)
        self.setWindowFlags(
            QtCore.Qt.WindowType.FramelessWindowHint
            | QtCore.Qt.WindowType.Tool
            | QtCore.Qt.WindowType.WindowStaysOnTopHint
        )
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setContextMenuPolicy(QtCore.Qt.ContextMenuPolicy.NoContextMenu)

        self.BG, self.FG, self.ACC, self.ACC2 = load_pywal()
        self._wpath = wal_path()
        self._wall = load_wall(self._wpath, WALL_W + SKEW, TILE_H)
        self.usage = self._load_usage()
        self.all_apps: list[dict] = []
        self._strip: Strip | None = None

        self._frame = QtWidgets.QFrame(self)
        self._frame.setObjectName("Frame")
        self._frame.setGeometry(0, 0, WIN_W, WIN_H)

        self._build()
        self._find_apps()
        self._style()
        self._watch()
        self._center()
        self._search.setFocus()
        self.show()

    # ── Build ─────────────────────────────────────────────────────────────────

    def _build(self):
        # ── Search bar ────────────────────────────────────────────────────────
        srow = QtWidgets.QWidget(self._frame)
        srow.setObjectName("SRow")
        srow.setGeometry(0, 0, WIN_W, SEARCH_H)
        sl = QtWidgets.QHBoxLayout(srow)
        sl.setContentsMargins(16, 0, 10, 0)
        sl.setSpacing(8)

        self._search = QtWidgets.QLineEdit()
        self._search.setObjectName("Search")
        self._search.setPlaceholderText("search apps…")
        self._search.textChanged.connect(self._filter)
        self._search.returnPressed.connect(self._launch)
        self._search.keyPressEvent = self._key
        sl.addWidget(self._search, 1)

        self._count = QtWidgets.QLabel()
        self._count.setObjectName("Count")
        sl.addWidget(self._count)

        # Power buttons in search bar — stored for inline styling in _style()
        self._power_btns = []
        for label, glyph, cmd, danger in POWER:
            btn = QtWidgets.QPushButton(glyph)
            btn.setObjectName("PwrBtn")
            btn.setFixedSize(30, 28)
            btn.setToolTip(label)
            btn.setCursor(QtGui.QCursor(QtCore.Qt.CursorShape.PointingHandCursor))
            btn.clicked.connect(lambda _, c=cmd: self._run_cmd(c))
            sl.addWidget(btn)
            self._power_btns.append(btn)

        # ── Divider ───────────────────────────────────────────────────────────
        div = QtWidgets.QFrame(self._frame)
        div.setObjectName("Div")
        div.setGeometry(0, SEARCH_H, WIN_W, 1)

        # ── Left wall panel ───────────────────────────────────────────────────
        self._wall_panel = WallPanel(self._frame)
        self._wall_panel.setGeometry(0, SEARCH_H + 1, WALL_W, TILE_H)
        self._wall_panel.shortcut_clicked.connect(self._run_cmd)

        # ── App scroll ────────────────────────────────────────────────────────
        self._scroll = HScroll(self._frame)
        self._scroll.setObjectName("Scroll")
        self._scroll.setGeometry(WALL_W, SEARCH_H + 1, WIN_W - WALL_W, TILE_H)
        self._scroll.setWidgetResizable(False)
        self._scroll.setHorizontalScrollBarPolicy(
            QtCore.Qt.ScrollBarPolicy.ScrollBarAsNeeded
        )
        self._scroll.setVerticalScrollBarPolicy(
            QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        self._scroll.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
        self._scroll.setStyleSheet("background:transparent;")

        # Push data into wall panel after geometry is set
        self._wall_panel.set_data(self._wall, self.ACC, self.FG, self.BG)

    # ── Apps ──────────────────────────────────────────────────────────────────

    def _find_apps(self):
        apps, seen = [], set()
        for d in APP_DIRS:
            if not d.exists():
                continue
            for f in d.glob("*.desktop"):
                info = self._parse(f)
                if info and info["Name"] not in seen:
                    if any(k in info["Name"].lower() for k in EXCLUDE):
                        continue
                    apps.append(info)
                    seen.add(info["Name"])
        self.all_apps = apps
        self._rebuild(apps)

    def _rebuild(self, apps):
        srt = sorted(
            apps, key=lambda a: (-self.usage.get(a["Name"], 0), a["Name"].lower())
        )
        old = self._scroll.takeWidget()
        if old:
            old.deleteLater()
        tiles = []
        for app in srt:
            t = AppTile(app, self.ACC, self.ACC2, self.FG, self.BG)
            t.launched.connect(self._execute)
            tiles.append(t)
        self._strip = Strip(tiles)
        self._scroll.setWidget(self._strip)
        self._count.setText(str(len(srt)))

    def _filter(self, text=""):
        t = text.strip().lower()
        self._rebuild([a for a in self.all_apps if t in a["Name"].lower()])

    # ── Launch ────────────────────────────────────────────────────────────────

    def _launch(self):
        if not self._strip:
            return
        tile = self._strip.cur_tile()
        if tile:
            self._execute(tile._app)

    def _execute(self, app):
        self._save_usage(app["Name"])
        if app["Terminal"]:
            subprocess.Popen([TERMINAL, "-e", "bash", "-l", "-c", app["Exec"]])
        else:
            subprocess.Popen(app["Exec"], shell=True)
        QtWidgets.QApplication.quit()

    def _run_cmd(self, cmd):
        subprocess.Popen(cmd, shell=True)
        QtWidgets.QApplication.quit()

    # ── Keyboard ──────────────────────────────────────────────────────────────

    def _key(self, event):
        k = event.key()
        K = QtCore.Qt.Key
        if k == K.Key_Escape:
            QtWidgets.QApplication.quit()
            return
        if not self._strip or not self._strip.count():
            QtWidgets.QLineEdit.keyPressEvent(self._search, event)
            return
        if k in (K.Key_Right, K.Key_Tab):
            t = self._strip.move_cursor(1)
            if t:
                self._scroll.ensureWidgetVisible(t)
        elif k == K.Key_Left:
            t = self._strip.move_cursor(-1)
            if t:
                self._scroll.ensureWidgetVisible(t)
        elif k in (K.Key_Return, K.Key_Enter):
            self._launch()
        else:
            QtWidgets.QLineEdit.keyPressEvent(self._search, event)

    # ── Styles ────────────────────────────────────────────────────────────────

    def _style(self):
        acc = self.ACC
        fg = self.FG
        bg = self.BG
        bg_c = QtGui.QColor(bg)
        r, g, b = bg_c.red(), bg_c.green(), bg_c.blue()
        ac = QtGui.QColor(acc)
        ar, ag, ab = ac.red(), ac.green(), ac.blue()

        self._frame.setStyleSheet(f"""
            #Frame {{
                background: rgba({r},{g},{b},205);
                border: 1px solid {mk_alpha(acc, 80)};
                border-radius: 12px;
            }}
            #SRow {{
                background: rgba(255,255,255,22);
                border-top-left-radius: 12px;
                border-top-right-radius: 12px;
            }}
            #Search {{
                background: transparent; border: none;
                padding: 6px 2px; font-size: 12pt;
                color: #ffffff; font-family: "{FONT}";
            }}
            #Count {{
                font-family: "{FONT}"; font-size: 8pt;
                color: {mk_alpha(fg, 100)}; min-width: 24px;
            }}
            #PwrBtn {{
                background: transparent;
                border: none; border-radius: 5px;
                color: {mk_alpha(fg, 160)};
                font-family: "{FONT}"; font-size: 14px;
            }}
            #PwrBtn:hover {{
                background: {mk_alpha(acc, 60)}; color: #ffffff;
            }}
            #PwrDanger {{
                background: transparent;
                border: none; border-radius: 5px;
                color: {mk_alpha("#ff5555", 160)};
                font-family: "{FONT}"; font-size: 14px;
            }}
            #PwrDanger:hover {{
                background: rgba(255,85,85,60); color: #ff5555;
            }}
            #Div {{ background: {mk_alpha(acc, 40)}; border: none; }}
            #Scroll {{ background: transparent; border: none; }}
            QScrollBar:horizontal {{
                height: 3px; background: transparent;
            }}
            QScrollBar::handle:horizontal {{
                background: rgba({ar},{ag},{ab},110);
                border-radius: 1px; min-width: 24px;
            }}
            QScrollBar::add-line:horizontal,
            QScrollBar::sub-line:horizontal {{ width: 0; }}
            #Clock {{
                font-family: "{FONT}"; font-size: 34pt;
                font-weight: bold; color: {acc};
                letter-spacing: 2px; background: transparent;
            }}
            #DateLbl {{
                font-family: "{FONT}"; font-size: 9pt;
                color: {mk_alpha(fg, 175)}; background: transparent;
                letter-spacing: 1px;
            }}
        """)

    # ── Pywal watcher ─────────────────────────────────────────────────────────

    def _watch(self):
        self._fw = QtCore.QFileSystemWatcher(
            [str(Path.home() / ".cache/wal/colors.json")]
        )
        self._fw.fileChanged.connect(self._reload)

    def _reload(self):
        self.BG, self.FG, self.ACC, self.ACC2 = load_pywal()
        self._wpath = wal_path()
        self._wall = load_wall(self._wpath, WALL_W + SKEW, TILE_H)
        self._wall_panel.set_data(self._wall, self.ACC, self.FG, self.BG)
        if self._strip:
            for t in self._strip._tiles:
                t.refresh(self.ACC, self.ACC2, self.FG, self.BG)
        self._style()

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _parse(self, path):
        cfg = configparser.ConfigParser(interpolation=None)
        try:
            cfg.read(path, encoding="utf-8")
        except:
            return None
        if "Desktop Entry" not in cfg:
            return None
        e = cfg["Desktop Entry"]
        if e.get("Type") != "Application" or e.getboolean("NoDisplay", fallback=False):
            return None
        return {
            "Name": e.get("Name", ""),
            "Exec": e.get("Exec", "").split("%", 1)[0].strip(),
            "Icon": e.get("Icon", ""),
            "Terminal": e.getboolean("Terminal", fallback=False),
            "Categories": [
                c.strip() for c in e.get("Categories", "").split(";") if c.strip()
            ],
        }

    def _load_usage(self):
        if USAGE_FILE.exists():
            try:
                return json.loads(USAGE_FILE.read_text())
            except:
                pass
        return {}

    def _save_usage(self, name):
        self.usage[name] = self.usage.get(name, 0) + 1
        try:
            USAGE_FILE.parent.mkdir(parents=True, exist_ok=True)
            USAGE_FILE.write_text(json.dumps(self.usage))
        except:
            pass

    def _center(self):
        g = QtWidgets.QApplication.primaryScreen().geometry()
        self.move((g.width() - WIN_W) // 2, (g.height() - WIN_H) // 2)


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    app.setFont(QtGui.QFont(FONT, 10))
    w = Launcher()
    sys.exit(app.exec())
