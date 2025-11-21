#!/usr/bin/env python3
import sys
import subprocess
import configparser
import json
from pathlib import Path
from PyQt6 import QtWidgets, QtGui, QtCore

# --- Configuration Constants ---
APP_DIRS = [
    Path.home() / ".local/share/applications",
    Path("/usr/share/applications"),
]
OPACITY = 210
ICON_SIZE = QtCore.QSize(32, 32)

EXCLUDE_KEYWORDS = [
    "ssh", "server", "avahi", "browser", "helper",
    "setup", "settings daemon", "gnome-session", "kde-",
    "xfce-", "gimp", "about xfce"
]

FONT_NAME = "Fira Code"
FONT_SIZE = 12
TERMINAL = "kitty"  # <-- change this to foot, alacritty, wezterm, etc.

class AppPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Pick an Application")
        self.setWindowFlag(QtCore.Qt.WindowType.WindowStaysOnTopHint)
        self.setWindowFlag(QtCore.Qt.WindowType.Tool)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        self.applications = self.find_applications()
        if not self.applications:
            QtWidgets.QMessageBox.warning(self, "Error", "No applications found.")
            sys.exit(1)

        self.BG, self.FG, self.ACCENT = self.get_pywal_colors()
        self.ICON_SIZE = ICON_SIZE
        self.SHOW_APP_ICONS = True

        # Calculate translucent background
        LIGHTENING_FACTOR = 2
        base_color = QtGui.QColor(self.BG)
        tint_color = QtGui.QColor("#ffffff")
        mix_factor = LIGHTENING_FACTOR / 100.0
        r = int(base_color.red() * (1 - mix_factor) + tint_color.red() * mix_factor)
        g = int(base_color.green() * (1 - mix_factor) + tint_color.green() * mix_factor)
        b = int(base_color.blue() * (1 - mix_factor) + tint_color.blue() * mix_factor)
        final_color = QtGui.QColor(r, g, b)
        final_color.setAlpha(OPACITY)
        self.rgba_bg = f"rgba({final_color.red()},{final_color.green()},{final_color.blue()},{final_color.alpha()})"

        # --- Widgets ---
        self.search_input = QtWidgets.QLineEdit()
        self.search_input.setPlaceholderText("Search applications...")
        arch_icon_themed = self.get_themed_logo("archlinux-logo", self.FG)
        self.search_input.addAction(
            QtGui.QAction(arch_icon_themed, "", self.search_input),
            QtWidgets.QLineEdit.ActionPosition.LeadingPosition
        )
        self.search_input.textChanged.connect(self.filter_list)
        self.search_input.returnPressed.connect(self.launch_selected)
        self.search_input.keyPressEvent = self.search_key_press_event

        self.list_view = QtWidgets.QListView()
        self.list_view.setEditTriggers(QtWidgets.QAbstractItemView.EditTrigger.NoEditTriggers)
        self.list_view.setFocusPolicy(QtCore.Qt.FocusPolicy.NoFocus)
        self.list_view.setSelectionMode(QtWidgets.QAbstractItemView.SelectionMode.SingleSelection)
        self.list_view.doubleClicked.connect(self.launch_selected)
        self.list_view.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.list_view.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        self.model = QtGui.QStandardItemModel()
        self.list_view.setModel(self.model)
        self.populate_model()

        self.main_frame = QtWidgets.QFrame()
        frame_layout = QtWidgets.QVBoxLayout(self.main_frame)
        frame_layout.addWidget(self.search_input)
        frame_layout.addWidget(self.list_view)
        frame_layout.setContentsMargins(10, 10, 10, 10)
        self.main_frame.setStyleSheet(
            f"QFrame {{ background-color: {self.rgba_bg}; border: 1px solid {self.ACCENT}; border-radius: 8px; }}"
        )

        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(self.main_frame)
        layout.setContentsMargins(0, 0, 0, 0)
        self.setStyleSheet("background-color: #00000000; border: none;")

        self.resize(450, 500)
        self.search_input.setFocus()

        if self.model.rowCount() > 0:
            self.list_view.setCurrentIndex(self.model.index(0, 0))

        # Periodically refresh Pywal colors
        self.timer = QtCore.QTimer()
        self.timer.timeout.connect(self.update_pywal_colors)
        self.timer.start(2000)

        self.apply_styles()
        self.show()

    # --- Styles ---
    def apply_styles(self):
        font = QtGui.QFont(FONT_NAME, FONT_SIZE)
        self.setFont(font)
        self.search_input.setFont(font)
        self.list_view.setFont(font)

        self.search_input.setStyleSheet(f"""
            QLineEdit {{
                border: 2px solid {self.ACCENT};
                border-radius: 4px;
                padding: 5px;
                padding-left: 10px;
                color: {self.FG};
                background-color: {self.BG};
            }}
        """)

        self.list_view.setStyleSheet(f"""
            QListView {{
                background-color: #00000000;
                border: none;
                color: {self.FG};
            }}
            QListView::item {{
                padding: 5px;
                border-radius: 4px;
            }}
            QListView::item:selected {{
                background-color: {self.ACCENT};
                border: none;
            }}
        """)

        self.main_frame.setStyleSheet(
            f"QFrame {{ background-color: {self.rgba_bg}; border: 1px solid {self.ACCENT}; border-radius: 8px; }}"
        )

        for row in range(self.model.rowCount()):
            item = self.model.item(row)
            item.setFont(QtGui.QFont(FONT_NAME, FONT_SIZE))

    def update_pywal_colors(self):
        self.BG, self.FG, self.ACCENT = self.get_pywal_colors()
        self.apply_styles()

    # --- Icons ---
    def recolor_icon(self, icon, color_hex):
        pixmap = icon.pixmap(QtCore.QSize(18, 18))
        painter = QtGui.QPainter(pixmap)
        painter.setCompositionMode(QtGui.QPainter.CompositionMode.CompositionMode_SourceIn)
        painter.fillRect(pixmap.rect(), QtGui.QColor(color_hex))
        painter.end()
        return QtGui.QIcon(pixmap)

    def get_themed_logo(self, icon_name, color_hex):
        icon = QtGui.QIcon.fromTheme(icon_name)
        if icon.isNull():
            icon = QtGui.QIcon.fromTheme("system-search")
        return self.recolor_icon(icon, color_hex)

    def get_app_icon(self, icon_name):
        symbolic_icon_name = icon_name + "-symbolic"
        icon = QtGui.QIcon.fromTheme(symbolic_icon_name)
        if icon.isNull():
            icon = QtGui.QIcon.fromTheme(icon_name)
        if icon.isNull() and Path(icon_name).exists():
            icon = QtGui.QIcon(icon_name)
        if not icon.isNull():
            return icon
        return QtGui.QIcon.fromTheme('application-default')

    # --- Keyboard ---
    def search_key_press_event(self, event):
        key = event.key()
        if key in (QtCore.Qt.Key.Key_Up, QtCore.Qt.Key.Key_Down):
            current_index = self.list_view.currentIndex()
            if not current_index.isValid() and self.list_view.model().rowCount() > 0:
                new_row = self.list_view.model().rowCount() - 1 if key == QtCore.Qt.Key.Key_Up else 0
            else:
                row = current_index.row()
                new_row = max(0, row - 1) if key == QtCore.Qt.Key.Key_Up else min(self.list_view.model().rowCount() - 1, row + 1)
            new_index = self.list_view.model().index(new_row, 0)
            self.list_view.setCurrentIndex(new_index)
            self.list_view.scrollTo(new_index)
        elif key == QtCore.Qt.Key.Key_Escape:
            QtWidgets.QApplication.quit()
        else:
            QtWidgets.QLineEdit.keyPressEvent(self.search_input, event)

    # --- Model ---
    def populate_model(self):
        self.model.clear()
        for app in sorted(self.applications, key=lambda a: a['Name']):
            item = QtGui.QStandardItem(app['Name'])
            if self.SHOW_APP_ICONS:
                item.setIcon(self.get_app_icon(app.get('Icon', 'application-default')))
            item.setFont(QtGui.QFont(FONT_NAME, FONT_SIZE))
            item.setData(app['Exec'], QtCore.Qt.ItemDataRole.UserRole)
            item.setData(app['Terminal'], QtCore.Qt.ItemDataRole.UserRole + 1)
            self.model.appendRow(item)

    def filter_list(self, text):
        proxy = QtCore.QSortFilterProxyModel()
        proxy.setSourceModel(self.model)
        proxy.setFilterCaseSensitivity(QtCore.Qt.CaseSensitivity.CaseInsensitive)
        if text:
            escaped = QtCore.QRegularExpression.escape(text)
            proxy.setFilterRegularExpression(f".*{escaped}.*")
        self.list_view.setModel(proxy)
        if proxy.rowCount() > 0:
            self.list_view.setCurrentIndex(proxy.index(0, 0))

    # --- Launch ---
    def launch_selected(self):
        index = self.list_view.currentIndex()
        if not index.isValid():
            return

        model = self.list_view.model()
        cmd = model.data(index, QtCore.Qt.ItemDataRole.UserRole)
        needs_terminal = model.data(index, QtCore.Qt.ItemDataRole.UserRole + 1)

        if needs_terminal:
            # Launch in a login shell so Pywal colors are applied
            subprocess.Popen([TERMINAL, "--hold", "-e", "bash", "-l", "-c", cmd], close_fds=True)
        else:
            subprocess.Popen(cmd, shell=True, close_fds=True)

        QtWidgets.QApplication.quit()

    # --- Desktop parsing ---
    def parse_desktop_file(self, path):
        parser = configparser.ConfigParser(interpolation=None)
        try:
            with path.open("r", encoding="utf-8") as f:
                parser.read_string(f.read())
        except Exception:
            return None

        if 'Desktop Entry' not in parser:
            return None

        entry = parser['Desktop Entry']
        if entry.getboolean('NoDisplay', fallback=False) or entry.get('Type') != 'Application':
            return None

        name = entry.get('Name')
        exec_cmd = entry.get('Exec', '').split('%', 1)[0].strip()
        icon = entry.get('Icon')
        terminal = entry.getboolean('Terminal', fallback=False)

        if not name or not exec_cmd:
            return None

        return {'Name': name, 'Exec': exec_cmd, 'Icon': icon, 'Terminal': terminal}

    def find_applications(self):
        apps, names = [], set()
        for app_dir in APP_DIRS:
            if app_dir.exists():
                for file in app_dir.glob("*.desktop"):
                    info = self.parse_desktop_file(file)
                    if not info:
                        continue
                    lower = info['Name'].lower()
                    if any(k in lower for k in EXCLUDE_KEYWORDS):
                        continue
                    if info['Name'] not in names:
                        apps.append(info)
                        names.add(info['Name'])
        return apps

    def get_pywal_colors(self):
        wal_json = Path.home() / ".cache/wal/colors.json"
        BG = "#1d1f21"
        FG = "#c5c8c6"
        ACCENT = "#5e81ac"
        if not wal_json.exists():
            return BG, FG, ACCENT
        try:
            data = json.loads(wal_json.read_text())
            BG = data["special"]["background"]
            FG = data["special"]["foreground"]
            ACCENT = data["colors"].get("color12") or data["colors"].get("color4") or ACCENT
            return BG, FG, ACCENT
        except Exception:
            return BG, FG, ACCENT


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    picker = AppPicker()
    sys.exit(app.exec())
