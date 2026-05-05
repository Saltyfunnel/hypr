#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

from PyQt6 import QtCore, QtGui, QtWidgets

WALLPAPER_DIR = Path.home() / "Pictures/Wallpapers"
FONT = "Hack Nerd Font"

# ── Dimensions (mirrors app.py proportions) ───────────────────────────────────
PREVIEW_W = 500   # left preview panel — same as app.py WALL_W
WIN_W = 850
WIN_H = 480
THUMB_H = 56      # height of each thumb row in the right list
THUMB_W = 80      # small thumbnail inside the row
RADIUS = 8

WAL_CACHE = Path.home() / ".cache/wal/colors.json"
WAL_WALL  = Path.home() / ".cache/wal/wal"


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
    except Exception:
        return d


def current_wall():
    return WAL_WALL.read_text().strip() if WAL_WALL.exists() else None


def mk_alpha(hex_c, a):
    c = QtGui.QColor(hex_c)
    c.setAlpha(a)
    return c.name(QtGui.QColor.NameFormat.HexArgb)


def load_preview(path, w, h):
    """Scale + centre-crop an image to exactly w×h."""
    if not path or not Path(path).exists():
        return QtGui.QPixmap()
    src = QtGui.QPixmap(str(path))
    if src.isNull():
        return QtGui.QPixmap()
    scaled = src.scaledToHeight(h, QtCore.Qt.TransformationMode.SmoothTransformation)
    if scaled.width() < w:
        scaled = src.scaledToWidth(w, QtCore.Qt.TransformationMode.SmoothTransformation)
    return scaled.copy((scaled.width() - w) // 2, 0, w, h)


# ── Async thumb loader ────────────────────────────────────────────────────────

class ThumbLoader(QtCore.QThread):
    loaded = QtCore.pyqtSignal(int, QtGui.QImage)

    def __init__(self, wallpapers):
        super().__init__()
        self.wallpapers = wallpapers

    def run(self):
        for i, wp in enumerate(self.wallpapers):
            img = QtGui.QImage(str(wp))
            if not img.isNull():
                img = img.scaled(
                    THUMB_W * 2, THUMB_H * 2,
                    QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                    QtCore.Qt.TransformationMode.SmoothTransformation,
                )
            self.loaded.emit(i, img)


# ── Single row in the right-hand list ────────────────────────────────────────

class WallRow(QtWidgets.QWidget):
    hovered   = QtCore.pyqtSignal(Path)   # emitted on enter
    activated = QtCore.pyqtSignal(Path)   # emitted on click

    def __init__(self, path, accent, fg, active=False, parent=None):
        super().__init__(parent)
        self.path   = path
        self._accent = accent
        self._fg     = fg
        self._active = active
        self._hover  = False
        self._thumb  = QtGui.QPixmap()

        self.setFixedHeight(THUMB_H)
        self.setCursor(QtGui.QCursor(QtCore.Qt.CursorShape.PointingHandCursor))

    # ── public slots ──────────────────────────────────────────────────────────

    def set_thumb(self, img: QtGui.QImage):
        self._thumb = QtGui.QPixmap.fromImage(img)
        self.update()

    def set_active(self, state: bool):
        self._active = state
        self.update()

    def update_colors(self, accent, fg):
        self._accent, self._fg = accent, fg
        self.update()

    # ── events ────────────────────────────────────────────────────────────────

    def enterEvent(self, _):
        self._hover = True
        self.update()
        self.hovered.emit(self.path)

    def leaveEvent(self, _):
        self._hover = False
        self.update()

    def mousePressEvent(self, e):
        if e.button() == QtCore.Qt.MouseButton.LeftButton:
            self.activated.emit(self.path)

    # ── paint ─────────────────────────────────────────────────────────────────

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)

        rect = self.rect().adjusted(2, 2, -8, -2)

        # Row background
        if self._hover or self._active:
            p.setBrush(QtGui.QColor(mk_alpha(self._accent, 80 if self._hover else 50)))
            p.setPen(QtGui.QPen(QtGui.QColor(self._accent), 1))
        else:
            p.setBrush(QtGui.QColor(255, 255, 255, 8))
            p.setPen(QtCore.Qt.PenStyle.NoPen)
        p.drawRoundedRect(rect, 5, 5)

        # Small thumbnail on the left of the row
        thumb_rect = QtCore.QRect(rect.x() + 6, rect.y() + 4, THUMB_W, THUMB_H - 8)
        if not self._thumb.isNull():
            clip = QtGui.QPainterPath()
            clip.addRoundedRect(QtCore.QRectF(thumb_rect), 4, 4)
            p.save()
            p.setClipPath(clip)
            # Centre-crop thumb into thumb_rect
            src = self._thumb
            sw, sh = src.width(), src.height()
            tw, th = thumb_rect.width(), thumb_rect.height()
            scale = max(tw / sw, th / sh)
            dw, dh = sw * scale, sh * scale
            dx = thumb_rect.x() + (tw - dw) / 2
            dy = thumb_rect.y() + (th - dh) / 2
            p.drawPixmap(QtCore.QRectF(dx, dy, dw, dh).toRect(), src)
            p.restore()
        else:
            p.fillRect(thumb_rect, QtGui.QColor(255, 255, 255, 12))

        # Filename text
        text_x = rect.x() + THUMB_W + 16
        p.setPen(QtGui.QColor("#ffffff"))
        p.setFont(QtGui.QFont(FONT, 9, QtGui.QFont.Weight.Bold))
        fm = QtGui.QFontMetrics(p.font())
        name = fm.elidedText(self.path.stem, QtCore.Qt.TextElideMode.ElideRight,
                              rect.width() - THUMB_W - 24)
        p.drawText(text_x, rect.y() + 22, name)

        # Suffix badge
        p.setFont(QtGui.QFont(FONT, 7))
        p.setPen(QtGui.QColor(mk_alpha(self._fg, 110)))
        p.drawText(text_x, rect.y() + 36, self.path.suffix.upper().lstrip("."))

        # Active indicator dot
        if self._active:
            p.setBrush(QtGui.QColor(self._accent))
            p.setPen(QtCore.Qt.PenStyle.NoPen)
            p.drawEllipse(rect.right() - 12, rect.center().y() - 4, 8, 8)


