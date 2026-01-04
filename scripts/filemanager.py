#!/usr/bin/env python3
import gi
import json
import subprocess
import shutil
from pathlib import Path

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GdkPixbuf, Gio

# --- CONFIG ---
WAL_COLORS = Path.home() / ".cache/wal/colors.json"

def get_wal():
    if not WAL_COLORS.exists(): return None
    try:
        with open(WAL_COLORS) as f:
            data = json.load(f)
        return {
            "bg": data["special"]["background"],
            "fg": data["special"]["foreground"],
            "acc": data["colors"]["color2"],
        }
    except: return None

class HorizonFM(Gtk.Window):
    def __init__(self):
        super().__init__(title="Horizon FM")
        self.set_default_size(1200, 750)
        self.cwd = Path.home()
        self.c = get_wal()
        
        self.clipboard_files = []
        self.clipboard_mode = None 

        self.main_layout = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.add(self.main_layout)

        # Sidebar
        self.side_strip = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        self.side_strip.set_size_request(65, -1)
        self.main_layout.pack_start(self.side_strip, False, False, 0)

        # Paned
        self.paned = Gtk.Paned.new(Gtk.Orientation.HORIZONTAL)
        self.main_layout.pack_start(self.paned, True, True, 0)

        # List Area
        self.list_scroll = Gtk.ScrolledWindow()
        self.listbox = Gtk.ListBox()
        self.listbox.set_selection_mode(Gtk.SelectionMode.MULTIPLE)
        self.list_scroll.add(self.listbox)
        self.paned.pack1(self.list_scroll, True, False)

        # Preview Area
        self.preview_eb = Gtk.EventBox()
        self.preview_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.preview_eb.add(self.preview_box)
        
        self.preview_image = Gtk.Image()
        self.preview_text = Gtk.TextView(editable=False, cursor_visible=False, left_margin=20, top_margin=20)
        self.preview_text.set_wrap_mode(Gtk.WrapMode.WORD)
        
        self.preview_stack = Gtk.Stack()
        self.preview_stack.add_named(self.preview_image, "image")
        
        text_scroll = Gtk.ScrolledWindow()
        text_scroll.add(self.preview_text)
        self.preview_stack.add_named(text_scroll, "text")
        
        self.preview_box.pack_start(self.preview_stack, True, True, 0)
        self.paned.pack2(self.preview_eb, False, False)

        self.listbox.connect("row-activated", self.on_open)
        self.listbox.connect("selected-rows-changed", self.on_select)
        self.listbox.connect("button-press-event", self.on_button_press)
        self.connect("key-press-event", self.on_key)

        self.apply_theme()
        self.setup_sidebar()
        self.refresh()

    def apply_theme(self):
        if not self.c: return
        bg, fg, acc = self.c["bg"], self.c["fg"], self.c["acc"]
        
        rgba_bg = Gdk.RGBA()
        rgba_bg.parse(bg)
        rgba_fg = Gdk.RGBA()
        rgba_fg.parse(fg)
        
        for w in [self, self.main_layout, self.side_strip, self.paned, 
                  self.list_scroll, self.listbox, self.preview_eb, 
                  self.preview_box, self.preview_text]:
            w.override_background_color(Gtk.StateFlags.NORMAL, rgba_bg)
            w.override_color(Gtk.StateFlags.NORMAL, rgba_fg)

        css = f"""
        row {{ background-color: transparent; color: {fg}; }}
        row:selected {{ background-color: {acc}; color: {bg}; border-radius: 4px; }}
        menu {{ background-color: {bg}; color: {fg}; border: 1px solid {fg}; border-radius: 8px; padding: 5px; }}
        menuitem {{ padding: 8px 12px; border-radius: 4px; }}
        menuitem:hover {{ background-color: {acc}; color: {bg}; }}
        separator {{ background-color: {fg}; opacity: 0.2; margin: 4px 0; }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, 800)

    def setup_sidebar(self):
        places = [
            ("user-home-symbolic", Path.home()), 
            ("folder-download-symbolic", Path.home()/"Downloads"), 
            ("folder-pictures-symbolic", Path.home()/"Pictures"), 
            ("user-trash-symbolic", "trash:///")
        ]
        for icon, path in places:
            eb = Gtk.EventBox() # Wrap in EventBox to catch right-clicks on the icon
            btn = Gtk.Button.new_from_icon_name(icon, Gtk.IconSize.DND)
            btn.set_relief(Gtk.ReliefStyle.NONE)
            btn.connect("clicked", lambda _, p=path: self.nav_to(p))
            eb.add(btn)
            
            if icon == "user-trash-symbolic":
                eb.connect("button-press-event", self.on_trash_icon_click)
                self.side_strip.pack_end(eb, False, False, 20)
            else:
                self.side_strip.pack_start(eb, False, False, 10)

    def on_trash_icon_click(self, widget, event):
        if event.button == 3: # Right Click
            menu = Gtk.Menu()
            m_empty = Gtk.MenuItem(label="Empty Trash")
            m_empty.connect("activate", lambda _: self.empty_trash())
            menu.append(m_empty)
            menu.show_all()
            menu.popup_at_pointer(event)
            return True
        return False

    def empty_trash(self):
        subprocess.run(["gio", "trash", "--empty"])
        self.refresh()

    def nav_to(self, path):
        self.cwd = "trash:///" if str(path).startswith("trash") else Path(path)
        self.refresh()

    def refresh(self):
        for r in self.listbox.get_children(): self.listbox.remove(r)
        try:
            if str(self.cwd).startswith("trash"):
                trash = Gio.File.new_for_uri("trash:///")
                en = trash.enumerate_children("standard::*", 0, None)
                for info in en: self.add_row(info.get_name(), f"trash:///{info.get_name()}")
            else:
                items = sorted(self.cwd.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower()))
                if self.cwd != self.cwd.parent: self.add_row("..", self.cwd.parent)
                for item in items: self.add_row(item.name, item)
        except: pass
        self.show_all()

    def add_row(self, name, path):
        row = Gtk.ListBoxRow()
        row.path = path
        box = Gtk.Box(spacing=15, margin=10)
        is_dir = Path(path).is_dir() if not str(path).startswith("trash") else False
        icon = "folder-symbolic" if is_dir else "text-x-generic-symbolic"
        if name == "..": icon = "go-up-symbolic"
        img = Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.MENU)
        lbl = Gtk.Label(label=name, xalign=0)
        box.pack_start(img, False, False, 0)
        box.pack_start(lbl, True, True, 0)
        row.add(box)
        self.listbox.add(row)

    def on_select(self, lb):
        rows = lb.get_selected_rows()
        if not rows: return
        p = rows[0].path
        if str(p).startswith("trash"): 
            self.preview_text.get_buffer().set_text("\n  Trash Item\n  Cannot preview.")
            self.preview_stack.set_visible_child_name("text")
            return
        if Path(p).suffix.lower() in (".png", ".jpg", ".jpeg"):
            pix = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(p), 400, 500, True)
            self.preview_image.set_from_pixbuf(pix)
            self.preview_stack.set_visible_child_name("image")
        else:
            try:
                with open(p, 'r', errors='ignore') as f:
                    self.preview_text.get_buffer().set_text(f.read(1500))
                self.preview_stack.set_visible_child_name("text")
            except: pass

    def on_button_press(self, widget, event):
        row = self.listbox.get_row_at_y(event.y)
        if event.button == 3: # Right Click
            if row: self.listbox.select_row(row)
            else: self.listbox.unselect_all()
            self.show_context_menu(event, row)
            return True
        elif not row:
            self.listbox.unselect_all()
        return False

    def show_context_menu(self, event, row):
        menu = Gtk.Menu()
        is_trash_folder = str(self.cwd).startswith("trash")
        
        if row:
            paths = [r.path for r in self.listbox.get_selected_rows()]
            m_open = Gtk.MenuItem(label="Open")
            m_open.connect("activate", lambda _: self.on_open(None, row))
            menu.append(m_open)
            
            if not is_trash_folder:
                menu.append(Gtk.SeparatorMenuItem())
                m_copy = Gtk.MenuItem(label="Copy")
                m_copy.connect("activate", lambda _: self.set_clipboard(paths, "copy"))
                menu.append(m_copy)
                m_cut = Gtk.MenuItem(label="Cut")
                m_cut.connect("activate", lambda _: self.set_clipboard(paths, "cut"))
                menu.append(m_cut)
                m_trash = Gtk.MenuItem(label="Move to Trash")
                m_trash.connect("activate", lambda _: [self.move_to_trash(p) for p in paths])
                menu.append(m_trash)
        else:
            if is_trash_folder:
                m_empty = Gtk.MenuItem(label="Empty Trash")
                m_empty.connect("activate", lambda _: self.empty_trash())
                menu.append(m_empty)
            else:
                m_fold = Gtk.MenuItem(label="New Folder")
                m_fold.connect("activate", lambda _: self.create_item("dir"))
                menu.append(m_fold)
                m_file = Gtk.MenuItem(label="New File")
                m_file.connect("activate", lambda _: self.create_item("file"))
                menu.append(m_file)
                menu.append(Gtk.SeparatorMenuItem())
                m_paste = Gtk.MenuItem(label=f"Paste ({len(self.clipboard_files)} items)")
                m_paste.set_sensitive(len(self.clipboard_files) > 0)
                m_paste.connect("activate", lambda _: self.paste_files())
                menu.append(m_paste)

        menu.show_all()
        menu.popup_at_pointer(event)

    def create_item(self, type):
        name = "new_folder" if type == "dir" else "new_file.txt"
        target = Path(self.cwd) / name
        try:
            if type == "dir": target.mkdir(exist_ok=True)
            else: target.touch()
            self.refresh()
        except: pass

    def set_clipboard(self, paths, mode):
        self.clipboard_files = paths
        self.clipboard_mode = mode

    def paste_files(self):
        for src in self.clipboard_files:
            try:
                src_path = Path(src)
                dst_path = Path(self.cwd) / src_path.name
                if self.clipboard_mode == "copy":
                    if src_path.is_dir(): shutil.copytree(src_path, dst_path)
                    else: shutil.copy2(src_path, dst_path)
                else: shutil.move(str(src_path), str(dst_path))
            except: pass
        if self.clipboard_mode == "cut": self.clipboard_files = []
        self.refresh()

    def move_to_trash(self, path):
        try: subprocess.run(["gio", "trash", str(path)])
        except: pass
        self.refresh()

    def on_open(self, _, row):
        if str(row.path).startswith("trash"): return
        if Path(row.path).is_dir(): self.nav_to(row.path)
        else: subprocess.Popen(["xdg-open", str(row.path)])

    def on_key(self, _, event):
        key = Gdk.keyval_name(event.keyval)
        ctrl = event.state & Gdk.ModifierType.CONTROL_MASK
        selected = self.listbox.get_selected_rows()
        if key == "BackSpace": self.nav_to(self.cwd.parent)
        elif ctrl and key == "c" and selected: self.set_clipboard([r.path for r in selected], "copy")
        elif ctrl and key == "x" and selected: self.set_clipboard([r.path for r in selected], "cut")
        elif ctrl and key == "v": self.paste_files()
        elif key == "Delete" and selected: [self.move_to_trash(r.path) for r in selected]

if __name__ == "__main__":
    win = HorizonFM()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()