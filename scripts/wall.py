#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

from PyQt6 import QtCore, QtGui, QtWidgets

WALLPAPER_DIR = Path.home() / "Pictures/Wallpapers"
GRID_COLS = 4
TILE_W = 220
TILE_H = int(TILE_W * 9 / 16)  # True 16:9 — 123px
RADIUS = 10
SPACING = 16


def load_pywal():
    try:
        data = json.loads((Path.home() / ".cache/wal/colors.json").read_text())
        c = data.get("colors", {})
        return (
            c.get("color0", "#1a1a1a"),
            c.get("color7", "#ffffff"),
            c.get("color4", "#3583f6"),
        )
    except Exception:
        return "#1a1a1a", "#ffffff", "#3583f6"


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
                    TILE_W * 2,
                    TILE_H * 2,
                    QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                    QtCore.Qt.TransformationMode.SmoothTransformation,
                )
            self.loaded.emit(i, img)


class WallpaperTile(QtWidgets.QWidget):
    clicked = QtCore.pyqtSignal(Path)

    def __init__(self, path, accent, fg, bg):
        super().__init__()
        self.path = path
        self.accent = QtGui.QColor(accent)
        self.fg = QtGui.QColor(fg)
        self.bg = QtGui.QColor(bg)
        self.pixmap = QtGui.QPixmap()
        self.hovered = False
        # Fixed to exactly the image rect — no extra height for a label row
        self.setFixedSize(TILE_W, TILE_H)
        self.setCursor(QtCore.Qt.CursorShape.PointingHandCursor)

    def set_pixmap(self, img):
        self.pixmap = QtGui.QPixmap.fromImage(img)
        self.update()

    def enterEvent(self, _):
        self.hovered = True
        self.update()

    def leaveEvent(self, _):
        self.hovered = False
        self.update()

    def mousePressEvent(self, e):
        if e.button() == QtCore.Qt.MouseButton.LeftButton:
            self.clicked.emit(self.path)

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)

        rect = QtCore.QRectF(0, 0, TILE_W, TILE_H)
        clip = QtGui.QPainterPath()
        clip.addRoundedRect(rect, RADIUS, RADIUS)

        # Thumbnail
        p.save()
        p.setClipPath(clip)
        if not self.pixmap.isNull():
            # Centre-crop the pixmap into the tile rect
            src = self.pixmap
            sw, sh = src.width(), src.height()
            scale = max(TILE_W / sw, TILE_H / sh)
            dw, dh = sw * scale, sh * scale
            dx = (TILE_W - dw) / 2
            dy = (TILE_H - dh) / 2
            p.drawPixmap(QtCore.QRectF(dx, dy, dw, dh).toRect(), src)
        else:
            p.fillRect(rect.toRect(), QtGui.QColor(255, 255, 255, 12))
        p.restore()

        # Hover: dark scrim + filename at bottom
        if self.hovered:
            p.save()
            p.setClipPath(clip)
            # Bottom gradient scrim
            grad = QtGui.QLinearGradient(0, TILE_H * 0.45, 0, TILE_H)
            grad.setColorAt(0, QtGui.QColor(0, 0, 0, 0))
            grad.setColorAt(1, QtGui.QColor(0, 0, 0, 185))
            p.fillRect(rect.toRect(), grad)
            p.restore()

            # Filename label
            p.setPen(QtGui.QColor(255, 255, 255, 230))
            font = QtGui.QFont("Hack Nerd Font", 8, QtGui.QFont.Weight.Medium)
            p.setFont(font)
            fm = QtGui.QFontMetrics(font)
            label = fm.elidedText(
                self.path.stem,
                QtCore.Qt.TextElideMode.ElideRight,
                TILE_W - 16,
            )
            p.drawText(8, TILE_H - 9, label)

            # Accent border
            p.setPen(QtGui.QPen(self.accent, 2.5))
            p.drawRoundedRect(rect.adjusted(1, 1, -1, -1), RADIUS, RADIUS)
        else:
            # Subtle border
            p.setPen(QtGui.QPen(QtGui.QColor(255, 255, 255, 18), 1))
            p.drawRoundedRect(rect.adjusted(0.5, 0.5, -0.5, -0.5), RADIUS, RADIUS)


class WallpaperPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(QtCore.Qt.WindowType.FramelessWindowHint)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        self.bg, self.fg, self.accent = load_pywal()

        wallpapers = sorted(
            {
                *WALLPAPER_DIR.glob("*.[pj][pn]g"),
                *WALLPAPER_DIR.glob("*.webp"),
            }
        )
        if not wallpapers:
            sys.exit(1)

        self._init_ui(wallpapers)

    def _init_ui(self, wallpapers):
        main_layout = QtWidgets.QVBoxLayout(self)
        main_layout.setContentsMargins(20, 16, 20, 16)
        main_layout.setSpacing(12)

        # Header
        header = QtWidgets.QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)

        title = QtWidgets.QLabel("Wallpapers")
        title.setStyleSheet(
            f"color: {self.fg}; font-family: 'Hack Nerd Font'; "
            f"font-size: 15px; font-weight: 700; background: transparent;"
        )
        header.addWidget(title)

        count = QtWidgets.QLabel(f"{len(wallpapers)} images")
        count.setStyleSheet(
            f"color: {self.fg}88; font-family: 'Hack Nerd Font'; "
            f"font-size: 11px; background: transparent;"
        )
        header.addWidget(count)
        header.addStretch()

        close_btn = QtWidgets.QPushButton("✕")
        close_btn.setFixedSize(28, 28)
        close_btn.clicked.connect(self.close)
        close_btn.setStyleSheet(
            f"border: none; color: {self.fg}; font-size: 13px; "
            f"background: transparent; padding: 0;"
        )
        close_btn.setCursor(QtCore.Qt.CursorShape.PointingHandCursor)
        header.addWidget(close_btn)
        main_layout.addLayout(header)

        # Scroll area
        self.scroll = QtWidgets.QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
        self.scroll.setHorizontalScrollBarPolicy(
            QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        self.scroll.setVerticalScrollBarPolicy(
            QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        self.scroll.setStyleSheet("background: transparent; border: none;")

        container = QtWidgets.QWidget()
        container.setStyleSheet("background: transparent;")
        self.grid = QtWidgets.QGridLayout(container)
        self.grid.setSpacing(SPACING)
        self.grid.setContentsMargins(0, 0, 0, 8)

        self.tiles = []
        for i, wp in enumerate(wallpapers):
            tile = WallpaperTile(wp, self.accent, self.fg, self.bg)
            tile.clicked.connect(self._apply)
            self.grid.addWidget(tile, i // GRID_COLS, i % GRID_COLS)
            self.tiles.append(tile)

        self.scroll.setWidget(container)
        main_layout.addWidget(self.scroll)

        # Window size: fits exactly 4 columns, shows ~3.5 rows to hint scrollability
        win_w = TILE_W * GRID_COLS + SPACING * (GRID_COLS - 1) + 52
        visible_rows = 3.6
        win_h = int(TILE_H * visible_rows + SPACING * (visible_rows - 1)) + 80
        self.setFixedSize(win_w, win_h)

        screen = QtWidgets.QApplication.primaryScreen().availableGeometry()
        self.move(screen.center() - self.rect().center())

        # Load thumbnails async
        self.loader = ThumbLoader(
            sorted({*WALLPAPER_DIR.glob("*.[pj][pn]g"), *WALLPAPER_DIR.glob("*.webp")})
        )
        self.loader.loaded.connect(lambda i, img: self.tiles[i].set_pixmap(img))
        self.loader.start()

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)

        bg = QtGui.QColor(self.bg)
        bg.setAlpha(242)
        p.setBrush(bg)
        p.setPen(QtGui.QPen(QtGui.QColor(self.fg + "22"), 1))
        p.drawRoundedRect(self.rect().adjusted(1, 1, -1, -1), 14, 14)

    def _apply(self, wp):
        subprocess.run(
            ["bash", str(Path.home() / ".config/scripts/setwall.sh"), str(wp)]
        )
        self.close()

    def keyPressEvent(self, e):
        if e.key() == QtCore.Qt.Key.Key_Escape:
            self.close()


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    app.setFont(QtGui.QFont("Hack Nerd Font", 10))
    w = WallpaperPicker()
    w.show()
    sys.exit(app.exec())
