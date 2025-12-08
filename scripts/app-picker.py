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
ICON_SIZE = QtCore.QSize(30, 30)

EXCLUDE_KEYWORDS = [
    "ssh", "server", "avahi", "browser", "helper",
    "setup", "settings daemon", "gnome-session", "kde-",
    "xfce-", "gimp", "about xfce"
]

FONT_NAME = "Fira Code"
FONT_SIZE = 10
TERMINAL = "kitty"  # Customize your preferred terminal


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

        # --- Translucent background mixing (Using your original logic) ---
        LIGHTEN = 2
        base = QtGui.QColor(self.BG)
        white = QtGui.QColor("#ffffff")
        mix = LIGHTEN / 100
        r = int(base.red() * (1 - mix) + white.red() * mix)
        g = int(base.green() * (1 - mix) + white.green() * mix)
        b = int(base.blue() * (1 - mix) + white.blue() * mix)
        final = QtGui.QColor(r, g, b)
        final.setAlpha(OPACITY)
        self.rgba_bg = f"rgba({r},{g},{b},{final.alpha()})"

        # --- Search bar ---
        self.search_input = QtWidgets.QLineEdit()
        self.search_input.setPlaceholderText("Search applications…")
        self.search_input.textChanged.connect(self.filter_list)
        self.search_input.returnPressed.connect(self.launch_selected)
        self.search_input.keyPressEvent = self.search_key_press_event

        arch_icon = self.get_themed_logo("archlinux-logo", self.FG)
        self.search_input.addAction(
            QtGui.QAction(arch_icon, "", self.search_input),
            QtWidgets.QLineEdit.ActionPosition.LeadingPosition
        )

       # --- List view ---
        self.list_view = QtWidgets.QListView()
        self.list_view.setEditTriggers(QtWidgets.QAbstractItemView.EditTrigger.NoEditTriggers)
        self.list_view.setSelectionMode(QtWidgets.QAbstractItemView.SelectionMode.SingleSelection)
        self.list_view.setUniformItemSizes(True)

        # Disable scrollbars fully
        self.list_view.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.list_view.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        self.list_view.doubleClicked.connect(self.launch_selected)
        
        # Proxy model for filtering
        self.proxy_model = QtCore.QSortFilterProxyModel()
        self.proxy_model.setFilterCaseSensitivity(QtCore.Qt.CaseSensitivity.CaseInsensitive)
        self.proxy_model.setFilterRole(QtCore.Qt.ItemDataRole.DisplayRole)

        # Model of all apps
        self.model = QtGui.QStandardItemModel()
        self.populate_model()
        
        self.proxy_model.setSourceModel(self.model)

        # Initially show main model
        self.list_view.setModel(self.proxy_model)

        # --- Frame ---
        self.main_frame = QtWidgets.QFrame()
        inner = QtWidgets.QVBoxLayout(self.main_frame)
        inner.addWidget(self.search_input)
        inner.addWidget(self.list_view)
        
        # Give the list view a high stretch factor to fill space
        inner.setStretchFactor(self.list_view, 1) 
        
        inner.setContentsMargins(12, 12, 12, 12)

        # Drop shadow
        shadow = QtWidgets.QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(40)
        shadow.setOffset(0, 4)
        shadow.setColor(QtGui.QColor(0, 0, 0, 160))
        self.main_frame.setGraphicsEffect(shadow)

        # Outer container
        outer = QtWidgets.QVBoxLayout(self)
        outer.addWidget(self.main_frame)
        outer.setContentsMargins(0, 0, 0, 0)

        self.resize(450, 500)
        self.search_input.setFocus()

        if self.model.rowCount() > 0:
            initial_index = self.proxy_model.index(0, 0)
            self.list_view.setCurrentIndex(initial_index)
            
            # Ensure the selected item is centered vertically
            self.list_view.scrollTo(
                initial_index,
                QtWidgets.QAbstractItemView.ScrollHint.PositionAtCenter
            )
            
            # Force repaint and layout recalculation on initial open
            self.list_view.updateGeometries() 
            self.list_view.viewport().update()

        # Periodically re-read pywal colors
        self.timer = QtCore.QTimer()
        self.timer.timeout.connect(self.update_pywal_colors)
        self.timer.start(2000)

        self.apply_styles()
        self.animate_open()
        self.show()

    # --- Animations (Same) ---
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

    # --- Styles (Adjusted Padding) ---
    def apply_styles(self):
        font = QtGui.QFont(FONT_NAME, FONT_SIZE)
        self.setFont(font)
        self.search_input.setFont(font)
        self.list_view.setFont(font)

        self.search_input.setStyleSheet(f"""
            QLineEdit {{
                border: 2px solid {self.ACCENT};
                border-radius: 6px;
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
                outline: 0; /* Remove focus rectangle */
            }}
            QListView::item {{
                padding: 6px 12px; /* Adjusted padding */
                border-radius: 6px;
                margin: 2px 4px;
            }}
            QListView::item:selected {{
                /* Use accent color for selected item background */
                background: {self.ACCENT}; 
                color: {self.BG}; /* Invert text color for contrast */
                border: 1px solid {self.ACCENT};
            }}
            QListView::item:hover:!selected {{
                /* Lighter hover effect for unselected items */
                background: rgba(255,255,255,0.08); 
            }}
        """)

        self.main_frame.setStyleSheet(f"""
            QFrame {{
                background-color: {self.rgba_bg};
                border: 1px solid {self.ACCENT};
                border-radius: 12px;
                backdrop-filter: blur(20px);
            }}
        """)

    def update_pywal_colors(self):
        # Your Pywal colors refresh logic
        old_bg, old_fg, old_accent = self.BG, self.FG, self.ACCENT
        self.BG, self.FG, self.ACCENT = self.get_pywal_colors()
        
        if old_bg != self.BG or old_accent != self.ACCENT:
            # Recompute rgba_bg if BG color changes
            LIGHTEN = 2
            base = QtGui.QColor(self.BG)
            white = QtGui.QColor("#ffffff")
            mix = LIGHTEN / 100
            r = int(base.red() * (1 - mix) + white.red() * mix)
            g = int(base.green() * (1 - mix) + white.green() * mix)
            b = int(base.blue() * (1 - mix) + white.blue() * mix)
            final = QtGui.QColor(r, g, b)
            final.setAlpha(OPACITY)
            self.rgba_bg = f"rgba({r},{g},{b},{final.alpha()})"
            
            self.apply_styles()

    # --- Icons (Same) ---
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

    # --- Keyboard navigation (Same) ---
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

    # --- Model population (Reverted to working state) ---
    def populate_model(self):
        self.model.clear()
        for app in sorted(self.applications, key=lambda a: a["Name"]):
            item = QtGui.QStandardItem(app["Name"])
            if self.SHOW_APP_ICONS:
                item.setIcon(self.get_app_icon(app.get("Icon", "")))
                
            item.setData(app["Exec"], QtCore.Qt.ItemDataRole.UserRole)
            item.setData(app["Terminal"], QtCore.Qt.ItemDataRole.UserRole + 1)
            self.model.appendRow(item)

    # --- Substring Search Reverted (With Repaint) ---
    def filter_list(self, text):
        # Set the filter using a regex pattern that matches the text anywhere
        regex = QtCore.QRegularExpression(text, 
            QtCore.QRegularExpression.PatternOption.CaseInsensitiveOption)
        self.proxy_model.setFilterRegularExpression(regex)

        # Select the first item if the list isn't empty
        if self.proxy_model.rowCount() > 0:
            index = self.proxy_model.index(0, 0)
            self.list_view.setCurrentIndex(index)
            
            # SCROLL ADJUSTMENT on FILTERING
            self.list_view.scrollTo(
                index,
                QtWidgets.QAbstractItemView.ScrollHint.PositionAtCenter
            )
            
            # Force repaint and layout recalculation on filter change
            self.list_view.updateGeometries()
            self.list_view.viewport().update()

    # --- Launch selected app (Same) ---
    def launch_selected(self):
        index = self.list_view.currentIndex()
        if not index.isValid():
            return

        # Get the index from the proxy model, then map it back to the source model to read data
        source_index = self.proxy_model.mapToSource(index)
        
        # We need the source model to read the UserRole data correctly
        model = self.model
        cmd = model.data(source_index, QtCore.Qt.ItemDataRole.UserRole)
        needs_terminal = bool(model.data(source_index, QtCore.Qt.ItemDataRole.UserRole + 1))

        if needs_terminal:
            subprocess.Popen([TERMINAL, "--hold", "-e", "bash", "-l", "-c", cmd])
        else:
            subprocess.Popen(cmd, shell=True)

        QtWidgets.QApplication.quit()

    # --- Desktop file parser (Same) ---
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

    # --- Collect applications (Same) ---
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


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    picker = AppPicker()
    sys.exit(app.exec())
