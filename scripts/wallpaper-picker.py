#!/usr/bin/env python3
import sys, subprocess
from pathlib import Path
from PyQt6 import QtWidgets, QtGui, QtCore

WALLPAPER_DIR = Path.home() / "Pictures/Wallpapers"
THUMB_SIZE = (350, 300)
THUMBS_PER_ROW = 4
MAX_VISIBLE_ROWS = 3
OPACITY = 200

class WallpaperPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Pick a wallpaper")
        self.setWindowFlag(QtCore.Qt.WindowType.WindowStaysOnTopHint)
        self.setWindowFlag(QtCore.Qt.WindowType.Tool)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        self.wallpapers = list(WALLPAPER_DIR.glob("*.[pj][pn]g"))
        if not self.wallpapers:
            QtWidgets.QMessageBox.warning(self, "Error", f"No wallpapers found in {WALLPAPER_DIR}")
            sys.exit(1)

        self.BG, self.FG, self.BORDER = self.get_pywal_colors()
        bg_color = QtGui.QColor(self.BG)
        bg_color.setAlpha(OPACITY)
        rgba_bg = f"rgba({bg_color.red()},{bg_color.green()},{bg_color.blue()},{bg_color.alpha()})"
        self.setStyleSheet(f"background-color: {rgba_bg};")

        scroll = QtWidgets.QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setStyleSheet(f"background-color: {rgba_bg}; QScrollBar:vertical {{ width: 0px; }}")

        container = QtWidgets.QWidget()
        container.setStyleSheet(f"background-color: {rgba_bg};")
        grid = QtWidgets.QGridLayout(container)
        grid.setSpacing(10)
        grid.setContentsMargins(10,10,10,10)

        row, col = 0, 0
        for wp in self.wallpapers:
            pixmap = QtGui.QPixmap(str(wp)).scaled(*THUMB_SIZE, QtCore.Qt.AspectRatioMode.KeepAspectRatio,
                                                  QtCore.Qt.TransformationMode.SmoothTransformation)
            btn = QtWidgets.QPushButton()
            btn.setIcon(QtGui.QIcon(pixmap))
            btn.setIconSize(pixmap.size())
            btn.setCursor(QtCore.Qt.CursorShape.PointingHandCursor)
            btn.setStyleSheet(f"""
                QPushButton {{
                    border: 2px solid {self.BORDER};
                    border-radius: 5px;
                    padding: 2px;
                    background-color: #00000000;
                }}
                QPushButton:hover {{
                    border: 2px solid {self.FG};
                }}
            """)
            # Fix closure capture
            btn.clicked.connect(lambda checked=False, w=wp: self.select_wallpaper(w))
            grid.addWidget(btn, row, col)
            col += 1
            if col >= THUMBS_PER_ROW:
                col = 0
                row += 1

        container.setLayout(grid)
        container_min_width = THUMB_SIZE[0]*THUMBS_PER_ROW + (THUMBS_PER_ROW-1)*grid.spacing() + grid.contentsMargins().left() + grid.contentsMargins().right() + 20
        container.setMinimumWidth(container_min_width)

        scroll.setWidget(container)
        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(scroll)

        visible_rows = min(row+1, MAX_VISIBLE_ROWS)
        total_height = THUMB_SIZE[1]*visible_rows + (visible_rows-1)*grid.spacing() + grid.contentsMargins().top() + grid.contentsMargins().bottom()
        self.resize(container_min_width + 20, total_height + 20)
        self.show()

    def get_pywal_colors(self):
        wal_cache = Path.home() / ".cache/wal/colors.css"
        colors = {}
        try:
            with open(wal_cache) as f:
                for i in range(16):
                    f.seek(0)
                    line_name = f"color{i}"
                    for l in f:
                        if line_name in l:
                            colors[f"color{i}"] = l.split(":")[1].strip().rstrip(";")
                            break
        except FileNotFoundError:
            return "#1d1f21", "#c5c8c6", "#5f819d"
        BG = colors.get("color0", "#1d1f21")
        FG = colors.get("color7", "#c5c8c6")
        BORDER = colors.get("color4", "#5f819d")
        return BG, FG, BORDER

    def select_wallpaper(self, wp):
        subprocess.run([str(Path.home() / ".config/scripts/setwall.sh"), str(wp)])
        QtWidgets.QApplication.quit()

if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    picker = WallpaperPicker()
    sys.exit(app.exec())
