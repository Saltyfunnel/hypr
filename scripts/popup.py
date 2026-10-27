#!/usr/bin/env python3
import gi, json, os, signal, threading, urllib.request
from datetime import datetime

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell

LOC = "Lhanbryde"
PIDFILE = f"/tmp/bar-popup-{os.getuid()}.pid"
TOP_MARGIN = 44  # bar height + gap

# Toggle: if already open, close it and exit
if os.path.exists(PIDFILE):
    try:
        os.kill(int(open(PIDFILE).read()), signal.SIGTERM)
        os.remove(PIDFILE)
        raise SystemExit
    except (ProcessLookupError, ValueError, FileNotFoundError):
        pass
open(PIDFILE, "w").write(str(os.getpid()))

# Colours: pywal if available, else Catppuccin Mocha
C = dict(bg="#181825", fg="#cdd6f4", accent="#cba6f7", dim="#6c7086",
         hot="#f38ba8", cold="#89b4fa", rain="#74c7ec")
try:
    w = json.load(open(os.path.expanduser("~/.cache/wal/colors.json")))
    C.update(bg=w["special"]["background"], fg=w["special"]["foreground"],
             accent=w["colors"]["color4"], dim=w["colors"]["color8"])
except Exception:
    pass

ICONS = {
    (113,): "󰖙", (116,): "󰖕", (119, 122): "󰖐", (143, 248, 260): "󰖑",
    (200, 386, 389): "󰖓",
    (176, 263, 266, 293, 296, 311, 314, 353): "󰖗",
    (299, 302, 305, 308, 356, 359): "󰖖",
    (179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 395): "󰼶",
}
def icon(code):
    code = int(code)
    return next((v for k, v in ICONS.items() if code in k), "󰖐")

CSS = f"""
window {{ background: alpha({C['bg']}, 0.95); border: 2px solid {C['accent']};
         border-radius: 16px; }}
label {{ color: {C['fg']}; font-family: "JetBrainsMono Nerd Font", monospace; }}
.date {{ font-size: 18px; font-weight: bold; color: {C['accent']}; }}
.big {{ font-size: 28px; font-weight: bold; }}
.dim {{ color: {C['dim']}; }}
.hot {{ color: {C['hot']}; }} .cold {{ color: {C['cold']}; }} .rain {{ color: {C['rain']}; }}
calendar {{ background: transparent; color: {C['fg']}; border: none; padding: 4px; }}
calendar.header {{ color: {C['accent']}; border: none; background: transparent; }}
calendar.button {{ color: {C['accent']}; background: transparent; border: none; }}
calendar:selected {{ background: {C['accent']}; color: {C['bg']}; border-radius: 8px; }}
calendar:indeterminate {{ color: {C['dim']}; }}
separator {{ background: {C['dim']}; min-height: 1px; }}
"""

def lbl(text="", cls=None, markup=False, xalign=0.5):
    l = Gtk.Label(xalign=xalign)
    l.set_markup(text) if markup else l.set_text(text)
    if cls:
        for c in cls.split():
            l.get_style_context().add_class(c)
    return l

class Popup(Gtk.Window):
    def __init__(self):
        super().__init__()
        scr = self.get_screen()
        if scr.get_rgba_visual():
            self.set_visual(scr.get_rgba_visual())
        self.set_app_paintable(True)

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "bar-popup")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, TOP_MARGIN)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_border_width(18)
        self.add(box)

        now = datetime.now()
        box.pack_start(lbl(now.strftime("%A, %d %B"), "date"), False, False, 0)
        cal = Gtk.Calendar()
        cal.set_property("show-week-numbers", False)
        box.pack_start(cal, False, False, 0)
        box.pack_start(Gtk.Separator(), False, False, 4)

        self.wbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.wbox.pack_start(lbl("Loading weather…", "dim"), False, False, 0)
        box.pack_start(self.wbox, False, False, 0)

        self.connect("key-press-event", lambda w, e: e.keyval == Gdk.KEY_Escape and self.quit())
        self.connect("focus-out-event", lambda *a: self.quit())
        self.connect("destroy", lambda *a: self.quit())
        threading.Thread(target=self.fetch, daemon=True).start()

    def fetch(self):
        try:
            url = f"https://wttr.in/{LOC}?format=j1"
            data = json.load(urllib.request.urlopen(url, timeout=6))
            GLib.idle_add(self.show_weather, data)
        except Exception:
            GLib.idle_add(self.show_weather, None)

    def show_weather(self, d):
        for ch in self.wbox.get_children():
            self.wbox.remove(ch)
        if not d:
            self.wbox.pack_start(lbl("Weather unavailable", "dim"), False, False, 0)
        else:
            cur = d["current_condition"][0]
            head = Gtk.Box(spacing=12, halign=Gtk.Align.CENTER)
            head.pack_start(lbl(f"{icon(cur['weatherCode'])}  {cur['temp_C']}°C", "big"), False, False, 0)
            col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            col.pack_start(lbl(cur["weatherDesc"][0]["value"], xalign=0), False, False, 0)
            col.pack_start(lbl(f"Feels like {cur['FeelsLikeC']}°C", "dim", xalign=0), False, False, 0)
            head.pack_start(col, False, False, 0)
            self.wbox.pack_start(head, False, False, 0)

            stats = (f"󰖎 {cur['humidity']}%    󰖝 {cur['windspeedKmph']} km/h {cur['winddir16Point']}"
                     f"    󰖨 UV {cur['uvIndex']}")
            self.wbox.pack_start(lbl(stats, "dim"), False, False, 4)

            for i, day in enumerate(d["weather"][:3]):
                name = "Today" if i == 0 else datetime.strptime(day["date"], "%Y-%m-%d").strftime("%a")
                rain = max(int(h["chanceofrain"]) for h in day["hourly"])
                code = day["hourly"][4]["weatherCode"]
                row = (f"<b>{name:<6}</b> {icon(code)}  "
                       f"<span foreground='{C['hot']}'>{day['maxtempC']}°</span> / "
                       f"<span foreground='{C['cold']}'>{day['mintempC']}°</span>   "
                       f"<span foreground='{C['rain']}'>󰖗 {rain}%</span>")
                self.wbox.pack_start(lbl(row, markup=True, xalign=0), False, False, 0)
        self.wbox.show_all()
        return False

    def quit(self):
        try:
            os.remove(PIDFILE)
        except FileNotFoundError:
            pass
        Gtk.main_quit()

prov = Gtk.CssProvider()
prov.load_from_data(CSS.encode())
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov,
                                         Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
win = Popup()
win.show_all()
Gtk.main()
