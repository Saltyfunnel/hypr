#!/usr/bin/env python3
import sys, subprocess
from pathlib import Path
from PyQt6 import QtWidgets, QtGui, QtCore

# ---------------- CONFIG ----------------
WALLPAPER_DIR = Path.home() / "Pictures/Wallpapers"

THUMB_SIZE = (220, 140)
THUMBS_PER_ROW = 5
VISIBLE_ROWS = 3

GRID_SPACING = 14
BORDER_RADIUS = 12
# ----------------------------------------


class Thumbnail(QtWidgets.QLabel):
    def __init__(self, wp_path, click_callback, hover_color):
        super().__init__()
        self.wp_path = wp_path
        self.click_callback = click_callback
        self.hover_color = hover_color

        self.setCursor(QtCore.Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet("border-radius:8px; border:2px solid #444;")

        pixmap = QtGui.QPixmap(str(self.wp_path)).scaled(
            THUMB_SIZE[0], THUMB_SIZE[1],
            QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding,
            QtCore.Qt.TransformationMode.SmoothTransformation
        )
        self.setPixmap(pixmap)
        self.setFixedSize(THUMB_SIZE[0], THUMB_SIZE[1])

    def enterEvent(self, event):
        self.setStyleSheet(f"border-radius:8px; border:2px solid {self.hover_color};")
        super().enterEvent(event)

    def leaveEvent(self, event):
        self.setStyleSheet("border-radius:8px; border:2px solid #444;")
        super().leaveEvent(event)

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.MouseButton.LeftButton:
            self.click_callback(self.wp_path)
        super().mousePressEvent(event)


class WallpaperPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()

        # ----- Window (float in Hyprland) -----
        self.setWindowTitle("WallpaperPicker")
        self.setWindowFlags(
            QtCore.Qt.WindowType.Window |
            QtCore.Qt.WindowType.FramelessWindowHint
        )
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        # ----- Wallpapers -----
        self.wallpapers = sorted(list(WALLPAPER_DIR.glob("*.[pj][pn]g")))
        if not self.wallpapers:
            QtWidgets.QMessageBox.critical(None, "Error", "No wallpapers found!")
            sys.exit(1)

        # ----- Pywal Colors -----
        self.BG, self.FG, self.HOVER = self.get_pywal_colors()
        self.tint_color = QtGui.QColor(self.BG)
        self.tint_color.setAlpha(180)

        # ----- Layout -----
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(GRID_SPACING, GRID_SPACING, GRID_SPACING, GRID_SPACING)

        scroll = QtWidgets.QScrollArea()
        scroll.setWidgetResizable(True)

        # 🔥 hide scrollbars completely
        scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setStyleSheet("background: transparent; border: none;")

        container = QtWidgets.QWidget()
        grid = QtWidgets.QGridLayout(container)
        grid.setSpacing(GRID_SPACING)
        grid.setContentsMargins(0, 0, 0, 0)

        # Thumbnails
        row = col = 0
        for wp in self.wallpapers:
            thumb = Thumbnail(wp, self.select_wallpaper, self.HOVER)
            grid.addWidget(thumb, row, col)
            col += 1
            if col >= THUMBS_PER_ROW:
                col = 0
                row += 1

        scroll.setWidget(container)
        layout.addWidget(scroll)

        # ----- Window Size (3 visible rows) -----
        rows = min(VISIBLE_ROWS, row + 1)

        width = (THUMBS_PER_ROW * THUMB_SIZE[0]) + ((THUMBS_PER_ROW + 1) * GRID_SPACING)
        height = (rows * THUMB_SIZE[1]) + ((rows + 1) * GRID_SPACING)

        self.resize(width, height)

    # --------- Helpers ---------

    def select_wallpaper(self, wp_path):
        subprocess.run([str(Path.home() / ".config/scripts/setwall.sh"), str(wp_path)])
        QtWidgets.QApplication.quit()

    def get_pywal_colors(self):
        wal_cache = Path.home() / ".cache/wal/colors.css"
        try:
            with open(wal_cache) as f:
                colors = {
                    line.split(":")[0].strip().replace("--", ""):
                    line.split(":")[1].strip().rstrip(";")
                    for line in f if ":" in line
                }
            return (
                colors.get("color0", "#1a1a1a"),
                colors.get("color7", "#ffffff"),
                colors.get("color4", "#00aaff")
            )
        except:
            return "#1a1a1a", "#ffffff", "#00aaff"

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        painter.setBrush(QtGui.QBrush(self.tint_color))
        painter.setPen(QtGui.QPen(QtGui.QColor(self.HOVER), 2))
        painter.drawRoundedRect(self.rect().adjusted(1,1,-1,-1), BORDER_RADIUS, BORDER_RADIUS)

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key.Key_Escape:
            QtWidgets.QApplication.quit()


# ---------------- MAIN ----------------

if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    picker = WallpaperPicker()
    picker.show()
    sys.exit(app.exec())