# ── Main window ───────────────────────────────────────────────────────────────

class WallpaperPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setFixedSize(WIN_W, WIN_H)
        self.setWindowFlags(QtCore.Qt.WindowType.FramelessWindowHint)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        self.BG, self.FG, self.ACC, self.ACC2 = load_pywal()
        self._current_wall = current_wall()
        self._preview_path = self._current_wall  # track what's showing in preview

        wallpapers = sorted({
            *WALLPAPER_DIR.glob("*.[pj][pn]g"),
            *WALLPAPER_DIR.glob("*.webp"),
        })
        if not wallpapers:
            sys.exit(1)

        self.wallpapers = wallpapers
        self._build_ui()
        self._load_preview(self._current_wall)

        # Pywal watcher — refresh colours if wal reruns
        self.watcher = QtCore.QFileSystemWatcher(self)
        for f in [WAL_CACHE, WAL_WALL]:
            if Path(str(f)).exists():
                self.watcher.addPath(str(f))
        self.watcher.fileChanged.connect(self._refresh_theme)

        # Async thumbnails
        self.loader = ThumbLoader(wallpapers)
        self.loader.loaded.connect(self._on_thumb)
        self.loader.start()

        self._center()

    # ── UI construction ───────────────────────────────────────────────────────

    def _build_ui(self):
        self.frame = QtWidgets.QFrame(self)
        self.frame.setObjectName("MainFrame")
        self.frame.setGeometry(0, 0, WIN_W, WIN_H)

        # ── Left: big preview ─────────────────────────────────────────────────
        self.preview_lbl = QtWidgets.QLabel(self.frame)
        self.preview_lbl.setGeometry(0, 0, PREVIEW_W, WIN_H)

        self.left_overlay = QtWidgets.QFrame(self.frame)
        self.left_overlay.setObjectName("LeftOverlay")
        self.left_overlay.setGeometry(0, 0, PREVIEW_W, WIN_H)

        # Filename label in the bottom-left of the preview
        self._fname_lbl = QtWidgets.QLabel("", self.frame)
        self._fname_lbl.setObjectName("FnameLbl")
        self._fname_lbl.setGeometry(18, WIN_H - 42, PREVIEW_W - 36, 28)

        # Wallpaper count top-left
        self._count_lbl = QtWidgets.QLabel(f"󰋩  {len(self.wallpapers)} wallpapers", self.frame)
        self._count_lbl.setObjectName("CountLbl")
        self._count_lbl.setGeometry(18, 18, PREVIEW_W - 36, 24)

        # ── Right: scrollable list ────────────────────────────────────────────
        self.scroll = QtWidgets.QScrollArea(self.frame)
        self.scroll.setObjectName("Scroll")
        self.scroll.setGeometry(PREVIEW_W + 10, 20, WIN_W - PREVIEW_W - 20, WIN_H - 40)
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
        self.scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.scroll.viewport().setStyleSheet("background: transparent;")

        self.list_container = QtWidgets.QWidget()
        self.list_layout = QtWidgets.QVBoxLayout(self.list_container)
        self.list_layout.setContentsMargins(5, 5, 5, 5)
        self.list_layout.setSpacing(5)
        self.list_layout.addStretch()
        self.scroll.setWidget(self.list_container)

        # Build rows
        self.rows: list[WallRow] = []
        for wp in self.wallpapers:
            is_active = (self._current_wall == str(wp))
            row = WallRow(wp, self.ACC, self.FG, active=is_active)
            row.hovered.connect(self._on_hover)
            row.activated.connect(self._apply)
            self.list_layout.insertWidget(self.list_layout.count() - 1, row)
            self.rows.append(row)

        self._apply_style()

    # ── Slots ─────────────────────────────────────────────────────────────────

    def _on_thumb(self, i: int, img: QtGui.QImage):
        if i < len(self.rows):
            self.rows[i].set_thumb(img)

    def _on_hover(self, path: Path):
        self._load_preview(str(path))

    def _load_preview(self, path):
        if not path:
            return
        px = load_preview(path, PREVIEW_W, WIN_H)
        if not px.isNull():
            self.preview_lbl.setPixmap(px)
        self._fname_lbl.setText(Path(path).stem)

    def _apply(self, path: Path):
        # Update active state on all rows
        for row in self.rows:
            row.set_active(row.path == path)
        self._current_wall = str(path)
        subprocess.Popen(
            ["bash", str(Path.home() / ".config/scripts/setwall.sh"), str(path)]
        )
        self.close()

    def _refresh_theme(self):
        self.BG, self.FG, self.ACC, self.ACC2 = load_pywal()
        for row in self.rows:
            row.update_colors(self.ACC, self.FG)
        self._apply_style()

    # ── Painting & styling ────────────────────────────────────────────────────

    def _apply_style(self):
        self.setStyleSheet(f"""
            #MainFrame {{
                background: {mk_alpha(self.BG, 240)};
                border: 1px solid {self.ACC};
                border-radius: 10px;
            }}
            #LeftOverlay {{
                background: rgba(0,0,0,80);
                border-right: 1px solid {mk_alpha(self.ACC, 80)};
                border-top-left-radius: 10px;
                border-bottom-left-radius: 10px;
            }}
            #FnameLbl {{
                font-family: "{FONT}";
                font-size: 11px;
                font-weight: bold;
                color: #ffffff;
                letter-spacing: 1px;
                background: transparent;
            }}
            #CountLbl {{
                font-family: "{FONT}";
                font-size: 10px;
                color: {self.FG};
                background: transparent;
                letter-spacing: 1px;
            }}
            QScrollBar:vertical {{
                width: 2px;
                background: transparent;
            }}
            QScrollBar::handle:vertical {{
                background: {self.ACC};
            }}
        """)

    def paintEvent(self, _):
        # Window chrome — rounded rect with border (matches app.py)
        pass

    def keyPressEvent(self, e):
        if e.key() == QtCore.Qt.Key.Key_Escape:
            self.close()

    def _center(self):
        qr = self.frameGeometry()
        qr.moveCenter(
            QtGui.QGuiApplication.primaryScreen().availableGeometry().center()
        )
        self.move(qr.topLeft())


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    app.setFont(QtGui.QFont(FONT, 10))
    w = WallpaperPicker()
    w.show()
    sys.exit(app.exec())
