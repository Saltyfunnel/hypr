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
ICON_SIZE = 30 
TERMINAL = "kitty"
FONT_NAME = "Fira Code"
FONT_SIZE = 10
# --- RESET TO STANDARD SIZE ---
WINDOW_WIDTH = 420 
WINDOW_HEIGHT = 400
# ----------------------

# Keywords to exclude applications (case-insensitive)
EXCLUDE_KEYWORDS = [
    "ssh", "server", "avahi", "helper", "setup", 
    "settings daemon", "gnome-session", "kde-", "xfce-"
]

class AppPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        
        # 1. Basic Window Setup
        self.setWindowTitle("App Launcher")
        
        # --- ESSENTIAL FIX: Set fixed size to prevent stretching ---
        self.setFixedSize(WINDOW_WIDTH, WINDOW_HEIGHT)
        
        # Use simple floating flags that worked before (Frameless + Tool)
        self.setWindowFlags(
            QtCore.Qt.WindowType.FramelessWindowHint | 
            QtCore.Qt.WindowType.Tool
        )
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)
        
        # 2. Data Loading and UI Setup
        self.BG, self.FG, self.ACCENT = self._get_pywal_colors()
        self.applications = self._find_applications()
        
        # 3. Create Widgets
        self.search_input = self._create_search_input()
        self.list_view = self._create_list_view()
        self.model = QtGui.QStandardItemModel()
        self.populate_model()
        self.list_view.setModel(self.model)

        # 4. Layout
        self._setup_layout()

        # 5. Styling and Focus
        self._calculate_translucent_bg()
        self._apply_styles()
        self.search_input.setFocus()
        self.list_view.setCurrentIndex(self.model.index(0, 0))
        
        # 6. Center and Show
        self._center_window()
        self.show()

    # --- UI Component Creation ---

    def _create_search_input(self):
        search_input = QtWidgets.QLineEdit()
        # --- NEW SHORTER PLACEHOLDER ---
        search_input.setPlaceholderText("Search apps...") 
        # -------------------------------
        search_input.textChanged.connect(self.filter_list)
        search_input.returnPressed.connect(self.launch_selected)
        search_input.keyPressEvent = self._search_key_press_event
        
        # Set max width to prevent stretching (420 - 40 = 380px)
        search_input.setMaximumWidth(WINDOW_WIDTH - 40)
        
        # Re-adding the Arch logo
        arch_icon = self._get_themed_logo("archlinux-logo", self.FG)
        search_input.addAction(
            QtGui.QAction(arch_icon, "", search_input),
            QtWidgets.QLineEdit.ActionPosition.LeadingPosition
        )
        
        return search_input

    def _create_list_view(self):
        list_view = QtWidgets.QListView()
        list_view.setEditTriggers(QtWidgets.QAbstractItemView.EditTrigger.NoEditTriggers)
        list_view.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        list_view.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        list_view.doubleClicked.connect(self.launch_selected)
        return list_view
    
    def _setup_layout(self):
        # Use a simple QFrame for the main window content
        main_frame = QtWidgets.QFrame()
        layout = QtWidgets.QVBoxLayout(main_frame)
        
        # Center the search input using alignment
        layout.addWidget(self.search_input, alignment=QtCore.Qt.AlignmentFlag.AlignHCenter) 
        layout.addWidget(self.list_view)
        
        # Standard margins 
        layout.setContentsMargins(10, 10, 10, 10) 
        
        # Set the main layout of the QWidget
        outer_layout = QtWidgets.QVBoxLayout(self)
        outer_layout.addWidget(main_frame)
        outer_layout.setContentsMargins(0, 0, 0, 0)

    # --- Layout and Position ---

    def _center_window(self):
        screen_geometry = QtWidgets.QApplication.primaryScreen().geometry()
        x = (screen_geometry.width() - self.width()) // 2
        y = (screen_geometry.height() - self.height()) // 2
        self.move(x, y)

    # --- Data and App Logic (Unchanged) ---

    def _parse_desktop_file(self, path):
        parser = configparser.ConfigParser(interpolation=None)
        try:
            parser.read(path, encoding="utf-8")
        except Exception:
            return None

        if "Desktop Entry" not in parser: return None
        entry = parser["Desktop Entry"]

        if entry.get("Type") != "Application": return None
        if entry.getboolean("NoDisplay", fallback=False): return None

        name = entry.get("Name")
        exec_cmd = entry.get("Exec", "").split("%", 1)[0].strip()
        icon = entry.get("Icon")
        terminal = entry.getboolean("Terminal", fallback=False)

        if not name or not exec_cmd: return None
        return {"Name": name, "Exec": exec_cmd, "Icon": icon, "Terminal": terminal}

    def _find_applications(self):
        apps, names = [], set()
        for app_dir in APP_DIRS:
            if not app_dir.exists(): continue
            for file in app_dir.glob("*.desktop"):
                info = self._parse_desktop_file(file)
                if not info: continue
                lower_name = info["Name"].lower()
                if any(k in lower_name for k in EXCLUDE_KEYWORDS): continue
                if info["Name"] not in names:
                    apps.append(info)
                    names.add(info["Name"])
        return apps
        
    def _recolor_icon(self, icon, color_hex):
        pixmap = icon.pixmap(QtCore.QSize(18, 18))
        painter = QtGui.QPainter(pixmap)
        painter.setCompositionMode(QtGui.QPainter.CompositionMode.CompositionMode_SourceIn)
        painter.fillRect(pixmap.rect(), QtGui.QColor(color_hex))
        painter.end()
        return QtGui.QIcon(pixmap)
        
    def _get_themed_logo(self, icon_name, color_hex):
        icon = QtGui.QIcon.fromTheme(icon_name)
        if icon.isNull():
            icon = QtGui.QIcon.fromTheme("system-search")
        return self._recolor_icon(icon, color_hex)

    def _get_app_icon(self, icon_name):
        icon = QtGui.QIcon.fromTheme(icon_name)
        if icon.isNull():
            return QtGui.QIcon.fromTheme("application-default")
        return icon

    def populate_model(self):
        self.model.clear()
        for app in sorted(self.applications, key=lambda a: a["Name"]):
            item = QtGui.QStandardItem(app["Name"])
            item.setIcon(self._get_app_icon(app.get("Icon", "")))
            item.setData(app["Exec"], QtCore.Qt.ItemDataRole.UserRole)
            item.setData(app["Terminal"], QtCore.Qt.ItemDataRole.UserRole + 1)
            self.model.appendRow(item)

    def filter_list(self, text):
        proxy = QtCore.QSortFilterProxyModel(self)
        proxy.setSourceModel(self.model)
        proxy.setFilterCaseSensitivity(QtCore.Qt.CaseSensitivity.CaseInsensitive)
        proxy.setFilterRegularExpression(f".*{QtCore.QRegularExpression.escape(text.strip())}.*")
        self.list_view.setModel(proxy)
        if proxy.rowCount() > 0:
            self.list_view.setCurrentIndex(proxy.index(0, 0))

    def launch_selected(self):
        index = self.list_view.currentIndex()
        if not index.isValid(): return

        model = self.list_view.model()
        cmd = model.data(index, QtCore.Qt.ItemDataRole.UserRole)
        needs_terminal = bool(model.data(index, QtCore.Qt.ItemDataRole.UserRole + 1))

        if needs_terminal:
            subprocess.Popen([TERMINAL, "-e", "bash", "-l", "-c", cmd])
        else:
            subprocess.Popen(cmd, shell=True)

        QtWidgets.QApplication.quit()

    def _search_key_press_event(self, event):
        key = event.key()
        if key in (QtCore.Qt.Key.Key_Up, QtCore.Qt.Key.Key_Down):
            model = self.list_view.model()
            current = self.list_view.currentIndex()
            count = model.rowCount()
            if count == 0: return

            row = current.row() + (1 if key == QtCore.Qt.Key.Key_Down else -1)
            row = max(0, min(row, count - 1))

            idx = model.index(row, 0)
            self.list_view.setCurrentIndex(idx)
            self.list_view.scrollTo(idx)

        elif key == QtCore.Qt.Key.Key_Escape:
            QtWidgets.QApplication.quit()
        else:
            QtWidgets.QLineEdit.keyPressEvent(self.search_input, event)

    # --- Styling and Pywal (Simplified) ---

    def _get_pywal_colors(self):
        wal = Path.home() / ".cache/wal/colors.json"
        BG, FG, ACCENT = "#1d1f21", "#c5c8c6", "#5e81ac"
        if not wal.exists(): return BG, FG, ACCENT
        try:
            data = json.loads(wal.read_text())
            BG = data["special"]["background"]
            FG = data["special"]["foreground"]
            ACCENT = data["colors"].get("color4") or ACCENT
            return BG, FG, ACCENT
        except Exception:
            return BG, FG, ACCENT
    
    def _calculate_translucent_bg(self):
        base = QtGui.QColor(self.BG)
        base.setAlpha(220)
        self.rgba_bg = base.name(QtGui.QColor.NameFormat.HexArgb)

    def _apply_styles(self):
        font = QtGui.QFont(FONT_NAME, FONT_SIZE)
        self.setFont(font)
        
        # Apply styles directly to the widgets
        self.search_input.setStyleSheet(f"""
            QLineEdit {{
                border: 2px solid {self.ACCENT};
                border-radius: 6px;
                /* Reset padding to standard for QAction/Logo positioning */
                padding: 5px 10px; 
                color: {self.FG};
                background-color: {self.BG};
            }}
        """)

        self.list_view.setStyleSheet(f"""
            QListView {{
                background: transparent;
                border: none;
                color: {self.FG};
            }}
            QListView::item {{
                padding: 6px 10px;
                border-radius: 6px;
                margin: 2px 4px;
            }}
            QListView::item:selected {{
                background: {self.ACCENT}60;
            }}
        """)
        
        # Style for the main window frame (important for border/blur)
        self.setStyleSheet(f"""
            QWidget {{
                background-color: {self.rgba_bg};
                border: 1px solid {self.ACCENT};
                border-radius: 12px;
            }}
        """)

# --- Main Execution ---

if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    picker = AppPicker()
    sys.exit(app.exec())
