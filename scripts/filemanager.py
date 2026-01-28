#!/usr/bin/env python3
"""
PyQt5 File Manager with LIVE Pywal theming + Hover Preview + Nerd Font Icons + Semi-Transparency
- Tree on top-left, Preview below tree (fixed height)
- File list on right
- Live Pywal colors
- Back / Home / Refresh / Copy / Cut / Paste / Delete
- Toggle button for hidden files
- Uses Nerd Font glyphs for folder/file icons
- Semi-transparent panels
"""

import sys, json, shutil, subprocess
from pathlib import Path
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QListWidget, QListWidgetItem, QPushButton, QLabel, QLineEdit,
    QMessageBox, QSplitter, QMenu, QTreeWidgetItem, QTreeWidget,
    QSizePolicy, QStyleFactory
)
from PyQt5.QtCore import Qt, QFileSystemWatcher
from PyQt5.QtGui import QFont, QColor, QPalette, QPixmap

# ---------------- Main File Manager ----------------
class FileManager(QMainWindow):
    def __init__(self):
        super().__init__()

        self.current_path = str(Path.home())
        self.clipboard = []
        self.clipboard_action = None
        self.colors_file = Path.home() / ".cache" / "wal" / "colors.json"
        self.show_hidden = False

        # Nerd Font icons
        self.icon_font = QFont("JetBrainsMono Nerd Font", 12)
        self.folder_glyph = ""
        self.file_glyph = ""
        self.video_glyph = "󰈙"

        # Watch Pywal colors.json for live updates
        self.watcher = QFileSystemWatcher([str(self.colors_file)])
        self.watcher.fileChanged.connect(self.reload_pywal_theme)

        self.colors = self.load_pywal_colors()

        self.initUI()
        self.apply_theme()
        self.load_directory(self.current_path)

    # ---------------- Live Pywal Reload ----------------
    def reload_pywal_theme(self):
        self.colors = self.load_pywal_colors()
        self.apply_theme()
        self.populate_tree()
        self.load_directory(self.current_path)

    # ---------------- Theme ----------------
    def load_pywal_colors(self):
        try:
            if self.colors_file.exists():
                with open(self.colors_file, "r") as f:
                    data = json.load(f)
                return data.get("colors", {})
        except Exception as e:
            print("pywal load failed:", e)
        return {"color0": "#1e1e2e","color7": "#cdd6f4","color4": "#89b4fa","color8": "#45475a"}

    def apply_theme(self):
        bg = QColor(self.colors.get("color0","#1e1e2e"))
        fg = QColor(self.colors.get("color7","#cdd6f4"))
        accent = QColor(self.colors.get("color4","#89b4fa"))
        hover = QColor(self.colors.get("color8","#45475a"))

        QApplication.setStyle(QStyleFactory.create("Fusion"))
        palette = QApplication.palette()
        palette.setColor(QPalette.Window, bg)
        palette.setColor(QPalette.WindowText, fg)
        palette.setColor(QPalette.Base, bg)
        palette.setColor(QPalette.AlternateBase, hover)
        palette.setColor(QPalette.Text, fg)
        palette.setColor(QPalette.Button, hover)
        palette.setColor(QPalette.ButtonText, fg)
        palette.setColor(QPalette.Highlight, accent)
        palette.setColor(QPalette.HighlightedText, bg)
        QApplication.setPalette(palette)

        # Semi-transparent panels
        bg_rgba = f"rgba({bg.red()},{bg.green()},{bg.blue()},180)"
        hover_rgba = f"rgba({hover.red()},{hover.green()},{hover.blue()},120)"
        accent_rgba = f"rgba({accent.red()},{accent.green()},{accent.blue()},180)"

        self.setStyleSheet(f"""
            QWidget {{
                background-color: {bg_rgba};
            }}
            QPushButton {{
                border-radius: 8px;
                padding: 6px 12px;
            }}
            QPushButton:hover {{
                background-color: {accent_rgba};
                color: {bg.name()};
            }}
            QLineEdit {{
                border-radius: 6px;
                padding: 4px 8px;
                background-color: {bg_rgba};
                color: {fg.name()};
            }}
            QListWidget, QTreeWidget {{
                background-color: {bg_rgba};
            }}
            QListWidget::item:hover {{
                background-color: {hover_rgba};
            }}
        """)

    # ---------------- UI ----------------
    def initUI(self):
        self.setWindowTitle("File Manager")
        self.setGeometry(100,100,1200,700)

        # --- Enable semi-transparency ---
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setWindowFlags(self.windowFlags() | Qt.FramelessWindowHint)

        icon_font = QFont("JetBrainsMono Nerd Font",14)

        central = QWidget()
        self.setCentralWidget(central)
        main = QVBoxLayout(central)

        # Toolbar
        bar = QHBoxLayout()
        self.btn_back = QPushButton("󰁍 Back"); self.btn_back.setFont(icon_font); self.btn_back.clicked.connect(self.go_back)
        self.btn_home = QPushButton("󰋜 Home"); self.btn_home.setFont(icon_font); self.btn_home.clicked.connect(self.go_home)
        self.btn_refresh = QPushButton("󰑐 Refresh"); self.btn_refresh.setFont(icon_font); self.btn_refresh.clicked.connect(self.refresh)
        self.path_edit = QLineEdit(self.current_path); self.path_edit.returnPressed.connect(self.navigate_to_path)
        bar.addWidget(self.btn_back); bar.addWidget(self.btn_home); bar.addWidget(self.btn_refresh)
        bar.addWidget(QLabel("Path:")); bar.addWidget(self.path_edit)

        # Hidden files toggle button
        self.btn_hidden = QPushButton("󰜉 Show Hidden"); self.btn_hidden.setFont(icon_font); self.btn_hidden.setCheckable(True)
        self.btn_hidden.toggled.connect(self.toggle_hidden)
        bar.addWidget(self.btn_hidden)

        main.addLayout(bar)

        # Actions
        actions = QHBoxLayout()
        self.btn_copy = QPushButton("󰆏 Copy"); self.btn_cut  = QPushButton("󰩨 Cut")
        self.btn_paste= QPushButton("󰅌 Paste"); self.btn_delete=QPushButton("󰩹 Delete")
        for b in [self.btn_copy,self.btn_cut,self.btn_paste,self.btn_delete]:
            b.setFont(icon_font)
        actions.addWidget(self.btn_copy); actions.addWidget(self.btn_cut); actions.addWidget(self.btn_paste); actions.addWidget(self.btn_delete); actions.addStretch()
        main.addLayout(actions)

        # ---------------- Split view ----------------
        self.splitter = QSplitter(Qt.Horizontal)

        # Left panel (Tree + Preview)
        self.left_panel = QWidget()
        left_layout = QVBoxLayout(self.left_panel)

        self.tree = QTreeWidget()
        self.tree.setHeaderLabel("Folders")
        self.tree.itemClicked.connect(self.tree_clicked)
        self.populate_tree()
        left_layout.addWidget(self.tree, stretch=3)

        self.preview_label = QLabel("")  # start empty
        self.preview_label.setAlignment(Qt.AlignCenter)
        self.preview_label.setMinimumHeight(200)
        self.preview_label.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        left_layout.addWidget(self.preview_label, stretch=0)

        self.splitter.addWidget(self.left_panel)

        # Right panel (File list)
        self.file_list = QListWidget()
        self.file_list.itemDoubleClicked.connect(self.item_opened)
        self.file_list.setSelectionMode(QListWidget.ExtendedSelection)
        self.file_list.setContextMenuPolicy(Qt.CustomContextMenu)
        self.file_list.customContextMenuRequested.connect(self.show_context_menu)
        self.file_list.itemSelectionChanged.connect(self.update_preview)
        # Hover preview
        self.file_list.setMouseTracking(True)
        self.file_list.enterEvent = self.start_hover_preview
        self.file_list.leaveEvent = self.stop_hover_preview
        self.file_list.viewport().installEventFilter(self)
        self.splitter.addWidget(self.file_list)
        self.splitter.setStretchFactor(1,1)
        main.addWidget(self.splitter)

        # Status bar
        self.statusBar().showMessage("Ready")

    # ---------------- Tooltip helper ----------------
    def set_instant_tooltip(self, button, text):
        button.setToolTip(text)
        button.setMouseTracking(True)

    # ---------------- Toggle Hidden ----------------
    def toggle_hidden(self, checked):
        self.show_hidden = checked
        self.refresh()

    # ---------------- Preview Pane ----------------
    def update_preview(self):
        items = self.file_list.selectedItems()
        if not items:
            self.preview_label.clear()
            return
        self.show_preview_for_item(items[0])

    def show_preview_for_item(self, item):
        path = Path(item.data(Qt.UserRole))
        suffix = path.suffix.lower()
        if path.is_file() and suffix in [".png",".jpg",".jpeg",".bmp",".gif"]:
            pixmap = QPixmap(str(path))
            if not pixmap.isNull():
                pixmap = pixmap.scaled(self.preview_label.width(), self.preview_label.height(), Qt.KeepAspectRatio, Qt.SmoothTransformation)
                self.preview_label.setPixmap(pixmap)
            else: self.preview_label.setText("Cannot load preview")
        elif path.is_file() and suffix in [".mp4",".mkv",".webm",".mov"]:
            self.preview_label.clear()
            self.preview_label.setText(self.video_glyph)
            self.preview_label.setFont(QFont("JetBrainsMono Nerd Font",72))
        elif path.is_dir():
            self.preview_label.clear()
            self.preview_label.setText(self.folder_glyph)
            self.preview_label.setFont(QFont("JetBrainsMono Nerd Font",72))
        else:
            self.preview_label.clear()
            self.preview_label.setText(self.file_glyph)
            self.preview_label.setFont(QFont("JetBrainsMono Nerd Font",72))
        self.preview_label.setAlignment(Qt.AlignCenter)

    # ---------------- Hover Preview ----------------
    def start_hover_preview(self, event): self.file_list.viewport().setMouseTracking(True)
    def stop_hover_preview(self, event): self.preview_label.clear()
    def eventFilter(self, source, event):
        if event.type() == event.MouseMove and source is self.file_list.viewport():
            item = self.file_list.itemAt(event.pos())
            if item: self.show_preview_for_item(item)
            else: self.preview_label.clear()
        return super().eventFilter(source,event)

    # ---------------- Tree ----------------
    def populate_tree(self):
        self.tree.clear()
        home = Path.home()
        home_item = QTreeWidgetItem([f"{self.folder_glyph} {home.name}"])
        home_item.setData(0, Qt.UserRole, str(home))
        home_item.setFont(0, self.icon_font)
        self.tree.addTopLevelItem(home_item)
        for p in sorted(home.iterdir()):
            if not self.show_hidden and p.name.startswith("."): continue
            if p.is_dir():
                item = QTreeWidgetItem([f"{self.folder_glyph} {p.name}"])
                item.setData(0, Qt.UserRole, str(p))
                item.setFont(0, self.icon_font)
                home_item.addChild(item)
        home_item.setExpanded(True)

    def tree_clicked(self, item, column):
        path = item.data(0, Qt.UserRole)
        if path: self.load_directory(path)

    # ---------------- Files ----------------
    def load_directory(self, path):
        try:
            self.file_list.clear()
            self.current_path = path
            self.path_edit.setText(path)
            if path != "/":
                parent_item = QListWidgetItem(f"{self.folder_glyph} ..")
                parent_item.setData(Qt.UserRole,str(Path(path).parent))
                parent_item.setFont(self.icon_font)
                self.file_list.addItem(parent_item)
            entries = sorted(Path(path).iterdir(), key=lambda x:(not x.is_dir(),x.name.lower()))
            visible=0
            for e in entries:
                if not self.show_hidden and e.name.startswith("."): continue
                glyph = self.folder_glyph if e.is_dir() else self.file_glyph
                item = QListWidgetItem(f"{glyph} {e.name}")
                item.setData(Qt.UserRole,str(e))
                item.setFont(self.icon_font)
                self.file_list.addItem(item)
                visible+=1
            self.statusBar().showMessage(f"{visible} items")
            self.update_preview()
        except Exception as e: QMessageBox.critical(self,"Error", str(e))

    def item_opened(self, item):
        path = item.data(Qt.UserRole)
        if Path(path).is_dir(): self.load_directory(path)
        else: subprocess.Popen(["xdg-open", path])

    # ---------------- Context Menu ----------------
    def show_context_menu(self, position):
        menu = QMenu(self)
        copy_action = menu.addAction("Copy")
        cut_action = menu.addAction("Cut")
        paste_action = menu.addAction("Paste"); paste_action.setEnabled(bool(self.clipboard))
        menu.addSeparator()
        delete_action = menu.addAction("Delete")
        action = menu.exec_(self.file_list.mapToGlobal(position))
        if action == copy_action: self.copy_files()
        elif action == cut_action: self.cut_files()
        elif action == paste_action: self.paste_files()
        elif action == delete_action: self.delete_files()

    # ---------------- Clipboard ----------------
    def get_selected_paths(self): return [i.data(Qt.UserRole) for i in self.file_list.selectedItems()]
    def copy_files(self): self.clipboard = self.get_selected_paths(); self.clipboard_action="copy"; self.statusBar().showMessage(f"Copied {len(self.clipboard)} item(s)")
    def cut_files(self): self.clipboard = self.get_selected_paths(); self.clipboard_action="cut"; self.statusBar().showMessage(f"Cut {len(self.clipboard)} item(s)")
    def paste_files(self):
        if not self.clipboard: return
        errors=[]
        for src in self.clipboard:
            try:
                src_p = Path(src)
                dest = Path(self.current_path)/src_p.name
                counter=1
                while dest.exists(): dest = Path(self.current_path)/f"{src_p.stem}_{counter}{src_p.suffix}"; counter+=1
                if self.clipboard_action=="copy":
                    if src_p.is_dir(): shutil.copytree(src,dest)
                    else: shutil.copy2(src,dest)
                else: shutil.move(src,dest)
            except Exception as e: errors.append(str(e))
        if self.clipboard_action=="cut": self.clipboard=[]
        self.refresh()
        if errors: QMessageBox.warning(self,"Errors","\n".join(errors))

    def delete_files(self):
        paths=self.get_selected_paths()
        if not paths: return
        reply=QMessageBox.question(self,"Delete",f"Delete {len(paths)} item(s)?")
        if reply!=QMessageBox.Yes: return
        errors=[]
        for p in paths:
            try:
                path=Path(p)
                if path.is_dir(): shutil.rmtree(path)
                else: path.unlink()
            except Exception as e: errors.append(str(e))
        self.refresh()
        if errors: QMessageBox.warning(self,"Errors","\n".join(errors))

    # ---------------- Navigation ----------------
    def go_back(self): self.load_directory(str(Path(self.current_path).parent))
    def go_home(self): self.load_directory(str(Path.home()))
    def refresh(self): self.load_directory(self.current_path)
    def navigate_to_path(self):
        path=self.path_edit.text()
        if Path(path).is_dir(): self.load_directory(path)
        else: QMessageBox.warning(self,"Invalid Path", path); self.path_edit.setText(self.current_path)

# ---------------- Main ----------------
def main():
    app=QApplication(sys.argv)
    app.setFont(QFont("JetBrainsMono Nerd Font",10))
    win=FileManager()
    win.show()
    sys.exit(app.exec_())

if __name__=="__main__":
    main()
