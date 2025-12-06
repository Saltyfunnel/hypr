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
OPACITY = 255 # Solid opacity for a crisp, non-transparent look
ICON_SIZE = QtCore.QSize(30, 30)

EXCLUDE_KEYWORDS = [
    "ssh", "server", "avahi", "browser", "helper",
    "setup", "settings daemon", "gnome-session", "kde-",
    "xfce-", "gimp", "about xfce"
]

FONT_NAME = "Fira Code"
FONT_SIZE = 10
TERMINAL = "kitty"  # Customize your preferred terminal

# --- Custom Delegate (Crucial for alignment fix) ---
class NoMarginItemDelegate(QtWidgets.QStyledItemDelegate):
    def sizeHint(self, option, index):
        size = super().sizeHint(option, index)
        # Force width to fill the view's available space
        if option.widget:
            size.setWidth(option.rect.width())
        return size

# --- Main App Picker Class ---
class AppPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("Pick an Application")
        self.setWindowFlag(QtCore.Qt.WindowType.WindowStaysOnTopHint)
        self.setWindowFlag(QtCore.Qt.WindowType.Tool)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        # --- Blur background (KDE/GNOME/wlroots-supporting) ---
        try:
            self.setWindowFlag(QtCore.Qt.WindowType.FramelessWindowHint)
            self.setProperty("KDEBlurBehindEnabled", True)
            self.setProperty("blur", True)
        except Exception:
            pass

        # Load applications
        self.applications = self.find_applications()
        if not self.applications:
            QtWidgets.QMessageBox.warning(self, "Error", "No applications found.")
            sys.exit(1)

        # Load theme colors
        self.BG, self.FG, self.ACCENT = self.get_pywal_colors()
        self.SHOW_APP_ICONS = True

        # --- Solid Background Color ---
        base = QtGui.QColor(self.BG)
        final = base
        final.setAlpha(OPACITY)
        self.rgba_bg = f"rgba({final.red()},{final.green()},{final.blue()},{final.alpha()})"
        
        # Determine colors for the search bar background (a lighter version of BG)
        search_bg_color = QtGui.QColor(self.BG).lighter(120).name()

        # --- Search bar ---
        self.search_input = QtWidgets.QLineEdit()
        self.search_input.setPlaceholderText("Search applications…")
        self.search_input.textChanged.connect(self.filter_list)
        self.search_input.returnPressed.connect(self.launch_selected)
        self.search_input.keyPressEvent = self.search_key_press_event

        arch_icon = self.get_themed_logo("system-search", self.ACCENT) # Using system-search
        self.search_input.addAction(
            QtGui.QAction(arch_icon, "", self.search_input),
            QtWidgets.QLineEdit.ActionPosition.LeadingPosition
        )

       # --- List view ---
        self.list_view = QtWidgets.QListView()
        self.list_view.setEditTriggers(QtWidgets.QAbstractItemView.EditTrigger.NoEditTriggers)
        self.list_view.setSelectionMode(QtWidgets.QAbstractItemView.SelectionMode.SingleSelection)
        self.list_view.setResizeMode(QtWidgets.QListView.ResizeMode.Adjust) 
        
        # Set the custom delegate for guaranteed full-width drawing
        self.delegate = NoMarginItemDelegate(self.list_view)
        self.list_view.setItemDelegate(self.delegate) 

        # Disable scrollbars fully
        self.list_view.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.list_view.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        self.list_view.doubleClicked.connect(self.launch_selected)

        # Model of all apps
        self.model = QtGui.QStandardItemModel()
        self.populate_model()

        # Initially show main model
        self.list_view.setModel(self.model)

        # --- Outer container (main layout) ---
        outer = QtWidgets.QVBoxLayout(self)
        outer.addWidget(self.search_input)
        outer.addWidget(self.list_view)
        # Reduce main window padding slightly for a tighter fit
        outer.setContentsMargins(10, 10, 10, 10) 
        outer.setSpacing(0) 

        self.resize(450, 500)
        self.search_input.setFocus()

        if self.model.rowCount() > 0:
            self.list_view.setCurrentIndex(self.model.index(0, 0))

        # Periodically re-read pywal colors
        self.timer = QtCore.QTimer()
        self.timer.timeout.connect(self.update_pywal_colors)
        self.timer.start(2000)
        
        # Store search bar color for dynamic use in apply_styles
        self.search_bg_color = search_bg_color

        self.apply_styles()
        self.animate_open()
        self.show()

    # --- Animations ---
    def animate_open(self):
        self.setWindowOpacity(0.0)

        fade = QtCore.QPropertyAnimation(self, b"windowOpacity")
        fade.setDuration(120)
        fade.setStartValue(0.0)
        fade.setEndValue(1.0)
        fade.start()
        self.fade_anim = fade

        geo = self.geometry()
        scale = QtCore.QPropertyAnimation(self, b"geometry")
        scale.setDuration(120)
        scale.setStartValue(QtCore.QRect(
            geo.x()+20, geo.y()+20,
            geo.width()-40, geo.height()-40
        ))
        scale.setEndValue(geo)
        scale.start()
        self.scale_anim = scale

    # --- Styles: Modern Flat & Crisp ---
    def apply_styles(self):
        font = QtGui.QFont(FONT_NAME, FONT_SIZE)
        self.setFont(font)
        self.search_input.setFont(font)
        self.list_view.setFont(font)

        # Style for the main window (self) - Sharp corners
        self.setStyleSheet(f"""
            QWidget {{
                background-color: {self.rgba_bg};
                border-radius: 4px; 
                border: 1px solid {self.ACCENT}; /* Thin border for definition */
            }}
        """)

        # Style for search bar - Uses a distinct color for separation
        self.search_input.setStyleSheet(f"""
            QLineEdit {{
                border: none;
                border-bottom: 2px solid {self.ACCENT}; /* Accent line under search */
                border-radius: 0px; 
                padding: 6px 10px;
                color: {self.FG};
                background-color: {self.search_bg_color};
            }}
        """)

        # Style for list view - Flat, full-width selection
        self.list_view.setStyleSheet(f"""
            QListView {{
                background: transparent;
                border: none;
                color: {self.FG};
                margin-top: 5px; 
                padding-right: 0px; 
            }}
            QListView::item {{
                padding: 8px 0px 8px 10px; /* Slightly more vertical padding */
                margin: 0px; /* Zero margin for full stretch */
            }}
            /* Full-width, accent-colored selection */
            QListView::item:selected {{
                background: {self.ACCENT};
                color: {self.BG}; /* Invert text color for selection */
                border: none;
                border-radius: 0px; /* Flat selection */
            }}
            QListView::item:hover {{
                background: rgba(255,255,255,0.08); /* Subtle hover */
                border-radius: 0px;
            }}
        """)

    def update_pywal_colors(self):
        self.BG, self.FG, self.ACCENT = self.get_pywal_colors()
        # Recalculate search bar color based on new BG
        base = QtGui.QColor(self.BG)
        self.search_bg_color = base.lighter(120).name()
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

    def round_icon(self, icon):
        size = 30
        pix = icon.pixmap(size, size)
        rounded = QtGui.QPixmap(size, size)
        rounded.fill(QtCore.Qt.GlobalColor.transparent)

        painter = QtGui.QPainter(rounded)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        path = QtGui.QPainterPath()
        path.addEllipse(0, 0, size, size)
        painter.setClipPath(path)
        painter.drawPixmap(0, 0, pix)
        painter.end()
        return QtGui.QIcon(rounded)

    def get_app_icon(self, icon_name):
        symbolic = QtGui.QIcon.fromTheme(icon_name + "-symbolic")
        if not symbolic.isNull():
            return self.round_icon(symbolic)

        normal = QtGui.QIcon.fromTheme(icon_name)
        if not normal.isNull():
            return self.round_icon(normal)

        if Path(icon_name).exists():
            return self.round_icon(QtGui.QIcon(icon_name))

        return self.round_icon(QtGui.QIcon.fromTheme("application-default"))

    # --- Keyboard navigation ---
    def search_key_press_event(self, event):
        key = event.key()
        if key in (QtCore.Qt.Key.Key_Up, QtCore.Qt.Key.Key_Down):
            model = self.list_view.model()
            current = self.list_view.currentIndex()
            count = model.rowCount()
            if count == 0:
                return

            if not current.isValid():
                row = 0
            else:
                row = current.row() + (1 if key == QtCore.Qt.Key.Key_Down else -1)
                row = max(0, min(row, count - 1))

            idx = model.index(row, 0)
            self.list_view.setCurrentIndex(idx)
            self.list_view.scrollTo(idx)

        elif key == QtCore.Qt.Key.Key_Escape:
            QtWidgets.QApplication.quit()
        else:
            QtWidgets.QLineEdit.keyPressEvent(self.search_input, event)

    # --- Model population ---
    def populate_model(self):
        self.model.clear()
        for app in sorted(self.applications, key=lambda a: a["Name"]):
            item = QtGui.QStandardItem(app["Name"])
            if self.SHOW_APP_ICONS:
                item.setIcon(self.get_app_icon(app.get("Icon", "")))
            item.setData(app["Exec"], QtCore.Qt.ItemDataRole.UserRole)
            item.setData(app["Terminal"], QtCore.Qt.ItemDataRole.UserRole + 1)
            self.model.appendRow(item)

    # --- **Substring Search** (no fuzzy) ---
    def filter_list(self, text):
        proxy = QtCore.QSortFilterProxyModel(self)
        proxy.setSourceModel(self.model)
        proxy.setFilterCaseSensitivity(QtCore.Qt.CaseSensitivity.CaseInsensitive)

        if text.strip():
            escaped = QtCore.QRegularExpression.escape(text)
            proxy.setFilterRegularExpression(f".*{escaped}.*")

        self.list_view.setModel(proxy)

        if proxy.rowCount() > 0:
            self.list_view.setCurrentIndex(proxy.index(0, 0))

    # --- Launch selected app ---
    def launch_selected(self):
        index = self.list_view.currentIndex()
        if not index.isValid():
            return

        model = self.list_view.model()
        cmd = model.data(index, QtCore.Qt.ItemDataRole.UserRole)
        needs_terminal = bool(model.data(index, QtCore.Qt.ItemDataRole.UserRole + 1))

        if needs_terminal:
            subprocess.Popen([TERMINAL, "--hold", "-e", "bash", "-l", "-c", cmd])
        else:
            subprocess.Popen(cmd, shell=True)

        QtWidgets.QApplication.quit()

    # --- Desktop file parser ---
    def parse_desktop_file(self, path):
        parser = configparser.ConfigParser(interpolation=None)
        try:
            parser.read(path, encoding="utf-8")
        except Exception:
            return None

        if "Desktop Entry" not in parser:
            return None

        entry = parser["Desktop Entry"]

        if entry.get("Type") != "Application":
            return None
        if entry.getboolean("NoDisplay", fallback=False):
            return None

        name = entry.get("Name")
        exec_cmd = entry.get("Exec", "").split("%", 1)[0].strip()
        icon = entry.get("Icon")
        terminal = entry.getboolean("Terminal", fallback=False)

        if not name or not exec_cmd:
            return None

        return {"Name": name, "Exec": exec_cmd, "Icon": icon, "Terminal": terminal}

    # --- Collect applications ---
    def find_applications(self):
        apps, names = [], set()

        for app_dir in APP_DIRS:
            if not app_dir.exists():
                continue

            for file in app_dir.glob("*.desktop"):
                info = self.parse_desktop_file(file)
                if not info:
                    continue

                lower_name = info["Name"].lower()
                if any(k in lower_name for k in EXCLUDE_KEYWORDS):
                    continue

                if info["Name"] not in names:
                    apps.append(info)
                    names.add(info["Name"])

        return apps

    def get_pywal_colors(self):
        wal = Path.home() / ".cache/wal/colors.json"
        BG = "#1d1f21"
        FG = "#c5c8c6"
        ACCENT = "#5e81ac"

        if not wal.exists():
            return BG, FG, ACCENT

        try:
            data = json.loads(wal.read_text())
            BG = data["special"]["background"]
            FG = data["special"]["foreground"]
            ACCENT = (
                data["colors"].get("color12")
                or data["colors"].get("color4")
                or ACCENT
            )
            return BG, FG, ACCENT
        except Exception:
            return BG, FG, ACCENT


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    picker = AppPicker()
    sys.exit(app.exec())
