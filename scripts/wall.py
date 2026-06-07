#!/usr/bin/env python3
"""
wall.py — carousel wallpaper picker
Parallelogram cards, centre card enlarged, scroll with keys/wheel/click.
Usage: python wall.py [wallpaper_dir]
"""

import json
import math
import subprocess
import sys
from pathlib import Path

from PyQt6 import QtCore, QtGui, QtWidgets

# ── Config ────────────────────────────────────────────────────────────────────

WALLPAPER_DIR = (
    Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Pictures/Wallpapers"
)
FONT = "Hack Nerd Font"
SETWALL = Path.home() / ".config/scripts/setwall.sh"
WAL_CACHE = Path.home() / ".cache/wal/colors.json"
WAL_WALL = Path.home() / ".cache/wal/wal"

# Card dimensions
CARD_W = 200  # base card width (before scale)
CARD_H = 290  # base card height
SKEW = 0.15  # parallelogram lean (fraction of card width)
CENTER_SCALE = 1.50  # multiplier for the focused card
SIDE_SCALE = 0.78  # multiplier for adjacent cards
SPACING = 200  # px between card centres
VISIBLE = 3  # cards each side of centre that are drawn

# Animation
ANIM_MS = 300

# Window
WIN_H = 500

# ── Pywal helpers ─────────────────────────────────────────────────────────────


def load_pywal():
    defaults = ("#1a1a1a", "#c0caf5", "#7aa2f7", "#bb9af7")
    if not WAL_CACHE.exists():
        return defaults
    try:
        d = json.loads(WAL_CACHE.read_text())
        return (
            d["special"]["background"],
            d["special"]["foreground"],
            d["colors"].get("color4", defaults[2]),
            d["colors"].get("color5", defaults[3]),
        )
    except Exception:
        return defaults


def current_wall():
    return WAL_WALL.read_text().strip() if WAL_WALL.exists() else None


# ── Image helpers ─────────────────────────────────────────────────────────────


def load_images(directory: Path) -> list[Path]:
    if not directory.exists():
        return []
    exts = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
    return sorted(
        [p for p in directory.iterdir() if p.suffix.lower() in exts],
        key=lambda p: p.name.lower(),
    )


def scaled_crop(path: Path, w: int, h: int) -> QtGui.QPixmap:
    px = QtGui.QPixmap(str(path))
    if px.isNull():
        blank = QtGui.QPixmap(w, h)
        blank.fill(QtGui.QColor(30, 30, 40))
        return blank
    scaled = px.scaled(
        w,
        h,
        QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding,
        QtCore.Qt.TransformationMode.SmoothTransformation,
    )
    x = (scaled.width() - w) // 2
    y = (scaled.height() - h) // 2
    return scaled.copy(x, y, w, h)


# ── Async thumbnail loader ────────────────────────────────────────────────────


class ThumbLoader(QtCore.QThread):
    loaded = QtCore.pyqtSignal(int, QtGui.QPixmap)

    def __init__(self, images: list[Path]):
        super().__init__()
        self.images = images
        # Load centre-first by distance from index 0 initially; reordered after init
        self._order = list(range(len(images)))

    def set_priority(self, centre: int):
        n = len(self.images)
        self._order = sorted(range(n), key=lambda i: abs(i - centre))

    def run(self):
        max_w = int(CARD_W * CENTER_SCALE) + int(CARD_W * CENTER_SCALE * SKEW) + 10
        max_h = int(CARD_H * CENTER_SCALE) + 10
        for i in self._order:
            px = scaled_crop(self.images[i], max_w, max_h)
            self.loaded.emit(i, px)


# ── Carousel widget ───────────────────────────────────────────────────────────


