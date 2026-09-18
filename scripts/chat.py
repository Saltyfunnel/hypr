#!/usr/bin/env python3
"""PyQt6 chat GUI for Ollama with RGBA transparency, Nerd Font icons, smart hardware detection, and live status."""

import json
import subprocess
import shutil
import sys
import time
import urllib.request
from pathlib import Path

from PyQt6.QtCore import Qt, QThread, pyqtSignal
from PyQt6.QtGui import QColor, QFont
from PyQt6.QtWidgets import (
    QApplication, QCheckBox, QComboBox, QHBoxLayout, QLabel, QPlainTextEdit,
    QPushButton, QTextBrowser, QVBoxLayout, QWidget,
)

HOST = "http://localhost:11434"
FONT = "Hack Nerd Font"


def find_ollama():
    """Locate the ollama binary across standard system and user paths."""
    found = shutil.which("ollama")
    if found:
        return found

    candidates = [
        Path("/usr/bin/ollama"),
        Path("/usr/local/bin/ollama"),
        Path.home() / ".local/bin/ollama",
        Path("/opt/ollama/ollama"),
    ]
    for c in candidates:
        if c.is_file():
            return str(c)

    return None


def detect_optimal_model():
    """Distinguish between dedicated desktop GPUs and laptops/integrated graphics."""
    vram_gb = 0

    if shutil.which("nvidia-smi"):
        try:
            res = subprocess.run(
                ["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits"],
                capture_output=True, text=True, timeout=2
            )
            if res.returncode == 0:
                vram_gb = int(res.stdout.strip().split("\n")[0]) / 1024
        except Exception:
            pass

    if vram_gb == 0:
        try:
            for card_path in Path("/sys/class/drm").glob("card*"):
                vram_file = card_path / "device" / "mem_info_vram_total"
                if vram_file.exists():
                    vram_bytes = int(vram_file.read_text().strip())
                    vram_gb = max(vram_gb, vram_bytes / (1024 ** 3))
        except Exception:
            pass

    if vram_gb >= 22:
        return "qwen3:32b"
    elif vram_gb >= 12:
        return "qwen3:14b"
    elif vram_gb >= 6:
        return "qwen2.5:7b"
    elif vram_gb > 0:
        return "qwen2.5:3b"

    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if "MemTotal" in line:
                    sys_ram_gb = int(line.split()[1]) / (1024 * 1024)
                    if sys_ram_gb >= 24:
                        return "qwen2.5:7b"
                    break
    except Exception:
        pass

    return "qwen2.5:3b"


DEFAULT_MODEL = detect_optimal_model()


def load_colors():
    c = dict(bg="#1e1e2e", fg="#cdd6f4", accent="#89b4fa", dim="#6c7086")
    try:
        w = json.loads((Path.home() / ".cache/wal/colors.json").read_text())
        bg = w["special"]["background"]
        fg = w["special"]["foreground"]
        accent = w["colors"]["color4"]
        dim = w["colors"]["color8"]

        if bg.strip() == "#000000":
            bg = "#181825"

        c.update(bg=bg, fg=fg, accent=accent, dim=dim)
    except Exception:
        pass
    return c


def hex_to_rgba(hex_str, alpha=0.82):
    """Convert pywal hex color to an RGBA string for crisp transparent window ricing."""
    hex_str = hex_str.lstrip('#')
    if len(hex_str) != 6:
        return f"rgba(30, 30, 46, {alpha})"
    r = int(hex_str[0:2], 16)
    g = int(hex_str[2:4], 16)
    b = int(hex_str[4:6], 16)
    return f"rgba({r}, {g}, {b}, {alpha})"


