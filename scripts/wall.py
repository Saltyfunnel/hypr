#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

from PyQt6 import QtCore, QtGui, QtWidgets

WALLPAPER_DIR = Path.home() / "Pictures/Wallpapers"
TILE_W = 220
TILE_H = 140
SKEW = 28
STEP = TILE_W
STRIP_PAD = 30


def load_pywal():
    try:
        data = json.loads((Path.home() / ".cache/wal/colors.json").read_text())
        c = data.get("colors", {})
        return (
            c.get("color0", "#1a1a1a"),
            c.get("color7", "#ffffff"),
            c.get("color4", "#89b4fa"),
        )
    except Exception:
        return "#1a1a1a", "#ffffff", "#89b4fa"


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
                    TILE_W + SKEW * 2,
                    TILE_H,
                    QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                    QtCore.Qt.TransformationMode.SmoothTransformation,
                )
            self.loaded.emit(i, img)


class StripCanvas(QtWidgets.QWidget):
    wallpaper_selected = QtCore.pyqtSignal(Path)

    def __init__(self, wallpapers, accent, fg, parent=None):
        super().__init__(parent)
        self.wallpapers = wallpapers
        self.accent = QtGui.QColor(accent)
        self.fg = QtGui.QColor(fg)
        self.selected = -1
        self.hovered = -1

        self._thumbs = [QtGui.QPixmap()] * len(wallpapers)

        self.setFixedSize(STRIP_PAD + len(wallpapers) * STEP + SKEW + STRIP_PAD, TILE_H)
        self.setMouseTracking(True)

        self._loader = ThumbLoader(wallpapers)
        self._loader.loaded.connect(self._on_thumb)
        self._loader.start()

    def _on_thumb(self, i, img):
        if not img.isNull():
            self._thumbs[i] = QtGui.QPixmap.fromImage(img)
            self.update()

    def _poly(self, i):
        x = STRIP_PAD + i * STEP
        return QtGui.QPolygonF(
            [
                QtCore.QPointF(x + SKEW, 0),
                QtCore.QPointF(x + TILE_W + SKEW, 0),
                QtCore.QPointF(x + TILE_W, TILE_H),
                QtCore.QPointF(x, TILE_H),
            ]
        )

    def _hit(self, pos):
        for i in range(len(self.wallpapers) - 1, -1, -1):
            pp = QtGui.QPainterPath()
            pp.addPolygon(self._poly(i))
            if pp.contains(pos):
                return i
        return -1

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        p.setRenderHint(QtGui.QPainter.RenderHint.SmoothPixmapTransform)

        for i, (wp, px) in enumerate(zip(self.wallpapers, self._thumbs)):
            poly = self._poly(i)
            clip = QtGui.QPainterPath()
            clip.addPolygon(poly)
            tx = STRIP_PAD + i * STEP

            p.save()
            p.setClipPath(clip)

            if not px.isNull():
                p.drawPixmap(
                    tx + (TILE_W - px.width()) // 2, (TILE_H - px.height()) // 2, px
                )
            else:
                p.fillPath(clip, QtGui.QColor("#2a2a2a"))

            if i == self.selected:
                ov = QtGui.QColor(self.accent)
                ov.setAlpha(90)
                p.fillPath(clip, ov)
            elif i == self.hovered:
                p.fillPath(clip, QtGui.QColor(255, 255, 255, 35))

            if i in (self.hovered, self.selected):
                font = QtGui.QFont("Hack Nerd Font", 9)
                fm = QtGui.QFontMetrics(font)
                lbl = fm.elidedText(
                    wp.stem, QtCore.Qt.TextElideMode.ElideMiddle, TILE_W - 16
                )
                lh = fm.height() + 4
                p.fillRect(
                    QtCore.QRectF(tx, TILE_H - lh - 4, TILE_W + SKEW, lh + 6),
                    QtGui.QColor(0, 0, 0, 160),
                )
                p.setFont(font)
                p.setPen(QtGui.QColor(self.fg))
                p.drawText(tx + 10, TILE_H - 8, lbl)

            p.restore()

            pen_col = (
                QtGui.QColor(self.accent)
                if i in (self.selected, self.hovered)
                else QtGui.QColor(255, 255, 255, 45)
            )
            pen_w = 2.0 if i == self.selected else (1.5 if i == self.hovered else 0.8)
            p.setPen(QtGui.QPen(pen_col, pen_w))
            p.setBrush(QtCore.Qt.BrushStyle.NoBrush)
            p.drawPolygon(poly)

    def mouseMoveEvent(self, e):
        idx = self._hit(e.position())
        if idx != self.hovered:
            self.hovered = idx
            self.update()
            self.setCursor(
                QtGui.QCursor(
                    QtCore.Qt.CursorShape.PointingHandCursor
                    if idx >= 0
                    else QtCore.Qt.CursorShape.ArrowCursor
                )
            )

    def leaveEvent(self, e):
        self.hovered = -1
        self.update()

    def mousePressEvent(self, e):
        if e.button() == QtCore.Qt.MouseButton.LeftButton:
            idx = self._hit(e.position())
            if idx >= 0:
                self.selected = idx
                self.update()
                self.wallpaper_selected.emit(self.wallpapers[idx])


class WallpaperPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("WallpaperPicker")
        self.setWindowFlags(
            QtCore.Qt.WindowType.Window | QtCore.Qt.WindowType.FramelessWindowHint
        )
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        self.bg, self.fg, self.accent = load_pywal()
        self._drag_pos = None

        wallpapers = sorted(
            {*WALLPAPER_DIR.glob("*.[pj][pn]g"), *WALLPAPER_DIR.glob("*.webp")}
        )
        if not wallpapers:
            QtWidgets.QMessageBox.critical(
                None, "Error", f"No wallpapers in {WALLPAPER_DIR}"
            )
            sys.exit(1)

        self._build(wallpapers)
        self._style()

    def _build(self, wallpapers):
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # ── Title bar ──
        bar = QtWidgets.QWidget()
        bar.setObjectName("bar")
        bar.setFixedHeight(28)
        bl = QtWidgets.QHBoxLayout(bar)
        bl.setContentsMargins(12, 0, 8, 0)
        bl.setSpacing(6)
        lbl = QtWidgets.QLabel("\uf03e  Wallpapers")
        lbl.setFont(QtGui.QFont("Hack Nerd Font", 9))
        lbl.setObjectName("bartitle")
        bl.addWidget(lbl, stretch=1)
        close = QtWidgets.QPushButton("×")
        close.setObjectName("closebtn")
        close.setFixedSize(20, 20)
        close.setFont(QtGui.QFont("Hack Nerd Font", 12))
        close.clicked.connect(self.close)
        bl.addWidget(close)
        bar.mousePressEvent = lambda e: setattr(
            self,
            "_drag_pos",
            e.globalPosition().toPoint() - self.frameGeometry().topLeft()
            if e.button() == QtCore.Qt.MouseButton.LeftButton
            else None,
        )
        bar.mouseMoveEvent = lambda e: (
            self.move(e.globalPosition().toPoint() - self._drag_pos)
            if (e.buttons() & QtCore.Qt.MouseButton.LeftButton) and self._drag_pos
            else None
        )
        bar.mouseReleaseEvent = lambda e: setattr(self, "_drag_pos", None)
        root.addWidget(bar)

        # ── Strip ──
        class HScroll(QtWidgets.QScrollArea):
            def wheelEvent(self, e):
                bar = self.horizontalScrollBar()
                bar.setValue(bar.value() - e.angleDelta().y())

        scroll = HScroll()
        scroll.setObjectName("scroll")
        scroll.setWidgetResizable(False)
        scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        scroll.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setFixedHeight(TILE_H + 8)
        self.canvas = StripCanvas(wallpapers, self.accent, self.fg)
        self.canvas.wallpaper_selected.connect(self._apply)
        scroll.setWidget(self.canvas)
        root.addWidget(scroll)

        # ── Size and center ──
        screen = QtWidgets.QApplication.primaryScreen().availableGeometry()
        w = min(self.canvas.width() + 4, int(screen.width() * 0.80))
        w = max(w, 420)
        h = 28 + TILE_H + 8  # titlebar + strip + scrollbar
        self.resize(w, h)
        self.move(
            screen.x() + (screen.width() - w) // 2,
            screen.y() + int(screen.height() * 0.65),
        )

    def _style(self):
        bg = QtGui.QColor(self.bg)
        ac = QtGui.QColor(self.accent)
        r, g, b = bg.red(), bg.green(), bg.blue()
        ar, ag, ab = ac.red(), ac.green(), ac.blue()
        fg = self.fg
        self.setStyleSheet(f"""
            WallpaperPicker {{ background: transparent; }}
            #bar {{
                background: rgba({r},{g},{b},220);
                border-top-left-radius: 10px; border-top-right-radius: 10px;
                border-bottom: 1px solid rgba(255,255,255,0.07);
            }}
            #bartitle {{ color:{fg}; background:transparent; }}
            #closebtn {{ background:transparent; color:rgba(255,255,255,0.35);
                         border:none; border-radius:4px; }}
            #closebtn:hover {{ background:rgba(255,255,255,0.1); color:{fg}; }}
            #scroll {{
                background:rgba({r},{g},{b},210); border:none;
                border-bottom-left-radius: 10px; border-bottom-right-radius: 10px;
            }}
            StripCanvas {{ background:transparent; }}
            QScrollBar:horizontal {{ height:4px; background:transparent; margin:0; }}
            QScrollBar::handle:horizontal {{
                background:rgba({ar},{ag},{ab},100); border-radius:2px; min-width:30px; }}
            QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {{ width:0; }}
        """)

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        bg = QtGui.QColor(self.bg)
        bg.setAlpha(200)
        ac = QtGui.QColor(self.accent)
        ac.setAlpha(90)
        p.setBrush(QtGui.QBrush(bg))
        p.setPen(QtGui.QPen(ac, 1.5))
        p.drawRoundedRect(self.rect().adjusted(1, 1, -1, -1), 10, 10)

    def _apply(self, wp: Path):
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
    app.setDesktopFileName("WallpaperPicker")
    w = WallpaperPicker()
    w.show()

    def reposition():
        screen = QtWidgets.QApplication.primaryScreen().availableGeometry()
        cw = w.canvas.width() + 4
        ww = min(cw, int(screen.width() * 0.80))
        ww = max(ww, 420)
        wh = 28 + TILE_H + 8
        w.resize(ww, wh)
        w.move(
            screen.x() + (screen.width() - ww) // 2,
            screen.y() + int(screen.height() * 0.65),
        )

    QtCore.QTimer.singleShot(50, reposition)
    sys.exit(app.exec())