class Carousel(QtWidgets.QWidget):
    def __init__(self, images: list[Path]):
        super().__init__()
        self.setWindowTitle("WallpaperPicker")
        self.images = images
        self.n = len(images)
        self.thumbs: dict[int, QtGui.QPixmap] = {}
        self.bg_pixmap: QtGui.QPixmap | None = None

        # Animated float: represents the visual centre position (card index)
        self._pos = 0.0

        # Find index of current wallpaper
        cw = current_wall()
        self._index = 0
        if cw:
            for i, p in enumerate(images):
                if str(p) == cw:
                    self._index = i
                    break
        self._pos = float(self._index)

        # Animation
        self._anim = QtCore.QPropertyAnimation(self, b"position")
        self._anim.setEasingCurve(QtCore.QEasingCurve.Type.OutCubic)
        self._anim.setDuration(ANIM_MS)

        # Pywal colours
        self.BG, self.FG, self.ACC, self.ACC2 = load_pywal()

        # Window setup
        self.setWindowFlags(
            QtCore.Qt.WindowType.FramelessWindowHint
            | QtCore.Qt.WindowType.WindowStaysOnTopHint
            | QtCore.Qt.WindowType.Tool,
        )
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setFocusPolicy(QtCore.Qt.FocusPolicy.StrongFocus)

        screen = QtGui.QGuiApplication.primaryScreen().availableGeometry()
        self.WIN_W = min(screen.width(), (VISIBLE * 2 + 1) * SPACING + CARD_W * 2)
        self.resize(self.WIN_W, WIN_H)
        # Centre on screen exactly like old wall.py
        qr = self.frameGeometry()
        qr.moveCenter(screen.center())
        self.move(qr.topLeft())

        # Blur background approximation via darkened current wallpaper
        self._rebuild_bg()

        # Load thumbnails
        self._loader = ThumbLoader(images)
        self._loader.set_priority(self._index)
        self._loader.loaded.connect(self._on_thumb)
        self._loader.start()

        # Pywal watcher
        self._watcher = QtCore.QFileSystemWatcher(self)
        for f in [WAL_CACHE, WAL_WALL]:
            if Path(str(f)).exists():
                self._watcher.addPath(str(f))
        self._watcher.fileChanged.connect(self._refresh_theme)

    # ── Qt property (enables QPropertyAnimation) ──────────────────────────────

    def _get_position(self) -> float:
        return self._pos

    def _set_position(self, v: float):
        self._pos = v
        self.update()

    position = QtCore.pyqtProperty(float, _get_position, _set_position)

    # ── Slots ─────────────────────────────────────────────────────────────────

    def _on_thumb(self, i: int, px: QtGui.QPixmap):
        self.thumbs[i] = px
        self.update()

    def _refresh_theme(self):
        self.BG, self.FG, self.ACC, self.ACC2 = load_pywal()
        self.update()

    # ── Navigation ────────────────────────────────────────────────────────────

    def _scroll_to(self, idx: int):
        idx = idx % self.n
        self._index = idx
        self._anim.stop()
        self._anim.setStartValue(self._pos)
        self._anim.setEndValue(float(idx))
        self._anim.start()
        self._rebuild_bg()

    def go_left(self):
        self._scroll_to(self._index - 1)

    def go_right(self):
        self._scroll_to(self._index + 1)

    def _apply(self):
        path = self.images[self._index]
        if SETWALL.exists():
            subprocess.Popen(["bash", str(SETWALL), str(path)])
        else:
            # fallback: try awww → swww → feh
            for cmd in (
                ["awww", "img", str(path), "--transition-type", "fade"],
                ["swww", "img", str(path)],
                ["feh", "--bg-fill", str(path)],
            ):
                try:
                    subprocess.Popen(cmd, stderr=subprocess.DEVNULL)
                    break
                except FileNotFoundError:
                    continue
        self.close()

    # ── Background ────────────────────────────────────────────────────────────

    def _rebuild_bg(self):
        path = self.images[self._index]
        px = scaled_crop(path, self.WIN_W, WIN_H)
        self.bg_pixmap = px
        self.update()

    # ── Input ─────────────────────────────────────────────────────────────────

    def keyPressEvent(self, e: QtGui.QKeyEvent):
        k = e.key()
        if k in (QtCore.Qt.Key.Key_Left, QtCore.Qt.Key.Key_H, QtCore.Qt.Key.Key_A):
            self.go_left()
        elif k in (QtCore.Qt.Key.Key_Right, QtCore.Qt.Key.Key_L, QtCore.Qt.Key.Key_D):
            self.go_right()
        elif k in (
            QtCore.Qt.Key.Key_Return,
            QtCore.Qt.Key.Key_Enter,
            QtCore.Qt.Key.Key_Space,
        ):
            self._apply()
        elif k == QtCore.Qt.Key.Key_Escape:
            self.close()

    def wheelEvent(self, e: QtGui.QWheelEvent):
        if e.angleDelta().y() < 0:
            self.go_right()
        else:
            self.go_left()

    def mousePressEvent(self, e: QtGui.QMouseEvent):
        if e.button() != QtCore.Qt.MouseButton.LeftButton:
            return
        cx = self.WIN_W / 2
        rel = (e.position().x() - cx) / SPACING
        if rel < -0.4:
            self.go_left()
        elif rel > 0.4:
            self.go_right()
        else:
            self._apply()

    # ── Paint ─────────────────────────────────────────────────────────────────

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        p.setRenderHint(QtGui.QPainter.RenderHint.SmoothPixmapTransform)

        W, H = self.WIN_W, WIN_H
        cx, cy = W / 2, H / 2

        # ── Background: blurred wallpaper approximated with darkened pixmap ──
        if self.bg_pixmap:
            p.drawPixmap(0, 0, self.bg_pixmap)
        p.fillRect(0, 0, W, H, QtGui.QColor(0, 0, 0, 155))

        if self.n == 0:
            p.setPen(QtGui.QColor(220, 220, 220))
            p.drawText(
                self.rect(),
                QtCore.Qt.AlignmentFlag.AlignCenter,
                f"No wallpapers found in\n{WALLPAPER_DIR}",
            )
            return

        # ── Draw cards back-to-front (farthest first) ─────────────────────────
        # Build list of (visual_distance, index) for all visible cards
        cards = []
        for di in range(-VISIBLE, VISIBLE + 1):
            idx = (self._index + di) % self.n
            visual_dist = di - (self._pos - self._index)  # signed float distance
            cards.append((visual_dist, idx))

        # Sort: draw farthest from centre first so centre is on top
        cards.sort(key=lambda t: abs(t[0]), reverse=True)

        for visual_dist, idx in cards:
            adist = abs(visual_dist)
            if adist > VISIBLE + 0.5:
                continue

            # ── Scale interpolation ───────────────────────────────────────────
            t = min(adist, 1.0)
            scale = CENTER_SCALE + (SIDE_SCALE - CENTER_SCALE) * t
            if adist > 1.0:
                beyond = adist - 1.0
                scale = SIDE_SCALE * max(0.0, 1.0 - beyond * 0.22)

            # ── Opacity ───────────────────────────────────────────────────────
            alpha = int(255 * max(0.0, 1.0 - adist * 0.38))
            if alpha <= 0:
                continue

            cw = int(CARD_W * scale)
            ch = int(CARD_H * scale)
            skew_px = int(cw * SKEW)
            total_w = cw + skew_px

            # Card centre on screen
            x_centre = cx + visual_dist * SPACING
            y_centre = cy

            x0 = x_centre - total_w / 2
            y0 = y_centre - ch / 2

            # ── Parallelogram path ────────────────────────────────────────────
            # Lean: top-right corner shifts right by skew_px
            path = QtGui.QPainterPath()
            path.moveTo(x0 + skew_px, y0)
            path.lineTo(x0 + skew_px + cw, y0)
            path.lineTo(x0 + cw, y0 + ch)
            path.lineTo(x0, y0 + ch)
            path.closeSubpath()

            p.save()
            p.setOpacity(alpha / 255)

            # ── Thumbnail ─────────────────────────────────────────────────────
            p.setClipPath(path)
            if idx in self.thumbs:
                src = self.thumbs[idx]
                sw, sh = src.width(), src.height()
                # Scale to fill parallelogram bounding rect
                s = max(total_w / sw, ch / sh)
                dw = sw * s
                dh = sh * s
                dx = x0 + (total_w - dw) / 2
                dy = y0 + (ch - dh) / 2
                p.drawPixmap(
                    QtCore.QRectF(dx, dy, dw, dh).toRect(),
                    src,
                )
            else:
                # Placeholder while loading
                p.fillPath(path, QtGui.QColor(25, 25, 35))

            # ── Side-card darkening overlay ───────────────────────────────────
            if adist > 0.05:
                darkness = int(min(adist, 1.5) / 1.5 * 140)
                p.fillPath(path, QtGui.QColor(0, 0, 0, darkness))

            p.restore()

            # ── Centre-card glow border ───────────────────────────────────────
            if adist < 0.12:
                glow_alpha = int((1.0 - adist / 0.12) * 180)
                pen = QtGui.QPen(QtGui.QColor(self.ACC))
                pen.setWidthF(1.8)
                c = QtGui.QColor(self.ACC)
                c.setAlpha(glow_alpha)
                pen.setColor(c)
                p.save()
                p.setOpacity(1.0)
                p.setPen(pen)
                p.setBrush(QtCore.Qt.BrushStyle.NoBrush)
                p.drawPath(path)
                p.restore()

            # ── Filename label under the centre card ──────────────────────────
            if adist < 0.05:
                name = self.images[idx].stem
                font = QtGui.QFont(FONT, 11, QtGui.QFont.Weight.Bold)
                p.save()
                p.setOpacity(0.92)
                p.setFont(font)
                fm = QtGui.QFontMetrics(font)
                tw = fm.horizontalAdvance(name)
                tx = int(cx - tw / 2)
                ty = int(y0 + ch + 30)
                # Drop shadow
                p.setPen(QtGui.QColor(0, 0, 0, 200))
                p.drawText(tx + 1, ty + 1, name)
                p.setPen(QtGui.QColor(255, 255, 255, 230))
                p.drawText(tx, ty, name)
                p.restore()

        # ── Arrow hints ───────────────────────────────────────────────────────
        p.setOpacity(0.30)
        p.setPen(QtGui.QColor(255, 255, 255))
        p.setFont(QtGui.QFont(FONT, 10))
        p.drawText(
            QtCore.QRect(0, H - 26, W, 20),
            QtCore.Qt.AlignmentFlag.AlignHCenter,
            "← → / scroll   ·   Enter to set   ·   Esc to close",
        )
        p.setOpacity(1.0)


# ── Entry ─────────────────────────────────────────────────────────────────────


def main():
    images = load_images(WALLPAPER_DIR)

    app = QtWidgets.QApplication(sys.argv)
    app.setApplicationName("wall")
    app.setDesktopFileName("wall")
    app.setFont(QtGui.QFont(FONT, 10))

    if not images:
        box = QtWidgets.QMessageBox()
        box.setWindowTitle("wall.py")
        box.setText(
            f"No wallpapers found in:\n{WALLPAPER_DIR}\n\nUsage: python wall.py [dir]"
        )
        box.exec()
        sys.exit(1)

    w = Carousel(images)
    w.show()
    w.raise_()
    w.activateWindow()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