def style(c):
    bg_rgba = hex_to_rgba(c["bg"], 0.82)
    surf_rgba = hex_to_rgba(c["bg"], 0.55)
    input_bg = hex_to_rgba(c["bg"], 0.35)
    return f"""
    QWidget {{
        background: {bg_rgba};
        color: {c['fg']};
    }}
    QTextBrowser {{
        background: {surf_rgba};
        border: 1px solid {c['dim']};
        border-radius: 12px;
        padding: 14px;
        selection-background-color: {c['accent']};
        selection-color: {c['bg']};
    }}
    QPlainTextEdit {{
        background: {input_bg};
        border: 1px solid {c['dim']};
        border-top-left-radius: 12px;
        border-bottom-left-radius: 12px;
        border-top-right-radius: 0px;
        border-bottom-right-radius: 0px;
        padding: 10px;
        selection-background-color: {c['accent']};
        selection-color: {c['bg']};
    }}
    QPlainTextEdit:focus {{
        border-color: {c['accent']};
    }}
    QPushButton#send_btn {{
        background: {surf_rgba};
        border: 1px solid {c['dim']};
        border-left: none;
        border-top-right-radius: 12px;
        border-bottom-right-radius: 12px;
        border-top-left-radius: 0px;
        border-bottom-left-radius: 0px;
        padding: 0px 20px;
        font-weight: 600;
    }}
    QPushButton#send_btn:hover {{
        border-color: {c['accent']};
        color: {c['accent']};
    }}
    QComboBox, QPushButton {{
        background: {surf_rgba};
        border: 1px solid {c['dim']};
        border-radius: 10px;
        padding: 6px 14px;
        font-weight: 600;
    }}
    QComboBox:hover, QPushButton:hover {{
        border-color: {c['accent']};
    }}
    QComboBox QAbstractItemView {{
        background: {c['bg']};
        selection-background-color: {c['accent']};
        selection-color: {c['bg']};
        border: 1px solid {c['dim']};
    }}
    QCheckBox {{
        background: transparent;
        spacing: 8px;
        font-weight: 600;
    }}
    QLabel {{
        background: transparent;
        color: {c['dim']};
        font-weight: 600;
    }}
    QScrollBar:vertical {{
        width: 8px;
        background: transparent;
    }}
    QScrollBar::handle:vertical {{
        background: {c['dim']};
        border-radius: 4px;
        min-height: 24px;
    }}
    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
        height: 0;
    }}
    """


