#!/usr/bin/env python3
"""
wall.py — carousel wallpaper picker
Parallelogram cards, centre card enlarged, scroll with keys/wheel/click.
Usage: python wall.py [wallpaper_dir]
"""

import json
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
CARD_W = 160  # base card width (before scale)
CARD_H = 240  # base card height
SKEW = 0.15  # parallelogram lean (fraction of card width)
CENTER_SCALE = 1.45  # multiplier for the focused card
SIDE_SCALE = 0.80  # multiplier for adjacent cards
SPACING = 130  # px between card centres
VISIBLE = (
    6  # cards each side of centre that are drawn (was 8; beyond 6 are invisible anyway)
)

# Animation — spring strength (0.12 = gentle, 0.22 = snappy)
SPRING = 0.16

# Window
WIN_W = 1100
WIN_H = 520

# ── Helpers ───────────────────────────────────────────────────────────────────


def load_pywal() -> tuple[str, str, str, str]:
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


def current_wall() -> str | None:
    return WAL_WALL.read_text().strip() if WAL_WALL.exists() else None


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


# ── Cached fonts ──────────────────────────────────────────────────────────────

_FONT_CACHE: dict[tuple, QtGui.QFont] = {}


def get_font(size: int, bold: bool = False) -> QtGui.QFont:
    key = (size, bold)
    if key not in _FONT_CACHE:
        f = QtGui.QFont(FONT, size)
        if bold:
            f.setWeight(QtGui.QFont.Weight.Bold)
        _FONT_CACHE[key] = f
    return _FONT_CACHE[key]


# ── Async thumbnail loader ────────────────────────────────────────────────────


class ThumbLoader(QtCore.QThread):
    """Loads thumbnails in a background thread, emitting (index, pixmap) per image."""

    loaded = QtCore.pyqtSignal(int, QtGui.QPixmap)

    def __init__(self, images: list[Path], centre: int = 0):
        super().__init__()
        self.images = images
        self._centre = centre
        self._stop = False

    def stop(self):
        self._stop = True
        self.wait()

    def run(self):
        n = len(self.images)
        # Load outward from the starting centre index
        order = sorted(range(n), key=lambda i: abs(i - self._centre))
        max_w = int(CARD_W * CENTER_SCALE) + int(CARD_W * CENTER_SCALE * SKEW) + 10
        max_h = int(CARD_H * CENTER_SCALE) + 10
        for i in order:
            if self._stop:
                return
            px = scaled_crop(self.images[i], max_w, max_h)
            self.loaded.emit(i, px)


# ── Background loader ─────────────────────────────────────────────────────────


class BgLoader(QtCore.QThread):
    """Loads and scales a single background image without blocking the main thread."""

    ready = QtCore.pyqtSignal(QtGui.QPixmap)

    def __init__(self, path: Path):
        super().__init__()
        self._path = path

    def run(self):
        px = scaled_crop(self._path, WIN_W, WIN_H)
        self.ready.emit(px)


# ── Carousel widget ───────────────────────────────────────────────────────────


