#!/usr/bin/env python3
import sys, subprocess
from pathlib import Path
from PyQt6 import QtWidgets, QtGui, QtCore

# --- CONFIGURATION (COMPACT SIZE AND HIGH DENSITY) ---
WALLPAPER_DIR = Path.home() / "Pictures/Wallpapers"
THUMB_SIZE = (200, 150) 
THUMBS_PER_ROW = 5
MAX_VISIBLE_ROWS = 3 
OPACITY = 200
GRID_SPACING = 10 

# Constants for seamless zoom calculation
SCALE_FACTOR = 1.1 
SHADOW_MARGIN = 10 
WRAPPER_WIDTH = int(THUMB_SIZE[0] * SCALE_FACTOR) + SHADOW_MARGIN * 2
WRAPPER_HEIGHT = int(THUMB_SIZE[1] * SCALE_FACTOR) + SHADOW_MARGIN * 2

# --- Animated Wrapper Class ---
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

        self.layout = QtWidgets.QHBoxLayout(self)
        self.layout.setContentsMargins(0, 0, 0, 0)
        self.setLayout(self.layout)
        self.button.setParent(self) 

    def enterEvent(self, event):
        if not self.is_animating:
            self.is_animating = True
            new_width = int(THUMB_SIZE[0] * SCALE_FACTOR)
            new_height = int(THUMB_SIZE[1] * SCALE_FACTOR)
            center_x = self.original_rect.center().x()
            center_y = self.original_rect.center().y()
            new_x = int(center_x - new_width / 2)
            new_y = int(center_y - new_height / 2)
            self.animation.setDuration(150)
            self.animation.setStartValue(self.button.geometry())
            self.animation.setEndValue(QtCore.QRect(new_x, new_y, new_width, new_height))
            self.animation.finished.connect(lambda: setattr(self, 'is_animating', False))
            self.animation.start()
        super().enterEvent(event)

    def leaveEvent(self, event):
        if not self.is_animating:
            self.is_animating = True
            self.animation.setDuration(150)
            self.animation.setStartValue(self.button.geometry())
            self.animation.setEndValue(self.original_rect) 
            self.animation.finished.connect(lambda: setattr(self, 'is_animating', False))
            self.animation.start()
        super().leaveEvent(event)


class WallpaperPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        
        self.setWindowTitle("Pick a wallpaper")
        self.setWindowFlag(QtCore.Qt.WindowType.WindowStaysOnTopHint)
        self.setWindowFlag(QtCore.Qt.WindowType.Tool)
        self.setWindowFlag(QtCore.Qt.WindowType.FramelessWindowHint) 
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_OpaquePaintEvent) 

        self.wallpapers = list(WALLPAPER_DIR.glob("*.[pj][pn]g"))
        if not self.wallpapers:
            QtWidgets.QMessageBox.warning(self, "Error", f"No wallpapers found in {WALLPAPER_DIR}")
            sys.exit(1)

        # Get Pywal colors
        self.BG, self.FG, self.BORDER = self.get_pywal_colors()
        bg_color = QtGui.QColor(self.BG)
        bg_color.setAlpha(OPACITY)
        rgba_bg = f"rgba({bg_color.red()},{bg_color.green()},{bg_color.blue()},{bg_color.alpha()})"
        
        # Apply style to main window
        self.setStyleSheet(f"background-color: {rgba_bg}; border-radius: 10px;") 

        # Scroll Area Setup
        scroll = QtWidgets.QScrollArea()
        scroll.setWidgetResizable(True)
        # Hide scrollbars
        scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setFrameShape(QtWidgets.QFrame.Shape.NoFrame) 
        scroll.setStyleSheet("background-color: transparent;")

        container = QtWidgets.QWidget()
        container.setStyleSheet("background-color: transparent;")
        grid = QtWidgets.QGridLayout(container)
        grid.setSpacing(0)
        grid.setContentsMargins(0, 0, 0, 0) 

        # Build Grid
        row, col = 0, 0
        for wp in self.wallpapers:
            pixmap = QtGui.QPixmap(str(wp)).scaled(
                THUMB_SIZE[0], THUMB_SIZE[1], 
                QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                QtCore.Qt.TransformationMode.SmoothTransformation
            )
            
            btn = QtWidgets.QPushButton()
            btn.setIcon(QtGui.QIcon(pixmap))
            btn.setIconSize(QtCore.QSize(*THUMB_SIZE))
            btn.setCursor(QtCore.Qt.CursorShape.PointingHandCursor)
            btn.setFixedSize(THUMB_SIZE[0], THUMB_SIZE[1]) 
            btn.setStyleSheet("QPushButton { border: none; border-radius: 5px; background-color: transparent; }")
            
            thumb_wrapper = AnimatedThumbnail(btn)
            btn.clicked.connect(lambda checked=False, w=wp: self.select_wallpaper(w))
            grid.addWidget(thumb_wrapper, row, col)
            
            col += 1
            if col >= THUMBS_PER_ROW:
                col = 0
                row += 1

        # --- DYNAMIC SIZING CALCULATIONS ---
        num_wallpapers = len(self.wallpapers)
        # Calculate how many rows are needed
        actual_rows = (num_wallpapers + THUMBS_PER_ROW - 1) // THUMBS_PER_ROW
        # Use actual rows, but don't exceed MAX_VISIBLE_ROWS
        visible_rows = min(actual_rows, MAX_VISIBLE_ROWS)

        # Window dimensions
        final_width = (WRAPPER_WIDTH * THUMBS_PER_ROW) + (GRID_SPACING * 2)
        final_height = (WRAPPER_HEIGHT * visible_rows) + (GRID_SPACING * 2)

        container.setLayout(grid)
        scroll.setWidget(container)

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(GRID_SPACING, GRID_SPACING, GRID_SPACING, GRID_SPACING) 
        layout.addWidget(scroll)

        # Lock the window size based on our calculations
        self.setFixedSize(final_width, final_height)

        # Fade-In Animation
        self.setWindowOpacity(0.0) 
        self.fade_in_animation = QtCore.QPropertyAnimation(self, b"windowOpacity")
        self.fade_in_animation.setDuration(400)
        self.fade_in_animation.setStartValue(0.0)
        self.fade_in_animation.setEndValue(1.0) 
        self.fade_in_animation.start()

        self.show()

    def get_pywal_colors(self):
        wal_cache = Path.home() / ".cache/wal/colors.css"
        colors = {}
        try:
            with open(wal_cache) as f:
                for line in f:
                    if ":" in line and "color" in line:
                        parts = line.split(":")
                        key = parts[0].strip().replace("--", "")
                        val = parts[1].strip().rstrip(";")
                        colors[key] = val
        except FileNotFoundError:
            return "#1d1f21", "#c5c8c6", "#5f819d"
        
        BG = colors.get("color0", "#1d1f21")
        FG = colors.get("color7", "#c5c8c6")
        BORDER = colors.get("color4", "#5f819d")
        return BG, FG, BORDER

    def select_wallpaper(self, wp):
        # Executes your setwall script
        try:
            subprocess.run([str(Path.home() / ".config/scripts/setwall.sh"), str(wp)])
        except Exception as e:
            print(f"Error running script: {e}")
        QtWidgets.QApplication.quit()

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key.Key_Escape:
            QtWidgets.QApplication.quit()
        super().keyPressEvent(event)

if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    picker = WallpaperPicker()
    sys.exit(app.exec())
