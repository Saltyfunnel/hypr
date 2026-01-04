#!/usr/bin/env python3
import sys, subprocess
from pathlib import Path
from PyQt6 import QtWidgets, QtGui, QtCore

# --- CONFIGURATION ---
WALLPAPER_DIR = Path.home() / "Pictures/Wallpapers"
THUMB_SIZE = (200, 150) 
THUMBS_PER_ROW = 5
MAX_VISIBLE_ROWS = 3 
GRID_SPACING = 15 
SCALE_FACTOR = 1.1 
SHADOW_MARGIN = 10 
WRAPPER_WIDTH = int(THUMB_SIZE[0] * SCALE_FACTOR) + SHADOW_MARGIN * 2
WRAPPER_HEIGHT = int(THUMB_SIZE[1] * SCALE_FACTOR) + SHADOW_MARGIN * 2

class AnimatedThumbnail(QtWidgets.QWidget):
    def __init__(self, button, parent=None):
        super().__init__(parent)
        self.button = button
        self.setFixedSize(WRAPPER_WIDTH, WRAPPER_HEIGHT) 
        btn_x = int((WRAPPER_WIDTH - THUMB_SIZE[0]) / 2)
        btn_y = int((WRAPPER_HEIGHT - THUMB_SIZE[1]) / 2)
        self.original_rect = QtCore.QRect(btn_x, btn_y, THUMB_SIZE[0], THUMB_SIZE[1])
        self.button.setGeometry(self.original_rect)
        self.animation = QtCore.QPropertyAnimation(self.button, b"geometry")
        self.is_animating = False
        self.button.setParent(self) 

    def enterEvent(self, event):
        if not self.is_animating:
            self.is_animating = True
            new_width = int(THUMB_SIZE[0] * SCALE_FACTOR)
            new_height = int(THUMB_SIZE[1] * SCALE_FACTOR)
            center_x = self.original_rect.center().x(); center_y = self.original_rect.center().y()
            new_x = int(center_x - new_width / 2); new_y = int(center_y - new_height / 2)
            self.animation.stop()
            self.animation.setDuration(150)
            self.animation.setEndValue(QtCore.QRect(new_x, new_y, new_width, new_height))
            self.animation.finished.connect(lambda: setattr(self, 'is_animating', False))
            self.animation.start()
        super().enterEvent(event)

    def leaveEvent(self, event):
        self.is_animating = True
        self.animation.stop()
        self.animation.setDuration(150)
        self.animation.setEndValue(self.original_rect) 
        self.animation.finished.connect(lambda: setattr(self, 'is_animating', False))
        self.animation.start()
        super().leaveEvent(event)

class WallpaperPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setObjectName("WallpaperPicker")
        self.setWindowFlags(QtCore.Qt.WindowType.FramelessWindowHint | QtCore.Qt.WindowType.Tool)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        self.wallpapers = sorted(list(WALLPAPER_DIR.glob("*.[pj][pn]g")))
        if not self.wallpapers: sys.exit(1)

        # Get actual colors from Pywal
        self.BG, self.FG, self.BORDER = self.get_pywal_colors()
        
        # MANAGE TINT: Use Pywal BG color but set alpha
        # This makes it theme-consistent rather than just "gray"
        self.tint_color = QtGui.QColor(self.BG)
        # If the theme is too light, we darken it slightly (multiplier 0.8)
        self.tint_color.setRed(int(self.tint_color.red() * 0.8))
        self.tint_color.setGreen(int(self.tint_color.green() * 0.8))
        self.tint_color.setBlue(int(self.tint_color.blue() * 0.8))
        self.tint_color.setAlpha(180) # 180 = "frosted" transparency

        main_layout = QtWidgets.QVBoxLayout(self)
        main_layout.setContentsMargins(GRID_SPACING, GRID_SPACING, GRID_SPACING, GRID_SPACING)

        scroll = QtWidgets.QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("background: transparent; border: none;")
        scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        container = QtWidgets.QWidget()
        container.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)
        grid = QtWidgets.QGridLayout(container)
        grid.setSpacing(5)

        row, col = 0, 0
        for wp in self.wallpapers:
            pixmap = QtGui.QPixmap(str(wp)).scaled(THUMB_SIZE[0], THUMB_SIZE[1], QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding, QtCore.Qt.TransformationMode.SmoothTransformation)
            btn = QtWidgets.QPushButton()
            btn.setIcon(QtGui.QIcon(pixmap))
            btn.setIconSize(QtCore.QSize(*THUMB_SIZE))
            btn.setFixedSize(THUMB_SIZE[0], THUMB_SIZE[1]) 
            btn.setStyleSheet("border-radius: 8px; border: none; background: transparent;")
            thumb_wrapper = AnimatedThumbnail(btn)
            btn.clicked.connect(lambda checked=False, w=wp: self.select_wallpaper(w))
            grid.addWidget(thumb_wrapper, row, col)
            col += 1
            if col >= THUMBS_PER_ROW: col = 0; row += 1

        scroll.setWidget(container)
        main_layout.addWidget(scroll)

        actual_rows = (len(self.wallpapers) + THUMBS_PER_ROW - 1) // THUMBS_PER_ROW
        visible_rows = min(actual_rows, MAX_VISIBLE_ROWS)
        self.setFixedSize((WRAPPER_WIDTH * THUMBS_PER_ROW) + (GRID_SPACING * 2), (WRAPPER_HEIGHT * visible_rows) + (GRID_SPACING * 2))
        self.show()

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        # Background Tint
        painter.setBrush(QtGui.QBrush(self.tint_color))
        painter.setPen(QtGui.QPen(QtGui.QColor(self.BORDER), 2))
        painter.drawRoundedRect(self.rect().adjusted(1,1,-1,-1), 15, 15)

    def get_pywal_colors(self):
        wal_cache = Path.home() / ".cache/wal/colors.css"
        colors = {}
        try:
            with open(wal_cache) as f:
                for line in f:
                    if ":" in line:
                        parts = line.split(":")
                        colors[parts[0].strip().replace("--", "")] = parts[1].strip().rstrip(";")
        except: return "#1a1a1a", "#ffffff", "#444444"
        return colors.get("color0", "#1a1a1a"), colors.get("color7", "#ffffff"), colors.get("color4", "#444444")

    def select_wallpaper(self, wp):
        subprocess.run([str(Path.home() / ".config/scripts/setwall.sh"), str(wp)])
        QtWidgets.QApplication.quit()

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key.Key_Escape: QtWidgets.QApplication.quit()

if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    app.setDesktopFileName("WallpaperPicker") 
    picker = WallpaperPicker()
    sys.exit(app.exec())
