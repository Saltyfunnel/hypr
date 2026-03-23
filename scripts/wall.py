#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

from PyQt6 import QtCore, QtGui, QtWidgets

WALLPAPER_DIR = Path.home() / "Pictures/Wallpapers"
GRID_COLS = 5
TILE_W = 185
TILE_H = 115
RADIUS = 12
SPACING = 22

def load_pywal():
    try:
        data = json.loads((Path.home() / ".cache/wal/colors.json").read_text())
        c = data.get("colors", {})
        # background is color0, text is color7 (white/light), accent is color4
        return (
            c.get("color0", "#1a1a1a"), 
            c.get("color7", "#ffffff"), 
            c.get("color4", "#3583f6")
        )
    except Exception:
        # Fallback to dark theme if pywal fails
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
                img = img.scaled(TILE_W * 2, TILE_H * 2, QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding, QtCore.Qt.TransformationMode.SmoothTransformation)
            self.loaded.emit(i, img)

class WallpaperTile(QtWidgets.QWidget):
    clicked = QtCore.pyqtSignal(Path)
    def __init__(self, path, accent, fg):
        super().__init__()
        self.path, self.accent, self.fg = path, QtGui.QColor(accent), QtGui.QColor(fg)
        self.pixmap, self.hovered = QtGui.QPixmap(), False
        self.setFixedSize(TILE_W, TILE_H + 35)
        self.setCursor(QtCore.Qt.CursorShape.PointingHandCursor)

    def set_pixmap(self, img):
        self.pixmap = QtGui.QPixmap.fromImage(img)
        self.update()

    def enterEvent(self, _): self.hovered = True; self.update()
    def leaveEvent(self, _): self.hovered = False; self.update()
    def mousePressEvent(self, e):
        if e.button() == QtCore.Qt.MouseButton.LeftButton: self.clicked.emit(self.path)

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        
        # Lift effect
        y_off = 5 if self.hovered else 10
        rect = QtCore.QRectF(0, y_off, TILE_W, TILE_H)
        
        path = QtGui.QPainterPath()
        path.addRoundedRect(rect, RADIUS, RADIUS)
        
        p.save()
        p.setClipPath(path)
        if not self.pixmap.isNull():
            p.drawPixmap(rect.toRect(), self.pixmap)
        else:
            # Placeholder color based on foreground transparency
            p.fillRect(rect.toRect(), QtGui.QColor(255, 255, 255, 10))
        p.restore()

        if self.hovered:
            p.setPen(QtGui.QPen(self.accent, 3))
            p.drawRoundedRect(rect, RADIUS, RADIUS)
            
            p.setPen(self.fg)
            p.setFont(QtGui.QFont("Sans", 8, QtGui.QFont.Weight.Bold))
            lbl = QtGui.QFontMetrics(p.font()).elidedText(self.path.stem, QtCore.Qt.TextElideMode.ElideRight, TILE_W)
            p.drawText(0, int(rect.bottom() + 22), lbl)
        else:
            # Subtle border that works on dark or light backgrounds
            p.setPen(QtGui.QPen(QtGui.QColor(self.fg.red(), self.fg.green(), self.fg.blue(), 30), 1))
            p.drawRoundedRect(rect, RADIUS, RADIUS)

class WallpaperPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(QtCore.Qt.WindowType.FramelessWindowHint)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)
        
        self.bg, self.fg, self.accent = load_pywal()
        
        wallpapers = sorted({*WALLPAPER_DIR.glob("*.[pj][pn]g"), *WALLPAPER_DIR.glob("*.webp")})
        if not wallpapers: sys.exit(1)

        self._init_ui(wallpapers)

    def _init_ui(self, wallpapers):
        main_layout = QtWidgets.QVBoxLayout(self)
        main_layout.setContentsMargins(25, 20, 25, 10)

        header = QtWidgets.QHBoxLayout()
        title = QtWidgets.QLabel("Wallpaper Library")
        title.setStyleSheet(f"color: {self.fg}; font-size: 20px; font-weight: 900;")
        header.addWidget(title)
        
        close = QtWidgets.QPushButton("✕")
        close.setFixedSize(30, 30)
        close.clicked.connect(self.close)
        close.setStyleSheet(f"border: none; color: {self.fg}; font-size: 14px; background: transparent;")
        header.addStretch()
        header.addWidget(close)
        main_layout.addLayout(header)

        self.scroll = QtWidgets.QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
        # Scrollbars are fully disabled
        self.scroll.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.scroll.setStyleSheet("background: transparent; border: none;")
        
        container = QtWidgets.QWidget()
        container.setStyleSheet("background: transparent;")
        self.grid = QtWidgets.QGridLayout(container)
        self.grid.setSpacing(SPACING)
        self.grid.setContentsMargins(0, 5, 0, 40) 
        
        self.tiles = []
        for i, wp in enumerate(wallpapers):
            tile = WallpaperTile(wp, self.accent, self.fg)
            tile.clicked.connect(self._apply)
            self.grid.addWidget(tile, i // GRID_COLS, i % GRID_COLS)
            self.tiles.append(tile)
            
        self.scroll.setWidget(container)
        main_layout.addWidget(self.scroll)

        self.loader = ThumbLoader(wallpapers)
        self.loader.loaded.connect(lambda i, img: self.tiles[i].set_pixmap(img))
        self.loader.start()

        # Window Size calculation
        win_w = (TILE_W * GRID_COLS) + (SPACING * (GRID_COLS - 1)) + 50
        win_h = (TILE_H + 50) * 4 + 110
        self.setFixedSize(win_w, win_h)
        
        screen = QtWidgets.QApplication.primaryScreen().availableGeometry()
        self.move(screen.center() - self.rect().center())

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        
        # Main background (now pulled from Pywal)
        bg_color = QtGui.QColor(self.bg)
        bg_color.setAlpha(245) # Slight transparency for a "modern" feel
        p.setBrush(bg_color)
        
        # Window border using Pywal accent
        p.setPen(QtGui.QPen(QtGui.QColor(self.accent), 1.5))
        p.drawRoundedRect(self.rect().adjusted(1,1,-1,-1), 16, 16)

    def _apply(self, wp):
        subprocess.run(["bash", str(Path.home() / ".config/scripts/setwall.sh"), str(wp)])
        self.close()

    def keyPressEvent(self, e):
        if e.key() == QtCore.Qt.Key.Key_Escape: self.close()

if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    app.setFont(QtGui.QFont("Sans", 10))
    w = WallpaperPicker()
    w.show()
    sys.exit(app.exec())
