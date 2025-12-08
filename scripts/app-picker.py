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
OPACITY = 230  # Slightly more opaque for stability
ICON_SIZE = QtCore.QSize(32, 32)
FONT_NAME = "Fira Code"
FONT_SIZE = 11
TERMINAL = "kitty"

EXCLUDE_KEYWORDS = [
    "ssh", "server", "avahi", "browser", "helper",
    "setup", "settings daemon", "gnome-session", "kde-",
    "xfce-", "gimp", "about xfce"
]

# --- Helper Functions ---

def get_pywal_colors():
    """Reads Pywal colors and returns BG, FG, ACCENT."""
    wal = Path.home() / ".cache/wal/colors.json"
    # Fallback colors
    BG = "#1d1f21"
    FG = "#c5c8c6"
    ACCENT = "#5e81ac" 

    if not wal.exists():
        return BG, FG, ACCENT

    try:
        data = json.loads(wal.read_text())
        BG = data["special"]["background"]
        FG = data["special"]["foreground"]
        # Use color4 (blue) or color12 (light blue) as common accents
        ACCENT = data["colors"].get("color4") or data["colors"].get("color12") or ACCENT
        return BG, FG, ACCENT
    except Exception:
        # If Pywal file is corrupt or unreadable, return fallback
        return BG, FG, ACCENT

def parse_desktop_file(path):
    """Parses a .desktop file into an application dictionary."""
    parser = configparser.ConfigParser(interpolation=None)
    try:
        parser.read(path, encoding="utf-8")
    except Exception:
        return None

    if "Desktop Entry" not in parser:
        return None

    entry = parser["Desktop Entry"]
    if entry.get("Type") != "Application" or entry.getboolean("NoDisplay", fallback=False):
        return None

    name = entry.get("Name")
    exec_cmd = entry.get("Exec", "").split("%", 1)[0].strip()
    icon = entry.get("Icon")
    terminal = entry.getboolean("Terminal", fallback=False)

    if not name or not exec_cmd:
        return None

    lower_name = name.lower()
    if any(k in lower_name for k in EXCLUDE_KEYWORDS):
        return None

    return {"Name": name, "Exec": exec_cmd, "Icon": icon, "Terminal": terminal}


# --- Main Application Class ---

