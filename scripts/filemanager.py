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
        self.set_default_size(1100, 700)
        self.cwd = Path.home()
        self.c = get_wal()
        
        self.clipboard_files = []
        self.clipboard_mode = None 

        # Enable transparency support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.main_layout = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.add(self.main_layout)

        # Sidebar
        self.side_strip = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        self.side_strip.set_size_request(60, -1)
        self.main_layout.pack_start(self.side_strip, False, False, 0)

        # Paned
        self.paned = Gtk.Paned.new(Gtk.Orientation.HORIZONTAL)
        self.main_layout.pack_start(self.paned, True, True, 0)

        # List Area
        self.list_scroll = Gtk.ScrolledWindow()
        self.listbox = Gtk.ListBox()
        # RE-ENABLED MULTIPLE SELECTION
        self.listbox.set_selection_mode(Gtk.SelectionMode.MULTIPLE)
        self.list_scroll.add(self.listbox)
        self.paned.pack1(self.list_scroll, True, False)

        # Preview Area
        self.preview_eb = Gtk.EventBox()
        self.preview_eb.set_name("preview_pane")
        self.preview_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.preview_box.set_size_request(280, -1) 
        self.preview_eb.add(self.preview_box)
        
        self.preview_image = Gtk.Image()
        self.preview_text = Gtk.TextView(editable=False, cursor_visible=False, left_margin=15, top_margin=15)
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

    def hex_to_rgba(self, hex_val, alpha):
        h = hex_val.lstrip('#')
        rgb = tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
        return f"rgba({rgb[0]},{rgb[1]},{rgb[2]},{alpha})"

    def apply_theme(self):
        if not self.c: return
        bg, fg, acc = self.c["bg"], self.c["fg"], self.c["acc"]
        bg_alpha = self.hex_to_rgba(bg, 0.6)
        
        css = f"""
        window, box, scrolledwindow, list, textview, viewport {{ 
            background-color: {bg}; 
            color: {fg}; 
            border: none;
        }}
        row {{ 
            background-color: transparent; 
            color: {fg};
        }}
        row:selected {{ 
            background-color: {acc}; 
            color: {bg}; 
        }}
        #preview_pane, #preview_pane textview, #preview_pane textview text {{ 
            background-color: {bg_alpha}; 
        }}
        paned > separator {{ 
            background-color: {fg}; 
            min-width: 1px; 
            opacity: 0.1; 
        }}
        menu {{ 
            background-color: {bg}; 
            border: 1px solid {fg}; 
            border-radius: 6px; 
        }}
        menuitem {{ color: {fg}; padding: 4px 10px; }}
        menuitem:hover {{ background-color: {acc}; color: {bg}; }}
        """
        
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, 800)

    def setup_sidebar(self):
        places = [("user-home-symbolic", Path.home()), ("folder-download-symbolic", Path.home()/"Downloads"), ("user-trash-symbolic", "trash:///")]
        for icon, path in places:
            eb = Gtk.EventBox()
            btn = Gtk.Button.new_from_icon_name(icon, Gtk.IconSize.DND)
            btn.set_relief(Gtk.ReliefStyle.NONE)
            btn.connect("clicked", lambda _, p=path: self.nav_to(p))
            eb.add(btn)
            if icon == "user-trash-symbolic":
                eb.connect("button-press-event", self.on_trash_icon_click)
                self.side_strip.pack_end(eb, False, False, 20)
            else: self.side_strip.pack_start(eb, False, False, 10)

    def on_trash_icon_click(self, widget, event):
        if event.button == 3:
            menu = Gtk.Menu()
            m_empty = Gtk.MenuItem(label="Empty Trash")
            m_empty.connect("activate", lambda _: subprocess.run(["gio", "trash", "--empty"]))
            menu.append(m_empty)
            menu.show_all()
            menu.popup_at_pointer(event)
            return True
        return False

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
        box = Gtk.Box(spacing=15, margin=8)
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
        selected = lb.get_selected_rows()
        if not selected: return
        p = selected[0].path
        if str(p).startswith("trash"): return
        if Path(p).suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
            try:
                pix = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(p), 260, 400, True)
                self.preview_image.set_from_pixbuf(pix)
                self.preview_stack.set_visible_child_name("image")
            except: pass
        else:
            try:
                with open(p, 'r', errors='ignore') as f:
                    self.preview_text.get_buffer().set_text(f.read(1500))
                self.preview_stack.set_visible_child_name("text")
            except: pass

    def on_button_press(self, widget, event):
        row = self.listbox.get_row_at_y(event.y)
        if event.button == 3: # Right Click
            if row and row not in self.listbox.get_selected_rows():
                self.listbox.unselect_all()
                self.listbox.select_row(row)
            self.show_context_menu(event)
            return True
        elif not row:
            self.listbox.unselect_all()
        return False

    def show_context_menu(self, event):
        menu = Gtk.Menu()
        selected_rows = self.listbox.get_selected_rows()
        
        if selected_rows:
            paths = [r.path for r in selected_rows]
            m_open = Gtk.MenuItem(label=f"Open ({len(paths)})" if len(paths) > 1 else "Open")
            m_open.connect("activate", lambda _: [self.on_open(None, r) for r in selected_rows])
            menu.append(m_open)
            
            m_copy = Gtk.MenuItem(label="Copy")
            m_copy.connect("activate", lambda _: self.set_clipboard(paths, "copy"))
            menu.append(m_copy)

            m_cut = Gtk.MenuItem(label="Cut")
            m_cut.connect("activate", lambda _: self.set_clipboard(paths, "cut"))
            menu.append(m_cut)
            
            m_trash = Gtk.MenuItem(label="Move to Trash")
            m_trash.connect("activate", lambda _: [subprocess.run(["gio", "trash", str(p)]) for p in paths])
            menu.append(m_trash)
        
        m_paste = Gtk.MenuItem(label=f"Paste ({len(self.clipboard_files)} items)")
        m_paste.set_sensitive(len(self.clipboard_files) > 0)
        m_paste.connect("activate", lambda _: self.paste_files())
        menu.append(m_paste)

        menu.show_all()
        menu.popup_at_pointer(event)

    def set_clipboard(self, paths, mode):
        self.clipboard_files = paths
        self.clipboard_mode = mode

    def paste_files(self):
        for src in self.clipboard_files:
            try:
                src_p, dst_p = Path(src), Path(self.cwd) / Path(src).name
                if self.clipboard_mode == "copy":
                    if src_p.is_dir(): shutil.copytree(src_p, dst_p)
                    else: shutil.copy2(src_p, dst_p)
                else: shutil.move(str(src_p), str(dst_p))
            except: pass
        if self.clipboard_mode == "cut": self.clipboard_files = []
        self.refresh()

    def on_open(self, _, row):
        if str(row.path).startswith("trash"): return
        if Path(row.path).is_dir(): self.nav_to(row.path)
        else: subprocess.Popen(["xdg-open", str(row.path)])

    def on_key(self, _, event):
        key = Gdk.keyval_name(event.keyval)
        ctrl = event.state & Gdk.ModifierType.CONTROL_MASK
        sel = self.listbox.get_selected_rows()
        if key == "BackSpace": self.nav_to(self.cwd.parent)
        elif ctrl and key == "c" and sel: self.set_clipboard([r.path for r in sel], "copy")
        elif ctrl and key == "x" and sel: self.set_clipboard([r.path for r in sel], "cut")
        elif ctrl and key == "v": self.paste_files()
        elif key == "Delete" and sel: 
            for r in sel: subprocess.run(["gio", "trash", str(r.path)])
            self.refresh()

if __name__ == "__main__":
    win = HorizonFM()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
