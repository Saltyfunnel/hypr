#!/usr/bin/env python3
import sys
import subprocess
import configparser
from pathlib import Path
from PyQt6 import QtWidgets, QtGui, QtCore

# --- Configuration Constants ---
APP_DIRS = [
    Path.home() / ".local/share/applications",
    Path("/usr/share/applications"),
]
OPACITY = 230 
ICON_SIZE = QtCore.QSize(32, 32) 

# --- NEW: Keywords for excluding unwanted apps from the launcher list ---
EXCLUDE_KEYWORDS = [
    "ssh", "server", "avahi", "browser", "helper", 
    "setup", "settings daemon", "gnome-session", "kde-", 
    "xfce-", "gimp", "manjaro"
]
# ------------------------------------------------------------------------

# --- AppPicker Class (Fuzzy Search) ---
class AppPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Pick an Application")
        
        # Window setup for Hyprland
        self.setWindowFlag(QtCore.Qt.WindowType.WindowStaysOnTopHint)
        self.setWindowFlag(QtCore.Qt.WindowType.Tool)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)

        self.applications = self.find_applications()
        if not self.applications:
            QtWidgets.QMessageBox.warning(self, "Error", "No applications found.")
            sys.exit(1)

        # Pywal color setup
        self.BG, self.FG, self.BORDER = self.get_pywal_colors()
        
        # FIXES: Instance variables
        self.ICON_SIZE = ICON_SIZE 
        self.SHOW_APP_ICONS = False # Set to False for a clean, text-only list
        
        # --- COLOR TINT LOGIC (Aggressive Tint) ---
        TINT_FACTOR = 30 # 30% mix of BORDER color into BG color for visible tint
        
        base_color = QtGui.QColor(self.BG)
        tint_color = QtGui.QColor(self.BORDER)
        
        # Interpolate (mix) the base color and the tint color
        mix_factor = TINT_FACTOR / 100.0
        r = int(base_color.red() * (1 - mix_factor) + tint_color.red() * mix_factor)
        g = int(base_color.green() * (1 - mix_factor) + tint_color.green() * mix_factor)
        b = int(base_color.blue() * (1 - mix_factor) + tint_color.blue() * mix_factor)

        # Create the final color and apply opacity
        final_color = QtGui.QColor(r, g, b)
        final_color.setAlpha(OPACITY)
        rgba_bg = f"rgba({final_color.red()},{final_color.green()},{final_color.blue()},{final_color.alpha()})"
        # ------------------------
        
        self.setStyleSheet(f"background-color: {rgba_bg}; border: 1px solid {self.BORDER}; border-radius: 8px;")

        # --- Widgets ---
        
        # 1. Search Bar (QLineEdit)
        self.search_input = QtWidgets.QLineEdit()
        self.search_input.setPlaceholderText("Search applications...")
        
        # --- Add Themed Arch Logo Action ---
        arch_icon_themed = self.get_themed_logo("archlinux-logo", self.FG)
        search_action = QtGui.QAction(arch_icon_themed, "", self.search_input)
        self.search_input.addAction(search_action, QtWidgets.QLineEdit.ActionPosition.LeadingPosition)
        # ------------------------------------
        
        self.search_input.setStyleSheet(f"""
            QLineEdit {{
                border: 2px solid {self.BORDER};
                border-radius: 4px;
                padding: 5px;
                padding-left: 28px; 
                color: {self.FG};
                background-color: {self.BG};
            }}
        """)
        self.search_input.textChanged.connect(self.filter_list)
        self.search_input.returnPressed.connect(self.launch_selected)
        
        self.search_input.keyPressEvent = self.search_key_press_event 


        # 2. List View (QListView)
        self.list_view = QtWidgets.QListView()
        self.list_view.setEditTriggers(QtWidgets.QAbstractItemView.EditTrigger.NoEditTriggers)
        self.list_view.setFocusPolicy(QtCore.Qt.FocusPolicy.NoFocus) 
        self.list_view.setSelectionMode(QtWidgets.QAbstractItemView.SelectionMode.SingleSelection)
        self.list_view.doubleClicked.connect(self.launch_selected)

        self.list_view.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.list_view.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        
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
                background-color: {self.BORDER}50; 
                border: none;
            }}
        """)

        # 3. Model for the list (holds the data)
        self.model = QtGui.QStandardItemModel()
        self.list_view.setModel(self.model)
        self.populate_model()
        
        # --- Layout ---
        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(self.search_input)
        layout.addWidget(self.list_view)
        layout.setContentsMargins(10, 10, 10, 10)
        
        self.resize(500, 350) 
        self.search_input.setFocus()
        
        if self.model.rowCount() > 0:
            self.list_view.setCurrentIndex(self.model.index(0, 0))
        
        self.show()

    # --- Icon Theming Methods ---
    def recolor_icon(self, icon, color_hex):
        """Manually recolors a QIcon's pixmap representation to the given color."""
        pixmap = icon.pixmap(self.ICON_SIZE) 
        
        painter = QtGui.QPainter(pixmap)
        painter.setCompositionMode(QtGui.QPainter.CompositionMode.CompositionMode_SourceIn)
        painter.fillRect(pixmap.rect(), QtGui.QColor(color_hex))
        painter.end()
        
        return QtGui.QIcon(pixmap)

    def get_themed_logo(self, icon_name, color_hex):
        """Loads a logo, converts it to a pixmap, and manually recolors it for the QLineEdit."""
        icon = QtGui.QIcon.fromTheme(icon_name)
        if icon.isNull():
            icon = QtGui.QIcon.fromTheme("system-search")
            
        pixmap = icon.pixmap(QtCore.QSize(18, 18)) 
        
        painter = QtGui.QPainter(pixmap)
        painter.setCompositionMode(QtGui.QPainter.CompositionMode.CompositionMode_SourceIn)
        painter.fillRect(pixmap.rect(), QtGui.QColor(color_hex))
        painter.end()
        
        return QtGui.QIcon(pixmap)
    
    def get_app_icon(self, icon_name):
        """Find the QIcon, and force it to be recolored with the Pywal color."""
        
        symbolic_icon_name = icon_name + '-symbolic'
        icon = QtGui.QIcon.fromTheme(symbolic_icon_name)
        
        if icon.isNull():
            icon = QtGui.QIcon.fromTheme(icon_name)
            
        if icon.isNull() and Path(icon_name).exists():
            icon = QtGui.QIcon(icon_name)
        
        if not icon.isNull():
            return self.recolor_icon(icon, self.FG)
            
        return QtGui.QIcon.fromTheme('application-default')
    # -------------------------------

    # --- Keyboard Scroll Handler ---
    def search_key_press_event(self, event):
        """Intercepts Up/Down arrow keys and moves selection in the list view."""
        key = event.key()
        
        if key == QtCore.Qt.Key.Key_Up or key == QtCore.Qt.Key.Key_Down:
            current_index = self.list_view.currentIndex()
            
            if not current_index.isValid() and self.list_view.model().rowCount() > 0:
                 new_row = self.list_view.model().rowCount() - 1 if key == QtCore.Qt.Key.Key_Up else 0
            else:
                 row = current_index.row()
                 if key == QtCore.Qt.Key.Key_Up:
                     new_row = max(0, row - 1)
                 else: # Key_Down
                     new_row = min(self.list_view.model().rowCount() - 1, row + 1)
            
            new_index = self.list_view.model().index(new_row, 0)
            self.list_view.setCurrentIndex(new_index)
            self.list_view.scrollTo(new_index)
            
        elif key == QtCore.Qt.Key.Key_Escape:
             QtWidgets.QApplication.quit()
        else:
            QtWidgets.QLineEdit.keyPressEvent(self.search_input, event)

    def populate_model(self):
        """Fills the model with application data."""
        self.model.clear()
        sorted_apps = sorted(self.applications, key=lambda app: app['Name'])
        
        for app_info in sorted_apps:
            item = QtGui.QStandardItem(app_info['Name'])
            
            if self.SHOW_APP_ICONS:
                item.setIcon(self.get_app_icon(app_info.get('Icon', 'application-default')))
                
            item.setData(app_info['Exec'], QtCore.Qt.ItemDataRole.UserRole)
            self.model.appendRow(item)
    
    def filter_list(self, text):
        """Fuzzily filters the list based on the search input."""
        proxy_model = QtCore.QSortFilterProxyModel()
        proxy_model.setSourceModel(self.model)
        
        proxy_model.setFilterCaseSensitivity(QtCore.Qt.CaseSensitivity.CaseInsensitive)
        
        if text:
            escaped_text = QtCore.QRegularExpression.escape(text)
            proxy_model.setFilterRegularExpression(f".*{escaped_text}.*")
        
        self.list_view.setModel(proxy_model)
        
        if proxy_model.rowCount() > 0:
            self.list_view.setCurrentIndex(proxy_model.index(0, 0))
        
    def launch_selected(self):
        """Launches the application selected in the list view."""
        selected_index = self.list_view.currentIndex()
        if not selected_index.isValid():
            return

        model = self.list_view.model()
        exec_command = model.data(selected_index, QtCore.Qt.ItemDataRole.UserRole)
        
        if exec_command:
            self.launch_application(exec_command)

    def parse_desktop_file(self, path):
        """Parses a .desktop file to extract Name, Exec, and Icon."""
        parser = configparser.ConfigParser(interpolation=None) 
        
        try:
            with path.open('r', encoding='utf-8') as f:
                content = f.read()
            parser.read_string(content)
        except Exception:
            return None

        if 'Desktop Entry' in parser:
            entry = parser['Desktop Entry']
            info = {}
            
            if entry.getboolean('NoDisplay', fallback=False) or entry.get('Type') != 'Application':
                return None
            
            info['Name'] = entry.get('Name') 
            exec_cmd = entry.get('Exec', '').split('%', 1)[0].strip()
            info['Exec'] = exec_cmd
            info['Icon'] = entry.get('Icon')
            
            if not info['Name'] or not info['Exec']:
                return None
                
            return info
        return None

    def find_applications(self):
        """Locate and parse relevant application (.desktop) files, excluding unwanted apps."""
        apps = []
        app_names = set() 
        
        for app_dir in APP_DIRS:
            if app_dir.exists():
                for app_file in app_dir.glob("*.desktop"):
                    info = self.parse_desktop_file(app_file)
                    
                    if info and info['Name'] not in app_names:
                        app_name_lower = info['Name'].lower()
                        
                        # Check against Exclude Keywords
                        is_excluded = any(keyword in app_name_lower for keyword in EXCLUDE_KEYWORDS)
                        
                        if not is_excluded:
                            apps.append(info)
                            app_names.add(info['Name'])
                            
        return apps

    def get_pywal_colors(self):
        """Fetches Pywal colors from cache."""
        wal_cache = Path.home() / ".cache/wal/colors.css"
        colors = {}
        try:
            with open(wal_cache) as f:
                for line in f:
                    if line.startswith('--color'):
                        parts = line.split(':')
                        if len(parts) == 2:
                            key = parts[0].strip().lstrip('-')
                            value = parts[1].strip().rstrip(';').strip()
                            colors[key] = value
        except FileNotFoundError:
            return "#1d1f21", "#c5c8c6", "#5f819d"
        
        BG = colors.get("color0", "#1d1f21")
        FG = colors.get("color7", "#c5c8c6")
        BORDER = colors.get("color4", "#5f819d")
        return BG, FG, BORDER

    def launch_application(self, exec_command):
        """Execute the command to launch the application."""
        try:
            subprocess.Popen(exec_command, shell=True, close_fds=True)
        except OSError as e:
            print(f"Error launching application: {e}")
        
        QtWidgets.QApplication.quit()

if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    picker = AppPicker()
    sys.exit(app.exec())