class AppPicker(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        
        # Load colors first
        self.BG, self.FG, self.ACCENT = get_pywal_colors()
        self.applications = self.find_applications()
        
        # --- Window Setup ---
        self.setWindowTitle("App Picker")
        self.setWindowFlag(QtCore.Qt.WindowType.WindowStaysOnTopHint)
        self.setWindowFlag(QtCore.Qt.WindowType.Tool)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground)
        
        # Frameless Window Hint for WM integration (like i3/sway)
        self.setWindowFlag(QtCore.Qt.WindowType.FramelessWindowHint)
        
        # --- Search Bar ---
        self.search_input = QtWidgets.QLineEdit()
        self.search_input.setPlaceholderText("Search...")
        self.search_input.textChanged.connect(self.filter_list)
        self.search_input.returnPressed.connect(self.launch_selected)

        # --- List Widget ---
        self.list_widget = QtWidgets.QListWidget()
        self.list_widget.setSelectionMode(QtWidgets.QAbstractItemView.SelectionMode.SingleSelection)
        self.list_widget.setFocusPolicy(QtCore.Qt.FocusPolicy.NoFocus) # Focus handled by search bar
        self.list_widget.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.list_widget.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.list_widget.doubleClicked.connect(self.launch_selected)

        self.populate_list()

        # --- Layout ---
        inner_layout = QtWidgets.QVBoxLayout()
        inner_layout.addWidget(self.search_input)
        inner_layout.addWidget(self.list_widget)
        inner_layout.setContentsMargins(15, 15, 15, 15)

        self.main_frame = QtWidgets.QFrame()
        self.main_frame.setLayout(inner_layout)
        
        # Drop shadow effect
        shadow = QtWidgets.QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(30)
        shadow.setOffset(0, 4)
        shadow.setColor(QtGui.QColor(0, 0, 0, 160))
        self.main_frame.setGraphicsEffect(shadow)

        outer_layout = QtWidgets.QVBoxLayout(self)
        outer_layout.addWidget(self.main_frame)
        outer_layout.setContentsMargins(0, 0, 0, 0)

        # --- Final Setup ---
        self.resize(500, 550)
        self.apply_styles()
        self.search_input.setFocus()
        self.setup_keyboard_navigation()
        self.show()

    def find_applications(self):
        """Collects and returns sorted list of unique applications."""
        apps, names = [], set()
        for app_dir in APP_DIRS:
            if app_dir.exists():
                for file in app_dir.glob("*.desktop"):
                    info = parse_desktop_file(file)
                    if info and info["Name"] not in names:
                        apps.append(info)
                        names.add(info["Name"])
        return sorted(apps, key=lambda a: a["Name"])

    def get_app_icon(self, icon_name):
        """Loads and rounds the application icon."""
        # Try symbolic, normal theme, then file path
        icon = QtGui.QIcon.fromTheme(icon_name + "-symbolic")
        if icon.isNull():
            icon = QtGui.QIcon.fromTheme(icon_name)
        if icon.isNull() and Path(icon_name).exists():
            icon = QtGui.QIcon(icon_name)
        if icon.isNull():
            icon = QtGui.QIcon.fromTheme("application-default")
            
        size = ICON_SIZE.width()
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

    def populate_list(self):
        """Fills the QListWidget with items and icon data."""
        self.list_widget.clear()
        
        for app in self.applications:
            # Create the QListWidgetItem
            item = QtWidgets.QListWidgetItem()
            item.setText(app["Name"])
            
            # Set the item's icon and size hint
            icon = self.get_app_icon(app.get("Icon", ""))
            item.setIcon(icon)
            
            # Set a fixed height for consistency (Icon height + vertical padding)
            item.setSizeHint(QtCore.QSize(0, ICON_SIZE.height() + 14)) 
            
            # Store launch data using the UserRole
            item.setData(QtCore.Qt.ItemDataRole.UserRole, app["Exec"])
            item.setData(QtCore.Qt.ItemDataRole.UserRole + 1, app["Terminal"])
            
            self.list_widget.addItem(item)

        # Select the first item immediately
        if self.list_widget.count() > 0:
            self.list_widget.setCurrentRow(0)

    # --- Interaction and Filtering ---

    def filter_list(self, text):
        """Filters the list based on the search input text."""
        text = text.lower()
        
        for i in range(self.list_widget.count()):
            item = self.list_widget.item(i)
            # Match if the name contains the search text
            is_visible = text in item.text().lower()
            item.setHidden(not is_visible)
        
        # After filtering, find and select the first visible item
        self.select_first_visible_item()

    def select_first_visible_item(self):
        """Selects the first non-hidden item in the list."""
        for i in range(self.list_widget.count()):
            item = self.list_widget.item(i)
            if not item.isHidden():
                self.list_widget.setCurrentRow(i)
                self.list_widget.scrollToItem(item, QtWidgets.QAbstractItemView.ScrollHint.PositionAtTop)
                return

    def launch_selected(self):
        """Launches the selected application and quits."""
        current_item = self.list_widget.currentItem()
        if not current_item:
            return

        cmd = current_item.data(QtCore.Qt.ItemDataRole.UserRole)
        needs_terminal = bool(current_item.data(QtCore.Qt.ItemDataRole.UserRole + 1))

        if needs_terminal:
            subprocess.Popen([TERMINAL, "-e", "bash", "-l", "-c", cmd])
        else:
            subprocess.Popen(cmd, shell=True)

        QtWidgets.QApplication.quit()

    # --- Keyboard Navigation ---

    def setup_keyboard_navigation(self):
        """Sets up key press event handlers for the search input."""
        def search_key_press_event(event):
            key = event.key()
            if key == QtCore.Qt.Key.Key_Up:
                self.navigate_list(-1)
            elif key == QtCore.Qt.Key.Key_Down:
                self.navigate_list(1)
            elif key == QtCore.Qt.Key.Key_Escape:
                QtWidgets.QApplication.quit()
            else:
                # Pass other keys to the default QLineEdit handler
                QtWidgets.QLineEdit.keyPressEvent(self.search_input, event)
        
        self.search_input.keyPressEvent = search_key_press_event

    def navigate_list(self, direction):
        """Moves the selection up or down, skipping hidden items."""
        current_row = self.list_widget.currentRow()
        new_row = current_row + direction
        count = self.list_widget.count()

        while 0 <= new_row < count:
            item = self.list_widget.item(new_row)
            if not item.isHidden():
                self.list_widget.setCurrentRow(new_row)
                self.list_widget.scrollToItem(item, QtWidgets.QAbstractItemView.ScrollHint.PositionAtCenter)
                return
            new_row += direction

    # --- Styling (Pywal Integration) ---

    def apply_styles(self):
        """Applies Pywal colors using stylesheets."""
        font = QtGui.QFont(FONT_NAME, FONT_SIZE)
        self.setFont(font)
        self.search_input.setFont(font)
        self.list_widget.setFont(font)
        
        # Calculate translucent background color
        base = QtGui.QColor(self.BG)
        white = QtGui.QColor("#ffffff")
        mix = 2 / 100
        r = int(base.red() * (1 - mix) + white.red() * mix)
        g = int(base.green() * (1 - mix) + white.green() * mix)
        b = int(base.blue() * (1 - mix) + white.blue() * mix)
        final_bg = QtGui.QColor(r, g, b)
        final_bg.setAlpha(self.OPACITY)
        rgba_bg = f"rgba({r},{g},{b},{final_bg.alpha()})"

        self.search_input.setStyleSheet(f"""
            QLineEdit {{
                border: 2px solid {self.ACCENT};
                border-radius: 8px;
                padding: 8px 12px;
                color: {self.FG};
                background-color: {self.BG};
            }}
        """)

        self.list_widget.setStyleSheet(f"""
            QListWidget {{
                background: transparent;
                border: none;
                outline: 0;
            }}
            QListWidget::item {{
                padding: 4px 10px;
                border-radius: 6px;
                margin: 2px 0;
                color: {self.FG};
            }}
            QListWidget::item:selected {{
                background: {self.ACCENT};
                color: {self.BG};
            }}
            QListWidget::item:hover:!selected {{
                background: rgba(255,255,255,0.08); 
            }}
        """)

        self.main_frame.setStyleSheet(f"""
            QFrame {{
                background-color: {rgba_bg};
                border: 1px solid {self.ACCENT};
                border-radius: 12px;
                /* If your window manager supports it: */
                /* backdrop-filter: blur(20px); */ 
            }}
        """)


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    picker = AppPicker()
    sys.exit(app.exec())