class Carousel(QtWidgets.QWidget):
    def __init__(self, images: list[Path]):
        super().__init__()
        self.setWindowTitle("WallpaperPicker")
        self.images = images
        self.n = len(images)

        self.thumbs: dict[int, QtGui.QPixmap] = {}
        self.bg_pixmap: QtGui.QPixmap | None = None
        self._bg_loader: BgLoader | None = None

        # Find index of current wallpaper
        cw = current_wall()
        self._index = 0
        if cw:
            for i, p in enumerate(images):
                if str(p) == cw:
                    self._index = i
                    break

        # _pos: animated float index of the visual centre card.
        # _target: where _pos is heading (advances by ±1 per scroll step).
        # We use a spring/lerp loop via QTimer rather than QPropertyAnimation
        # so repaints are frame-locked and rapid scrolls accumulate smoothly.
        self._pos = float(self._index)
        self._target = float(self._index)

        # Frame timer — fires every ~8 ms (~120 fps ceiling), stops when at rest
        self._anim_timer = QtCore.QTimer(self)
        self._anim_timer.setInterval(8)
        self._anim_timer.timeout.connect(self._anim_tick)

        # Pywal colours
        self.BG, self.FG, self.ACC, self.ACC2 = load_pywal()

        # Window
        self.setWindowFlags(
            QtCore.Qt.WindowType.FramelessWindowHint
            | QtCore.Qt.WindowType.WindowStaysOnTopHint
            | QtCore.Qt.WindowType.Tool,
        )
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setFocusPolicy(QtCore.Qt.FocusPolicy.StrongFocus)
        self.resize(WIN_W, WIN_H)

        screen = QtGui.QGuiApplication.primaryScreen().availableGeometry()
        self.move(screen.center() - self.rect().center())

        # Kick off background load (async — no stutter on open)
        self._load_bg(self._index)

        # Load thumbnails from background thread
        self._loader = ThumbLoader(images, centre=self._index)
        self._loader.loaded.connect(self._on_thumb)
        self._loader.start()

        # Pywal file watcher
        self._watcher = QtCore.QFileSystemWatcher(self)
        for f in [WAL_CACHE, WAL_WALL]:
            if Path(str(f)).exists():
                self._watcher.addPath(str(f))
        self._watcher.fileChanged.connect(self._refresh_theme)

    # ── Animation tick ────────────────────────────────────────────────────────

    def _anim_tick(self):
        """Spring-lerp _pos toward _target each timer tick; stop when close enough."""
        diff = self._target - self._pos
        if abs(diff) < 0.0005:
            self._pos = self._target
            self._anim_timer.stop()
        else:
            self._pos += diff * SPRING
        self.update()

    # ── Slots ─────────────────────────────────────────────────────────────────

    def _on_thumb(self, i: int, px: QtGui.QPixmap):
        self.thumbs[i] = px
        self.update()

    def _on_bg_ready(self, px: QtGui.QPixmap):
        self.bg_pixmap = px
        self.update()

    def _refresh_theme(self):
        self.BG, self.FG, self.ACC, self.ACC2 = load_pywal()
        self.update()

    # ── Background loading ────────────────────────────────────────────────────

    def _load_bg(self, idx: int):
        """Start an async background image load for the given index."""
        # Prefer an already-loaded thumb if available and large enough — good enough as bg
        if idx in self.thumbs:
            self.bg_pixmap = self.thumbs[idx].scaled(
                WIN_W,
                WIN_H,
                QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                QtCore.Qt.TransformationMode.SmoothTransformation,
            )
            self.update()
            return

        # Stop any previous bg load
        if self._bg_loader and self._bg_loader.isRunning():
            self._bg_loader.ready.disconnect()
            self._bg_loader.quit()

        self._bg_loader = BgLoader(self.images[idx])
        self._bg_loader.ready.connect(self._on_bg_ready)
        self._bg_loader.start()

    # ── Navigation ────────────────────────────────────────────────────────────

    def _scroll_to(self, new_index: int):
        # Advance _target by the signed delta so rapid presses accumulate
        # rather than restarting — the spring catches up naturally.
        delta = new_index - self._index
        self._index = new_index % self.n
        self._target += delta

        if not self._anim_timer.isActive():
            self._anim_timer.start()

        self._load_bg(self._index)

    def go_left(self):
        self._scroll_to(self._index - 1)

    def go_right(self):
        self._scroll_to(self._index + 1)

    def _apply(self):
        path = self.images[self._index]
        if SETWALL.exists():
            subprocess.Popen(["bash", str(SETWALL), str(path)], start_new_session=True)
        else:
            for cmd in (
                ["awww", "img", str(path), "--transition-type", "fade"],
                ["swww", "img", str(path)],
                ["feh", "--bg-fill", str(path)],
            ):
                try:
                    subprocess.Popen(
                        cmd, stderr=subprocess.DEVNULL, start_new_session=True
                    )
                    break
                except FileNotFoundError:
                    continue
        self.close()

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
        """Click a visible card to jump to it; click the centre card to apply."""
        if e.button() != QtCore.Qt.MouseButton.LeftButton:
            return

        mx = e.position().x()
        cx = WIN_W / 2
        best = None  # (abs_dist_from_click, signed_offset)

        # Test every rendered card and find the closest one to the click
        # anim_offset: how far _pos has travelled past the nearest integer
        anim_offset = self._pos - round(self._pos)

        for di in range(-VISIBLE, VISIBLE + 1):
            idx_mod = (self._index + di) % self.n
            vdist = di - anim_offset
            adist = abs(vdist)
            if adist > VISIBLE + 0.5:
                continue

            # Replicate the same scale/skew from paintEvent
            t = min(adist, 1.0)
            scale = CENTER_SCALE + (SIDE_SCALE - CENTER_SCALE) * t
            if adist > 1.0:
                scale = SIDE_SCALE * max(0.0, 1.0 - (adist - 1.0) * 0.22)

            cw = int(CARD_W * scale)
            skew_px = int(cw * SKEW)
            total_w = cw + skew_px
            x_centre = cx + vdist * SPACING
            x_left = x_centre - total_w / 2
            x_right = x_centre + total_w / 2

            if x_left <= mx <= x_right:
                dist = abs(mx - x_centre)
                if best is None or dist < best[0]:
                    best = (dist, di)

        if best is None:
            return

        offset = best[1]
        if offset == 0:
            self._apply()
        else:
            self._scroll_to(self._index + offset)

    def closeEvent(self, e):
        self._anim_timer.stop()
        self._loader.stop()
        if self._bg_loader and self._bg_loader.isRunning():
            self._bg_loader.quit()
            self._bg_loader.wait()
        super().closeEvent(e)

    # ── Paint ─────────────────────────────────────────────────────────────────

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        p.setRenderHint(QtGui.QPainter.RenderHint.SmoothPixmapTransform)

        W, H = WIN_W, WIN_H
        cx = W / 2
        cy = H / 2

        # ── Background ────────────────────────────────────────────────────────
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

        # ── Build card list ───────────────────────────────────────────────────
        # anim_offset: fractional overshoot of _pos past the nearest integer.
        # Subtracting it from di gives each card its correct visual position
        # during animation — positive when scrolling right, negative when left.
        anim_offset = self._pos - round(self._pos)

        cards = []
        for di in range(-VISIBLE, VISIBLE + 1):
            idx = (self._index + di) % self.n
            vdist = di - anim_offset
            adist = abs(vdist)
            alpha_f = max(0.0, 1.0 - adist * 0.17)
            if alpha_f <= 0.01:
                continue
            cards.append((adist, vdist, idx, int(alpha_f * 255)))

        # Draw farthest-from-centre first so centre is on top
        cards.sort(key=lambda t: t[0], reverse=True)

        for adist, vdist, idx, alpha in cards:
            # ── Scale ─────────────────────────────────────────────────────────
            t = min(adist, 1.0)
            scale = CENTER_SCALE + (SIDE_SCALE - CENTER_SCALE) * t
            if adist > 1.0:
                scale = SIDE_SCALE * max(0.0, 1.0 - (adist - 1.0) * 0.22)

            cw = int(CARD_W * scale)
            ch = int(CARD_H * scale)
            skew_px = int(cw * SKEW)
            total_w = cw + skew_px

            x_centre = cx + vdist * SPACING
            y_centre = cy
            x0 = x_centre - total_w / 2
            y0 = y_centre - ch / 2

            # ── Parallelogram path ────────────────────────────────────────────
            path = QtGui.QPainterPath()
            path.moveTo(x0 + skew_px, y0)
            path.lineTo(x0 + skew_px + cw, y0)
            path.lineTo(x0 + cw, y0 + ch)
            path.lineTo(x0, y0 + ch)
            path.closeSubpath()

            p.save()
            p.setOpacity(alpha / 255)
            p.setClipPath(path)

            # ── Thumbnail or placeholder ──────────────────────────────────────
            if idx in self.thumbs:
                src = self.thumbs[idx]
                sw, sh = src.width(), src.height()
                s = max(total_w / sw, ch / sh)
                dw = sw * s
                dh = sh * s
                dx = x0 + (total_w - dw) / 2
                dy = y0 + (ch - dh) / 2
                p.drawPixmap(QtCore.QRectF(dx, dy, dw, dh).toRect(), src)
            else:
                # Animated shimmer placeholder while loading
                grad = QtGui.QLinearGradient(x0, y0, x0 + total_w, y0)
                grad.setColorAt(0.0, QtGui.QColor(30, 30, 45))
                grad.setColorAt(0.5, QtGui.QColor(50, 50, 70))
                grad.setColorAt(1.0, QtGui.QColor(30, 30, 45))
                p.fillPath(path, QtGui.QBrush(grad))

            # ── Side-card darkening ───────────────────────────────────────────
            if adist > 0.05:
                darkness = int(min(adist, 1.5) / 1.5 * 140)
                p.fillPath(path, QtGui.QColor(0, 0, 0, darkness))

            p.restore()

            # ── Centre-card accent border ─────────────────────────────────────
            if adist < 0.12:
                glow_alpha = int((1.0 - adist / 0.12) * 200)
                c = QtGui.QColor(self.ACC)
                c.setAlpha(glow_alpha)
                pen = QtGui.QPen(c)
                pen.setWidthF(2.0)
                p.save()
                p.setOpacity(1.0)
                p.setPen(pen)
                p.setBrush(QtCore.Qt.BrushStyle.NoBrush)
                p.drawPath(path)
                p.restore()

            # ── Filename label beneath centre card ────────────────────────────
            if adist < 0.05:
                name = self.images[idx].stem
                font = get_font(11, bold=True)
                p.save()
                p.setOpacity(0.92)
                p.setFont(font)
                fm = QtGui.QFontMetrics(font)
                tw = fm.horizontalAdvance(name)
                tx = int(cx - tw / 2)
                ty = int(y0 + ch + 28)
                p.setPen(QtGui.QColor(0, 0, 0, 200))
                p.drawText(tx + 1, ty + 1, name)
                p.setPen(QtGui.QColor(255, 255, 255, 230))
                p.drawText(tx, ty, name)
                p.restore()

        # ── Hint bar ─────────────────────────────────────────────────────────
        p.setOpacity(0.30)
        p.setPen(QtGui.QColor(255, 255, 255))
        p.setFont(get_font(10))
        p.drawText(
            QtCore.QRect(0, H - 26, W, 20),
            QtCore.Qt.AlignmentFlag.AlignHCenter,
            "← → / hjkl / scroll   ·   Enter to set   ·   Esc to close",
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
