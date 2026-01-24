#!/usr/bin/env python3
import gi
import json
import subprocess
import shutil
import threading
import os
from pathlib import Path

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GdkPixbuf, Gio, GLib

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
        self.set_default_size(1100, 750)
        self.cwd = Path.home()
        self.c = get_wal()
        self.clipboard_files = []
        self.clipboard_mode = None

        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual: self.set_visual(visual)

        self.outer_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(self.outer_vbox)

        self.main_layout = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.outer_vbox.pack_start(self.main_layout, True, True, 0)

        # Sidebar
        self.side_strip = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        self.side_strip.set_size_request(60, -1)
        self.main_layout.pack_start(self.side_strip, False, False, 0)

        self.static_sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.drive_sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.side_strip.pack_start(self.static_sidebar, False, False, 10)
        self.side_strip.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 5)
        self.side_strip.pack_start(self.drive_sidebar, False, False, 0)

        # Paned & List
        self.paned = Gtk.Paned.new(Gtk.Orientation.HORIZONTAL)
        self.main_layout.pack_start(self.paned, True, True, 0)

        self.list_scroll = Gtk.ScrolledWindow()
        self.listbox = Gtk.ListBox()
        self.listbox.set_selection_mode(Gtk.SelectionMode.MULTIPLE)
        self.list_scroll.add(self.listbox)
        self.paned.pack1(self.list_scroll, True, False)

        # --- PREVIEW PANEL ---
        self.preview_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.preview_box.set_size_request(280, -1)

        # Thumbnail with hover animation
        self.preview_icon_event = Gtk.EventBox()
        self.preview_icon = Gtk.Image()
        self.preview_icon_event.add(self.preview_icon)
        self.preview_icon_event.set_above_child(True)
        self.preview_icon_event.connect("enter-notify-event", self.on_preview_hover)
        self.preview_icon_event.connect("leave-notify-event", self.on_preview_leave)
        self.preview_box.pack_start(self.preview_icon_event, False, False, 0)

        # File/folder name
        self.preview_name = Gtk.Label(label="", xalign=0)
        self.preview_box.pack_start(self.preview_name, False, False, 0)

        # Info text
        self.preview_info = Gtk.Label(label="", xalign=0)
        self.preview_info.set_line_wrap(True)
        self.preview_box.pack_start(self.preview_info, False, False, 0)

        self.preview_stack = Gtk.Stack()
        self.preview_stack.add_named(self.preview_box, "info")
        self.paned.pack2(self.preview_stack, False, False)

        # Status Bar
        self.status_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10, margin=5)
        self.status_label = Gtk.Label(label="", xalign=0)
        self.progress_bar = Gtk.ProgressBar()
        self.progress_bar.set_hexpand(True)
        self.status_bar.pack_start(self.status_label, False, False, 5)
        self.status_bar.pack_start(self.progress_bar, True, True, 5)
        self.outer_vbox.pack_end(self.status_bar, False, False, 0)
        self.status_bar.hide()

        # Volume Monitor
        self.monitor = Gio.VolumeMonitor.get()
        self.monitor.connect("mount-added", lambda *_: self.update_drives())
        self.monitor.connect("mount-removed", lambda *_: self.update_drives())

        self.listbox.connect("row-activated", self.on_open)
        self.listbox.connect("selected-rows-changed", self.on_select)
        self.listbox.connect("button-press-event", self.on_button_press)
        self.connect("key-press-event", self.on_key)

        # Apply theme & setup UI
        self.apply_theme()
        self.setup_static_sidebar()
        self.update_drives()
        self.refresh()

        # Animation state
        self._hover_scale = 1.0
        self._hover_anim = None

    # --- THUMBNAIL HOVER ANIMATION ---
    def on_preview_hover(self, widget, event):
        self.animate_hover(1.1)
        return False

    def on_preview_leave(self, widget, event):
        self.animate_hover(1.0)
        return False

    def animate_hover(self, target_scale):
        if self._hover_anim:
            GLib.source_remove(self._hover_anim)
        start_scale = self._hover_scale
        steps = 5
        duration = 100
        delta = (target_scale - start_scale) / steps
        interval = duration // steps

        def step(count=0):
            nonlocal start_scale
            if count >= steps:
                self._hover_scale = target_scale
                self.preview_icon.set_size_request(int(200 * self._hover_scale), int(200 * self._hover_scale))
                return False
            self._hover_scale += delta
            self.preview_icon.set_size_request(int(200 * self._hover_scale), int(200 * self._hover_scale))
            return True

        self._hover_anim = GLib.timeout_add(interval, lambda c=0: step(c) and step(c+1))

    # --- THEMING ---
    def apply_theme(self):
        if not self.c: return
        bg, fg, acc = self.c["bg"], self.c["fg"], self.c["acc"]
        bg_alpha = self.hex_to_rgba(bg, 0.6)
        css = f"""
        window, box, scrolledwindow, list, textview, viewport {{ background-color: {bg}; color: {fg}; border: none; }}
        row {{ background-color: transparent; color: {fg}; }}
        row:selected {{ background-color: {acc}; color: {bg}; }}
        progressbar trough {{ background-color: rgba(255,255,255,0.1); border-radius: 4px; border: none; min-height: 8px; }}
        progressbar progress {{ background-color: {acc}; border-radius: 4px; border: none; }}
        separator {{ background-color: {fg}; opacity: 0.1; }}
        menu {{ background-color: {bg}; border: 1px solid {fg}; border-radius: 6px; }}
        menuitem {{ color: {fg}; padding: 4px 10px; }}
        menuitem:hover {{ background-color: {acc}; color: {bg}; }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, 800)

    def hex_to_rgba(self, hex_val, alpha):
        h = hex_val.lstrip('#')
        rgb = tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
        return f"rgba({rgb[0]},{rgb[1]},{rgb[2]},{alpha})"

    # --- STATIC SIDEBAR ---
    def setup_static_sidebar(self):
        places = [("user-home-symbolic", Path.home()), ("folder-download-symbolic", Path.home()/"Downloads")]
        for icon_name, path in places:
            btn = Gtk.Button.new_from_icon_name(icon_name, Gtk.IconSize.DND)
            btn.set_relief(Gtk.ReliefStyle.NONE)
            btn.connect("clicked", lambda _, p=path: self.nav_to(p))
            self.static_sidebar.pack_start(btn, False, False, 0)
        
        trash_eb = Gtk.EventBox()
        trash_btn = Gtk.Button.new_from_icon_name("user-trash-symbolic", Gtk.IconSize.DND)
        trash_btn.set_relief(Gtk.ReliefStyle.NONE)
        trash_btn.set_can_focus(False)
        trash_btn.connect("clicked", lambda _: self.nav_to("trash:///"))
        trash_eb.add(trash_btn)
        trash_eb.connect("button-press-event", self.on_trash_right_click)
        self.side_strip.pack_end(trash_eb, False, False, 20)

    def on_trash_right_click(self, widget, event):
        if event.button == 3:
            menu = Gtk.Menu()
            item = Gtk.MenuItem(label="Empty Trash")
            item.connect("activate", lambda _: [subprocess.run(["gio", "trash", "--empty"]), self.refresh()])
            menu.append(item)
            menu.show_all()
            menu.popup_at_pointer(event)
            return True
        return False

    # --- DRIVE UPDATE ---
    def update_drives(self):
        for child in self.drive_sidebar.get_children(): self.drive_sidebar.remove(child)
        mounts = self.monitor.get_mounts()
        for m in mounts:
            root = m.get_root().get_path()
            if root:
                g_icon = m.get_icon()
                eb = Gtk.EventBox()
                img = Gtk.Image.new_from_gicon(g_icon, Gtk.IconSize.DND)
                btn = Gtk.Button()
                btn.add(img)
                btn.set_relief(Gtk.ReliefStyle.NONE)
                btn.set_tooltip_text(m.get_name())
                btn.connect("clicked", lambda _, p=root: self.nav_to(p))
                eb.add(btn)
                eb.connect("button-press-event", lambda w, e, mount=m: self.on_drive_right_click(w, e, mount))
                self.drive_sidebar.pack_start(eb, False, False, 0)
        self.drive_sidebar.show_all()

    def on_drive_right_click(self, widget, event, mount):
        if event.button == 3:
            menu = Gtk.Menu()
            item = Gtk.MenuItem(label=f"Eject {mount.get_name()}")
            item.connect("activate", lambda _: mount.eject_with_operation(Gio.MountUnmountFlags.NONE, None, None, None, None))
            menu.append(item)
            menu.show_all()
            menu.popup_at_pointer(event)
            return True
        return False

    # --- NAVIGATION & REFRESH ---
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
        self.preview_name.set_text(Path(p).name if not str(p).startswith("trash") else str(p))
        if str(p).startswith("trash") or Path(p).is_dir():
            self.preview_icon.set_from_icon_name("folder-symbolic", Gtk.IconSize.DND)
            self.preview_info.set_text("")
            return

        if Path(p).suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
            try:
                pix = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(p), 200, 200, True)
                self.preview_icon.set_from_pixbuf(pix)
                self.preview_info.set_text(f"{os.path.getsize(p)} bytes")
            except: pass
        else:
            self.preview_icon.set_from_icon_name("text-x-generic-symbolic", Gtk.IconSize.DND)
            try:
                with open(p, 'r', errors='ignore') as f:
                    self.preview_info.set_text(f.read(300))
            except: pass

    # --- FILE OPERATIONS ---
    def update_progress(self, current, total, name):
        percent = current / total if total > 0 else 0
        GLib.idle_add(self.progress_bar.set_fraction, percent)
        GLib.idle_add(self.status_label.set_text, f"Processing {name}...")

    def file_op_worker(self, sources, destination, mode):
        GLib.idle_add(self.status_bar.show)
        for src in sources:
            src_path = Path(src)
            if mode == "trash":
                subprocess.run(["gio", "trash", str(src_path)])
            else:
                dest_path = Path(destination) / src_path.name
                if mode == "copy":
                    if src_path.is_dir(): shutil.copytree(src_path, dest_path)
                    else:
                        total_size = os.path.getsize(src)
                        copied = 0
                        with open(src, 'rb') as fsrc, open(dest_path, 'wb') as fdst:
                            while True:
                                buf = fsrc.read(1024*1024)
                                if not buf: break
                                fdst.write(buf)
                                copied += len(buf)
                                self.update_progress(copied, total_size, src_path.name)
                elif mode == "cut":
                    shutil.move(str(src_path), str(dest_path))
        GLib.idle_add(self.status_bar.hide)
        GLib.idle_add(self.refresh)

    def start_op(self, sources, mode):
        thread = threading.Thread(target=self.file_op_worker, args=(sources, self.cwd, mode))
        thread.daemon = True
        thread.start()

    def on_button_press(self, widget, event):
        row = self.listbox.get_row_at_y(event.y)
        if event.button == 3:
            if row and row not in self.listbox.get_selected_rows():
                self.listbox.unselect_all()
                self.listbox.select_row(row)
            self.show_context_menu(event)
            return True
        elif not row: self.listbox.unselect_all()
        return False

    def show_context_menu(self, event):
        menu = Gtk.Menu()
        sel = self.listbox.get_selected_rows()
        if sel:
            paths = [r.path for r in sel]
            m_copy = Gtk.MenuItem(label="Copy")
            m_copy.connect("activate", lambda _: self.set_clipboard(paths, "copy"))
            menu.append(m_copy)
            m_cut = Gtk.MenuItem(label="Cut")
            m_cut.connect("activate", lambda _: self.set_clipboard(paths, "cut"))
            menu.append(m_cut)
            m_trash = Gtk.MenuItem(label="Move to Trash")
            m_trash.connect("activate", lambda _: self.start_op(paths, "trash"))
            menu.append(m_trash)
        m_paste = Gtk.MenuItem(label="Paste")
        m_paste.set_sensitive(len(self.clipboard_files) > 0)
        m_paste.connect("activate", lambda _: self.start_op(self.clipboard_files, self.clipboard_mode))
        menu.append(m_paste)
        menu.show_all()
        menu.popup_at_pointer(event)

    def set_clipboard(self, paths, mode):
        self.clipboard_files, self.clipboard_mode = paths, mode

    def on_open(self, _, row):
        if str(row.path).startswith("trash"): return
        if Path(row.path).is_dir(): self.nav_to(row.path)
        else: subprocess.Popen(["xdg-open", str(row.path)])

    def on_key(self, _, event):
        key = Gdk.keyval_name(event.keyval)
        sel = self.listbox.get_selected_rows()
        if key == "BackSpace": self.nav_to(self.cwd.parent)
        elif key == "Delete" and sel:
            self.start_op([r.path for r in sel], "trash")

if __name__ == "__main__":
    win = HorizonFM()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
