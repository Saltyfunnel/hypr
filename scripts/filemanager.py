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
- OPTIMIZED: Async image loading, caching, debouncing to prevent UI hangs
"""

import sys, json, shutil, subprocess, tempfile
from pathlib import Path
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QListWidget, QListWidgetItem, QPushButton, QLabel, QLineEdit,
    QMessageBox, QSplitter, QMenu, QTreeWidgetItem, QTreeWidget,
    QSizePolicy, QStyleFactory
)
from PyQt5.QtCore import Qt, QFileSystemWatcher, QThread, pyqtSignal, QTimer
from PyQt5.QtGui import QFont, QColor, QPalette, QPixmap, QImage

# ---------------- Image Loader Thread ----------------
class ImageLoaderThread(QThread):
    """Async thread for loading images without blocking UI"""
    image_loaded = pyqtSignal(str, QPixmap)
    
    def __init__(self, filepath, target_width, target_height):
        super().__init__()
        self.filepath = filepath
        self.target_width = target_width
        self.target_height = target_height
    
    def run(self):
        try:
            # Load image with size hint to avoid loading full resolution
            reader = QImage(self.filepath)
            if not reader.isNull():
                # Scale to reasonable preview size before converting to pixmap
                scaled = reader.scaled(
                    self.target_width, 
                    self.target_height, 
                    Qt.KeepAspectRatio, 
                    Qt.SmoothTransformation
                )
                pixmap = QPixmap.fromImage(scaled)
                self.image_loaded.emit(self.filepath, pixmap)
        except Exception as e:
            print(f"Image load error: {e}")

# ---------------- Main File Manager ----------------
class FileManager(QMainWindow):
    def __init__(self):
        super().__init__()

        self.current_path = str(Path.home())
        self.clipboard = []
        self.clipboard_action = None
        self.colors_file = Path.home() / ".cache" / "wal" / "colors.json"
        self.show_hidden = False

        # Image cache to prevent reloading
        self.image_cache = {}
        self.cache_max_size = 50  # Max cached images
        
        # Current loading thread
        self.current_loader = None
        
        # Hover debounce timer
        self.hover_timer = QTimer()
        self.hover_timer.setSingleShot(True)
        self.hover_timer.timeout.connect(self.load_hovered_preview)
        self.hover_delay = 150  # ms delay before loading preview
        self.pending_hover_item = None

        # Nerd Font icons (using Unicode escape codes)
        self.icon_font = QFont("JetBrainsMono Nerd Font", 12)
        self.folder_glyph = "\uf07b"  # nf-fa-folder
        self.file_glyph = "\uf15b"  # nf-fa-file
        self.video_glyph = "\U000f0219"  # nf-md-video
        
        # Debug: Check if font is available
        print(f"Icon font family: {self.icon_font.family()}")
        print(f"Folder glyph: '{self.folder_glyph}' (U+{ord(self.folder_glyph):04X})")
        print(f"File glyph: '{self.file_glyph}' (U+{ord(self.file_glyph):04X})")

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
                colors = data.get("colors", {})
                if colors:
                    print(f"✓ Loaded pywal colors from {self.colors_file}")
                    print(f"  color0: {colors.get('color0')}, color7: {colors.get('color7')}")
                    return colors
                else:
                    print(f"⚠ colors.json exists but 'colors' key is empty")
            else:
                print(f"⚠ Pywal colors file not found: {self.colors_file}")
        except Exception as e:
            print(f"✗ pywal load failed: {e}")
        
        print("→ Using fallback Catppuccin colors")
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

        # More transparent panels - lower alpha = more see-through
        bg_rgba = f"rgba({bg.red()},{bg.green()},{bg.blue()},120)"  # More transparent
        hover_rgba = f"rgba({hover.red()},{hover.green()},{hover.blue()},100)"
        accent_rgba = f"rgba({accent.red()},{accent.green()},{accent.blue()},150)"

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
                color: {fg.name()};
                border: none;
            }}
            QTreeWidget::item {{
                color: {fg.name()};
                background-color: transparent;
            }}
            QTreeWidget::item:selected {{
                background-color: {hover_rgba};
            }}
            QTreeWidget::item:hover {{
                background-color: {hover_rgba};
            }}
            QTreeWidget::branch {{
                background-color: transparent;
            }}
            QHeaderView::section {{
                background-color: transparent;
                color: {fg.name()};
                border: none;
                padding: 4px;
            }}
            QListWidget::item {{
                color: {fg.name()};
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
        bar.addWidget(self.path_edit)

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
        self.btn_copy.clicked.connect(self.copy_files)
        self.btn_cut.clicked.connect(self.cut_files)
        self.btn_paste.clicked.connect(self.paste_files)
        self.btn_delete.clicked.connect(self.delete_files)
        actions.addWidget(self.btn_copy); actions.addWidget(self.btn_cut); actions.addWidget(self.btn_paste); actions.addWidget(self.btn_delete); actions.addStretch()
        main.addLayout(actions)

        # ---------------- Split view ----------------
        self.splitter = QSplitter(Qt.Horizontal)

        # Left panel (Tree + Preview)
        self.left_panel = QWidget()
        left_layout = QVBoxLayout(self.left_panel)

        self.tree = QTreeWidget()
        self.tree.setHeaderLabel("Folders")
        self.tree.setFont(self.icon_font)
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
        self.file_list.setFont(self.icon_font)
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

    # ---------------- Toggle Hidden ----------------
    def toggle_hidden(self, checked):
        self.show_hidden = checked
        self.refresh()

    # ---------------- Cache Management ----------------
    def add_to_cache(self, filepath, pixmap):
        """Add image to cache with size limit"""
        if len(self.image_cache) >= self.cache_max_size:
            # Remove oldest entry (first key)
            self.image_cache.pop(next(iter(self.image_cache)))
        self.image_cache[filepath] = pixmap

    def clear_cache(self):
        """Clear image cache"""
        self.image_cache.clear()

    # ---------------- Preview Pane ----------------
    def update_preview(self):
        """Update preview when selection changes"""
        items = self.file_list.selectedItems()
        if not items:
            self.preview_label.clear()
            return
        self.show_preview_for_item(items[0])

    def show_preview_for_item(self, item):
        """Show preview for a specific item"""
        # Cancel any pending loader thread
        if self.current_loader and self.current_loader.isRunning():
            self.current_loader.wait()
        
        path = Path(item.data(Qt.UserRole))
        suffix = path.suffix.lower()
        
        if path.is_file() and suffix in [".png",".jpg",".jpeg",".bmp",".gif",".webp"]:
            filepath = str(path)
            
            # Check cache first
            if filepath in self.image_cache:
                self.preview_label.setPixmap(self.image_cache[filepath])
                self.preview_label.setFont(self.icon_font)
                return
            
            # Show loading indicator
            self.preview_label.clear()
            self.preview_label.setText("⏳ Loading...")
            self.preview_label.setFont(QFont("JetBrainsMono Nerd Font", 16))
            
            # Load asynchronously
            self.current_loader = ImageLoaderThread(
                filepath, 
                self.preview_label.width(), 
                self.preview_label.height()
            )
            self.current_loader.image_loaded.connect(self.on_image_loaded)
            self.current_loader.start()
            
        elif path.is_file() and suffix in [".mp4",".mkv",".webm",".mov",".avi",".flv"]:
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

    def on_image_loaded(self, filepath, pixmap):
        """Callback when image is loaded asynchronously"""
        if not pixmap.isNull():
            # Add to cache
            self.add_to_cache(filepath, pixmap)
            # Display if still relevant
            self.preview_label.setPixmap(pixmap)
        else:
            self.preview_label.setText("❌ Cannot load")
            self.preview_label.setFont(QFont("JetBrainsMono Nerd Font", 16))

    # ---------------- Hover Preview with Debouncing ----------------
    def start_hover_preview(self, event): 
        self.file_list.viewport().setMouseTracking(True)
    
    def stop_hover_preview(self, event): 
        self.hover_timer.stop()
        self.pending_hover_item = None
        self.preview_label.clear()
    
    def eventFilter(self, source, event):
        """Handle mouse move events with debouncing"""
        if event.type() == event.MouseMove and source is self.file_list.viewport():
            item = self.file_list.itemAt(event.pos())
            if item and item != self.pending_hover_item:
                # Schedule preview load after delay
                self.pending_hover_item = item
                self.hover_timer.stop()
                self.hover_timer.start(self.hover_delay)
            elif not item:
                self.hover_timer.stop()
                self.pending_hover_item = None
        return super().eventFilter(source, event)
    
    def load_hovered_preview(self):
        """Actually load the preview after debounce delay"""
        if self.pending_hover_item:
            self.show_preview_for_item(self.pending_hover_item)

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
            # Clear cache when changing directories
            self.clear_cache()
            
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
        
        # Get selected items
        selected = self.file_list.selectedItems()
        
        # Basic operations
        copy_action = menu.addAction("Copy")
        cut_action = menu.addAction("Cut")
        paste_action = menu.addAction("Paste"); paste_action.setEnabled(bool(self.clipboard))
        menu.addSeparator()
        
        # Archive operations (only if single archive selected)
        if len(selected) == 1:
            path = Path(selected[0].data(Qt.UserRole))
            if self.is_archive(path):
                extract_here = menu.addAction("📦 Extract Here")
                extract_to = menu.addAction("📂 Extract To...")
                menu.addSeparator()
        
        delete_action = menu.addAction("Delete")
        
        action = menu.exec_(self.file_list.mapToGlobal(position))
        if action == copy_action: self.copy_files()
        elif action == cut_action: self.cut_files()
        elif action == paste_action: self.paste_files()
        elif action == delete_action: self.delete_files()
        elif len(selected) == 1 and self.is_archive(Path(selected[0].data(Qt.UserRole))):
            if action.text() == "📦 Extract Here":
                self.extract_here(Path(selected[0].data(Qt.UserRole)))
            elif action.text() == "📂 Extract To...":
                self.extract_to(Path(selected[0].data(Qt.UserRole)))

    # ---------------- Archive Detection ----------------
    def is_archive(self, path):
        """Check if file is a supported archive"""
        if not path.is_file():
            return False
        ext = path.suffix.lower()
        archive_exts = ['.zip', '.tar', '.gz', '.bz2', '.xz', '.7z', '.rar', 
                       '.tar.gz', '.tar.bz2', '.tar.xz', '.tgz', '.tbz2', '.txz']
        # Check for compound extensions
        if path.suffixes:
            compound = ''.join(path.suffixes[-2:]).lower()
            if compound in archive_exts:
                return True
        return ext in archive_exts

    # ---------------- Archive Extraction ----------------
    def extract_here(self, archive_path):
        """Extract archive to current directory"""
        try:
            self.statusBar().showMessage(f"Extracting {archive_path.name}...")
            QApplication.processEvents()  # Update UI
            
            extract_path = archive_path.parent
            success = self.extract_archive(archive_path, extract_path)
            
            if success:
                self.statusBar().showMessage(f"✓ Extracted {archive_path.name}")
                self.refresh()
            else:
                QMessageBox.warning(self, "Extraction Failed", 
                                  f"Could not extract {archive_path.name}")
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))

    def extract_to(self, archive_path):
        """Extract archive to a new folder with archive name"""
        try:
            # Create extraction folder with archive name (without extension)
            folder_name = archive_path.stem
            if archive_path.suffixes and len(archive_path.suffixes) > 1:
                # Handle .tar.gz, .tar.bz2, etc.
                folder_name = archive_path.name
                for ext in ['.tar.gz', '.tar.bz2', '.tar.xz', '.tgz', '.tbz2', '.txz']:
                    if archive_path.name.lower().endswith(ext):
                        folder_name = archive_path.name[:-len(ext)]
                        break
            
            extract_path = archive_path.parent / folder_name
            counter = 1
            while extract_path.exists():
                extract_path = archive_path.parent / f"{folder_name}_{counter}"
                counter += 1
            
            extract_path.mkdir(parents=True, exist_ok=True)
            
            self.statusBar().showMessage(f"Extracting {archive_path.name} to {extract_path.name}...")
            QApplication.processEvents()
            
            success = self.extract_archive(archive_path, extract_path)
            
            if success:
                self.statusBar().showMessage(f"✓ Extracted to {extract_path.name}")
                self.refresh()
            else:
                # Clean up empty folder if extraction failed
                if extract_path.exists() and not any(extract_path.iterdir()):
                    extract_path.rmdir()
                QMessageBox.warning(self, "Extraction Failed", 
                                  f"Could not extract {archive_path.name}")
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))

    def extract_archive(self, archive_path, extract_path):
        """Extract archive using appropriate tool"""
        ext = archive_path.suffix.lower()
        
        # Check for compound extensions
        compound_ext = None
        if archive_path.suffixes and len(archive_path.suffixes) > 1:
            compound_ext = ''.join(archive_path.suffixes[-2:]).lower()
        
        try:
            # ZIP files
            if ext == '.zip':
                result = subprocess.run(['unzip', '-q', str(archive_path), '-d', str(extract_path)],
                                      capture_output=True, text=True)
                return result.returncode == 0
            
            # 7Z files
            elif ext == '.7z':
                result = subprocess.run(['7z', 'x', str(archive_path), f'-o{extract_path}', '-y'],
                                      capture_output=True, text=True)
                return result.returncode == 0
            
            # RAR files
            elif ext == '.rar':
                result = subprocess.run(['unrar', 'x', '-y', str(archive_path), str(extract_path)],
                                      capture_output=True, text=True)
                return result.returncode == 0
            
            # TAR and compressed TAR files
            elif compound_ext in ['.tar.gz', '.tar.bz2', '.tar.xz'] or ext in ['.tgz', '.tbz2', '.txz', '.tar']:
                result = subprocess.run(['tar', '-xf', str(archive_path), '-C', str(extract_path)],
                                      capture_output=True, text=True)
                return result.returncode == 0
            
            # Standalone compression (gz, bz2, xz)
            elif ext in ['.gz', '.bz2', '.xz']:
                # These are single-file compression, extract to file without extension
                output_file = extract_path / archive_path.stem
                if ext == '.gz':
                    result = subprocess.run(['gunzip', '-c', str(archive_path)],
                                          capture_output=True)
                elif ext == '.bz2':
                    result = subprocess.run(['bunzip2', '-c', str(archive_path)],
                                          capture_output=True)
                elif ext == '.xz':
                    result = subprocess.run(['unxz', '-c', str(archive_path)],
                                          capture_output=True)
                
                if result.returncode == 0:
                    with open(output_file, 'wb') as f:
                        f.write(result.stdout)
                    return True
                return False
            
            return False
            
        except FileNotFoundError as e:
            QMessageBox.critical(self, "Tool Missing", 
                               f"Required extraction tool not found. Please install the necessary package.")
            return False
        except Exception as e:
            print(f"Extraction error: {e}")
            return False

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