class Stream(QThread):
    chunk = pyqtSignal(str, str)
    failed = pyqtSignal(str)

    def __init__(self, model, messages, think):
        super().__init__()
        self.model, self.messages, self.think = model, messages, think
        self._halt = False

    def halt(self):
        self._halt = True

    def run(self):
        body = json.dumps({
            "model": self.model,
            "messages": self.messages,
            "stream": True,
            "think": self.think,
        }).encode()
        req = urllib.request.Request(
            f"{HOST}/api/chat", body, {"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                for line in r:
                    if self._halt:
                        break
                    if not line.strip():
                        continue
                    d = json.loads(line)
                    if "error" in d:
                        self.failed.emit(d["error"])
                        return
                    m = d.get("message", {})
                    if m.get("thinking"):
                        self.chunk.emit("think", m["thinking"])
                    if m.get("content"):
                        self.chunk.emit("text", m["content"])
                    if d.get("done"):
                        break
        except Exception as e:
            self.failed.emit(str(e))


class PullThread(QThread):
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool, str)

    def __init__(self, model):
        super().__init__()
        self.model = model

    def run(self):
        body = json.dumps({"name": self.model, "stream": True}).encode()
        req = urllib.request.Request(
            f"{HOST}/api/pull", body, {"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=1800) as r:
                for line in r:
                    if not line.strip():
                        continue
                    d = json.loads(line)
                    status = d.get("status", "")
                    completed = d.get("completed")
                    total = d.get("total")
                    if completed and total:
                        pct = int((completed / total) * 100)
                        self.progress.emit(f"Installing {self.model}: {status} ({pct}%)")
                    else:
                        self.progress.emit(f"Installing {self.model}: {status}")
            self.finished.emit(True, "")
        except Exception as e:
            self.finished.emit(False, str(e))


class InstallOllamaThread(QThread):
    finished = pyqtSignal(bool, str)

    def run(self):
        try:
            res = subprocess.run(
                ["pkexec", "pacman", "-S", "--noconfirm", "ollama"],
                capture_output=True, text=True, timeout=300
            )
            if res.returncode == 0:
                self.finished.emit(True, "")
            else:
                self.finished.emit(False, res.stderr.strip() or "Pacman installation failed.")
        except Exception as e:
            self.finished.emit(False, str(e))


class ServerInitThread(QThread):
    ready = pyqtSignal(str)

    def run(self):
        try:
            with urllib.request.urlopen(f"{HOST}/api/tags", timeout=1) as r:
                self.ready.emit("")
                return
        except Exception:
            pass

        ollama_bin = find_ollama()
        if not ollama_bin:
            self.ready.emit("Ollama binary missing.")
            return

        try:
            global _ollama_proc
            log_path = Path("/tmp/ollama_gui_serve.log")
            with open(log_path, "w") as log_file:
                _ollama_proc = subprocess.Popen(
                    [ollama_bin, "serve"],
                    stdout=log_file,
                    stderr=log_file
                )

            for _ in range(30):
                time.sleep(0.3)
                if _ollama_proc.poll() is not None:
                    error_msg = log_path.read_text().strip() or "Process exited unexpectedly."
                    self.ready.emit(f"Ollama crashed on start: {error_msg}")
                    return
                try:
                    with urllib.request.urlopen(f"{HOST}/api/tags", timeout=1) as r:
                        self.ready.emit("")
                        return
                except Exception:
                    pass

            self.ready.emit("Timed out waiting for ollama serve.")
        except Exception as e:
            self.ready.emit(str(e))


_ollama_proc = None


class Input(QPlainTextEdit):
    submit = pyqtSignal()

    def keyPressEvent(self, e):
        enter = e.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter)
        if enter and not e.modifiers() & Qt.KeyboardModifier.ShiftModifier:
            self.submit.emit()
            return
        super().keyPressEvent(e)


class Win(QWidget):
    def __init__(self):
        super().__init__()
        # Explicit attribute flag required for proper window transparency under Linux WMs (Hyprland, etc.)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)

        self.setWindowTitle("󰣇  ollama chat")
        self.resize(840, 740)

        self.history = []
        self.md = ""
        self.reply = ""
        self.thinking = False
        self.err = ""
        self.worker = None
        self.pull_worker = None
        self.server_worker = None
        self.install_ollama_worker = None

        self.view = QTextBrowser()
        self.view.setOpenExternalLinks(True)

        self.models = QComboBox()
        self.think = QCheckBox("󰚩 think")
        self.install_btn = QPushButton(f"󰚰 install {DEFAULT_MODEL}")
        self.install_btn.setVisible(False)
        self.clear = QPushButton("󰃢 clear")

        top = QHBoxLayout()
        top.addWidget(self.models, 1)
        top.addWidget(self.think)
        top.addWidget(self.install_btn)
        top.addWidget(self.clear)

        self.input = Input()
        self.input.setPlaceholderText("Enter to send, Shift+Enter for newline...")
        self.input.setFixedHeight(84)

        self.send = QPushButton("󰒭 send")
        self.send.setObjectName("send_btn")
        self.send.setFixedHeight(84)

        self.status_lbl = QLabel("󰄬 ready")

        bottom = QHBoxLayout()
        bottom.setSpacing(0)
        bottom.addWidget(self.status_lbl)
        bottom.addSpacing(12)
        bottom.addWidget(self.input, 1)
        bottom.addWidget(self.send)

        lay = QVBoxLayout(self)
        lay.setContentsMargins(16, 16, 16, 16)
        lay.setSpacing(12)
        lay.addLayout(top)
        lay.addWidget(self.view, 1)
        lay.addLayout(bottom)

        self.send.clicked.connect(self.go)
        self.input.submit.connect(self.go)
        self.install_btn.clicked.connect(self.handle_install_click)
        self.clear.clicked.connect(self.reset)

        self.input.setFocus()
        self.init_server()

    def init_server(self):
        if not find_ollama():
            self.md = "> ⚠ **Ollama is not installed.** Click the button below to install it via pacman.\n\n"
            self.install_btn.setText("󰚰 install ollama")
            self.install_btn.setVisible(True)
            self.status_lbl.setText("󰅚 missing")
            self.render()
            return

        self.status_lbl.setText("󰔟 starting...")
        self.md = "> ⏳ Starting Ollama service in the background...\n\n"
        self.render()
        self.server_worker = ServerInitThread()
        self.server_worker.ready.connect(self.on_server_ready)
        self.server_worker.start()

    def on_server_ready(self, err_msg):
        if err_msg:
            self.status_lbl.setText("󰅚 error")
            self.md = f"> ⚠ Background service error: `{err_msg}`\n\n---\n\n"
            self.render()
        self.load_models()

    def load_models(self):
        if not find_ollama():
            return

        names = []
        ollama_online = False
        try:
            with urllib.request.urlopen(f"{HOST}/api/tags", timeout=3) as r:
                names = [m["name"] for m in json.load(r)["models"]]
                ollama_online = True
        except Exception:
            pass

        self.models.clear()
        self.models.addItems(names or [DEFAULT_MODEL])

        if not ollama_online:
            self.status_lbl.setText("󰖪 offline")
            self.install_btn.setText(f"󰚰 install {DEFAULT_MODEL}")
            self.install_btn.setVisible(True)
            self.md = f"> ⚠ Can't reach Ollama at `{HOST}`. Please ensure `ollama serve` is running.\n\n" \
                      f"> 💡 Hardware-detected optimal model: **{DEFAULT_MODEL}**\n\n---\n\n"
            self.render()
            return

        self.status_lbl.setText("󰄬 ready")
        if DEFAULT_MODEL in names:
            self.models.setCurrentText(DEFAULT_MODEL)
            self.install_btn.setVisible(False)
            self.md = ""
        else:
            self.install_btn.setText(f"󰚰 install {DEFAULT_MODEL}")
            self.install_btn.setVisible(True)
            self.md = f"> 💡 **Hardware Check:** Recommended optimal model for your system is **{DEFAULT_MODEL}**, but it is not installed yet. Click above to download it.\n\n---\n\n"
        self.render()

    def handle_install_click(self):
        if not find_ollama():
            self.install_btn.setEnabled(False)
            self.status_lbl.setText("󰚰 installing...")
            self.md += "> ⚙ Prompting for password to install `ollama` via `pacman`...\n\n"
            self.render()
            self.install_ollama_worker = InstallOllamaThread()
            self.install_ollama_worker.finished.connect(self.on_ollama_installed)
            self.install_ollama_worker.start()
        else:
            self.start_model_pull()

    def on_ollama_installed(self, success, err_msg):
        self.install_btn.setEnabled(True)
        if success:
            self.md += "> ✔ Successfully installed `ollama` package!\n\n"
            self.init_server()
        else:
            self.status_lbl.setText("󰅚 failed")
            self.md += f"> ⚠ Failed to install ollama: {err_msg}\n\n---\n\n"
            self.render()

    def start_model_pull(self):
        if self.pull_worker and self.pull_worker.isRunning():
            return
        self.install_btn.setEnabled(False)
        self.status_lbl.setText("󰉁 downloading")
        self.md += f"> ⬇ Starting download for **{DEFAULT_MODEL}**...\n\n"
        self.render()

        self.pull_worker = PullThread(DEFAULT_MODEL)
        self.pull_worker.progress.connect(self.on_install_progress)
        self.pull_worker.finished.connect(self.on_install_finished)
        self.pull_worker.start()

    def on_install_progress(self, msg):
        lines = self.md.strip().split("\n")
        if lines and lines[-1].startswith("> ⬇"):
            lines[-1] = f"> ⬇ {msg}"
            self.md = "\n".join(lines) + "\n\n"
        else:
            self.md += f"> ⬇ {msg}\n\n"
        self.render()

    def on_install_finished(self, success, err_msg):
        self.install_btn.setEnabled(True)
        if success:
            self.status_lbl.setText("󰄬 ready")
            self.md += f"> ✔ Successfully installed **{DEFAULT_MODEL}**!\n\n---\n\n"
            self.load_models()
        else:
            self.status_lbl.setText("󰅚 failed")
            self.md += f"> ⚠ Installation failed: {err_msg}\n\n---\n\n"
        self.render()

    def go(self):
        if self.worker and self.worker.isRunning():
            self.worker.halt()
            return
        text = self.input.toPlainText().strip()
        if not text:
            return
        self.input.clear()

        self.history.append({"role": "user", "content": text})
        shown = text.replace("\n", "  \n")
        self.md += f"**󰊠 You**\n\n{shown}\n\n**󰚩 {self.models.currentText()}**\n\n"
        self.reply, self.thinking, self.err = "", False, ""
        self.render()

        self.send.setText("󰓛 stop")
        self.status_lbl.setText("󰚩 thinking..." if self.think.isChecked() else "󰚩 working...")

        self.worker = Stream(self.models.currentText(), self.history, self.think.isChecked())
        self.worker.chunk.connect(self.on_chunk)
        self.worker.failed.connect(self.on_fail)
        self.worker.finished.connect(self.done)
        self.worker.start()

    def on_chunk(self, kind, text):
        if kind == "think":
            self.thinking = True
            self.status_lbl.setText("󰚩 thinking...")
        else:
            if self.thinking:
                self.thinking = False
            self.status_lbl.setText("󰕑 streaming...")
            self.reply += text
        self.render()

    def on_fail(self, msg):
        self.err = msg

    def done(self):
        if self.reply:
            self.history.append({"role": "assistant", "content": self.reply})
            self.md += self.reply + "\n\n"
        else:
            self.history.pop()
        if self.err:
            self.md += f"> ⚠ {self.err}\n\n"
        self.md += "---\n\n"
        self.reply, self.thinking = "", False
        self.send.setText("󰒭 send")
        self.status_lbl.setText("󰄬 ready")
        self.render()

    def render(self):
        body = self.reply or ("*󰚩 thinking…*" if self.thinking else "")
        self.view.setMarkdown(self.md + body)
        bar = self.view.verticalScrollBar()
        bar.setValue(bar.maximum())

    def reset(self):
        if self.worker and self.worker.isRunning():
            self.worker.halt()
            self.worker.wait()
        self.history, self.md, self.reply = [], "", ""
        self.init_server()
        self.render()

    def closeEvent(self, e):
        if self.worker and self.worker.isRunning():
            self.worker.halt()
            self.worker.wait(2000)
        if self.pull_worker and self.pull_worker.isRunning():
            self.pull_worker.wait(2000)

        global _ollama_proc
        if _ollama_proc and _ollama_proc.poll() is None:
            _ollama_proc.terminate()
            try:
                _ollama_proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                _ollama_proc.kill()

        super().closeEvent(e)


def main():
    app = QApplication(sys.argv)
    app.setFont(QFont(FONT, 11))
    app.setStyleSheet(style(load_colors()))
    w = Win()
    w.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
