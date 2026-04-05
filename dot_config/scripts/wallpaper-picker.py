#!/usr/bin/env python3
"""
Wallpaper Picker — Galería visual estilo carousel
GTK4 + Libadwaita · Integrado con hyprpaper + extracción de colores
"""

import gi, os, subprocess, glob, threading

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("GdkPixbuf", "2.0")

from gi.repository import Gtk, Adw, GdkPixbuf, Gdk, GLib, Gio

WALL_DIR = os.path.expanduser("~/Pictures/wallpapers")
EXTENSIONS = ("*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp")
THUMB_W, THUMB_H = 460, 300
EXTRACT_SCRIPT = os.path.expanduser("~/.config/scripts/extract-colors.py")
HYPRPAPER_CONF = os.path.expanduser("~/.config/hypr/hyprpaper.conf")
PALETTE_CACHE = os.path.expanduser("~/.cache/qs-palette")

CSS = """
window.background, .main-box {
    background-color: rgba(17, 17, 27, 0.92);
}

/* ── Toolbar pill ── */
.toolbar-pill {
    background-color: rgba(30, 30, 46, 0.90);
    border-radius: 22px;
    padding: 6px 16px;
    border: 1px solid rgba(255, 255, 255, 0.06);
}

/* ── Color dots ── */
.cdot {
    min-width: 24px; min-height: 24px;
    border-radius: 50%;
    padding: 0;
    margin: 0 1px;
    border: none;
}

/* ── Wallpaper card ── */
.wall-card {
    border-radius: 16px;
    background-color: rgba(30, 30, 46, 0.55);
    margin: 10px;
    padding: 0;
    transition: all 200ms ease;
    border: 2px solid transparent;
}
.wall-card:hover {
    background-color: rgba(49, 50, 68, 0.75);
    border: 2px solid rgba(137, 180, 250, 0.35);
}

.wall-card-img {
    border-radius: 14px;
}

/* ── Toolbar buttons ── */
.tb-btn {
    color: rgba(205, 214, 244, 0.75);
    min-width: 30px; min-height: 30px;
    padding: 0;
}
.tb-btn:hover { color: #89b4fa; }

/* ── Search ── */
.wp-search {
    background-color: rgba(49, 50, 68, 0.6);
    color: #cdd6f4;
    border-radius: 14px;
    border: 1px solid rgba(255, 255, 255, 0.05);
    min-height: 30px;
    padding: 0 12px;
}

.wall-label {
    color: rgba(205, 214, 244, 0.55);
    font-size: 10px;
    font-weight: 500;
}

/* ── scrollbar ── */
scrollbar slider {
    background-color: rgba(137, 180, 250, 0.25);
    border-radius: 10px;
    min-width: 6px;
}
scrollbar slider:hover {
    background-color: rgba(137, 180, 250, 0.45);
}
"""


class WallpaperPicker(Adw.Application):
    def __init__(self):
        super().__init__(application_id="com.reaan.wallpicker",
                         flags=Gio.ApplicationFlags.NON_UNIQUE)
        self.connect("activate", self.on_activate)
        self.images = []
        self.filtered = []

    def scan_images(self):
        imgs = []
        for ext in EXTENSIONS:
            imgs.extend(glob.glob(os.path.join(WALL_DIR, ext)))
            imgs.extend(glob.glob(os.path.join(WALL_DIR, "**", ext), recursive=True))
        seen = set()
        unique = []
        for p in sorted(imgs):
            rp = os.path.realpath(p)
            if rp not in seen:
                seen.add(rp)
                unique.append(rp)
        return unique

    def apply_wallpaper(self, path):
        try:
            monitor = subprocess.check_output(
                ["sh", "-c", "hyprctl monitors -j | jq -r '.[0].name'"],
                text=True).strip()
            try:
                subprocess.check_output(["pgrep", "-x", "hyprpaper"])
            except subprocess.CalledProcessError:
                subprocess.Popen(["hyprpaper"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                import time; time.sleep(1)
            subprocess.run(["hyprctl", "hyprpaper", "unload", "all"], capture_output=True)
            subprocess.run(["hyprctl", "hyprpaper", "preload", path], capture_output=True)
            subprocess.run(["hyprctl", "hyprpaper", "wallpaper", f"{monitor},{path}"],
                           capture_output=True)
            with open(HYPRPAPER_CONF, "w") as f:
                f.write(f"preload = {path}\nwallpaper = ,{path}\nsplash = false\nipc = on\n")
            raw_file = "/tmp/qs-colors-raw"
            subprocess.run(
                ["sh", "-c",
                 f'magick "{path}" -resize 200x200! -colors 8 -unique-colors -depth 8 txt:- '
                 f'2>/dev/null | tail -n +2 | grep -oE "#[0-9A-Fa-f]{{6}}" | head -8 > {raw_file}'],
                capture_output=True)
            if os.path.isfile(EXTRACT_SCRIPT) and os.path.isfile(raw_file):
                subprocess.run(["python3", EXTRACT_SCRIPT, raw_file, PALETTE_CACHE],
                               capture_output=True)
                try: os.remove(raw_file)
                except: pass
            subprocess.run(["notify-send", "Wallpaper actualizado",
                            os.path.basename(path), "-i", path, "-t", "3000"],
                           capture_output=True)
        except Exception as e:
            print(f"Error: {e}")

    # ══════════════════════════════════════════════
    #  UI
    # ══════════════════════════════════════════════
    def on_activate(self, app):
        self.images = self.scan_images()
        self.filtered = list(self.images)

        self.win = Adw.ApplicationWindow(application=app)
        self.win.set_title("Wallpapers")
        self.win.set_default_size(1366, 768)
        self.win.set_resizable(True)

        # CSS
        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        # Color dot providers (one per color)
        self.dot_colors = [
            ("#e64553", "rojo"),  ("#fe640b", "naranja"), ("#df8e1d", "amarillo"),
            ("#40a02b", "verde"), ("#209fb5", "azul"),    ("#7c3aed", "morado"),
            ("#ea76cb", "rosa"),  ("#9ca0b0", "gris")
        ]
        for hx, nm in self.dot_colors:
            p = Gtk.CssProvider()
            p.load_from_string(f".cdot-{nm} {{ background-color: {hx}; }}")
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), p,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        # ── Main layout ──
        main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        main.add_css_class("main-box")

        # ── Toolbar (centered pill) ──
        tb_center = Gtk.Box(hexpand=True)
        tb_center.set_halign(Gtk.Align.CENTER)
        tb_center.set_margin_top(14)
        tb_center.set_margin_bottom(6)

        pill = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        pill.add_css_class("toolbar-pill")
        pill.set_valign(Gtk.Align.CENTER)

        # Grid icon
        grid_btn = Gtk.Button(icon_name="view-grid-symbolic")
        grid_btn.add_css_class("flat"); grid_btn.add_css_class("tb-btn")
        pill.append(grid_btn)

        # Play/shuffle icon
        shuffle_btn = Gtk.Button(icon_name="media-playlist-shuffle-symbolic")
        shuffle_btn.add_css_class("flat"); shuffle_btn.add_css_class("tb-btn")
        shuffle_btn.set_tooltip_text("Wallpaper aleatorio")
        shuffle_btn.connect("clicked", self.on_random)
        pill.append(shuffle_btn)

        # Separator
        s1 = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        s1.set_margin_start(2); s1.set_margin_end(2)
        pill.append(s1)

        # Color dots
        for hx, nm in self.dot_colors:
            d = Gtk.Button()
            d.add_css_class("flat"); d.add_css_class("cdot"); d.add_css_class(f"cdot-{nm}")
            d.set_tooltip_text(nm.capitalize())
            pill.append(d)

        # Separator
        s2 = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        s2.set_margin_start(2); s2.set_margin_end(2)
        pill.append(s2)

        # Search
        self.search = Gtk.SearchEntry()
        self.search.set_placeholder_text("Buscar...")
        self.search.add_css_class("wp-search")
        self.search.set_size_request(180, -1)
        self.search.connect("search-changed", self.on_search)
        pill.append(self.search)

        tb_center.append(pill)
        main.append(tb_center)

        # ── Gallery ──
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True); scroll.set_hexpand(True)
        scroll.set_kinetic_scrolling(True)

        self.flow = Gtk.FlowBox()
        self.flow.set_valign(Gtk.Align.START)
        self.flow.set_homogeneous(True)
        self.flow.set_max_children_per_line(4)
        self.flow.set_min_children_per_line(2)
        self.flow.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.flow.set_column_spacing(2)
        self.flow.set_row_spacing(2)
        self.flow.set_margin_start(24)
        self.flow.set_margin_end(24)
        self.flow.set_margin_top(6)
        self.flow.set_margin_bottom(24)
        self.flow.connect("child-activated", self.on_click)

        scroll.set_child(self.flow)
        main.append(scroll)

        self.win.set_content(main)

        # Esc to close
        kc = Gtk.EventControllerKey()
        kc.connect("key-pressed", self.on_key)
        self.win.add_controller(kc)

        # Load thumbs async
        threading.Thread(target=self._load_thumbs, daemon=True).start()

        self.win.maximize()
        self.win.present()

    # ── Thumbnails ──
    def _load_thumbs(self):
        for p in self.filtered:
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(p, THUMB_W, THUMB_H, True)
                GLib.idle_add(self._add_card, p, pb)
            except:
                pass

    def _add_card(self, path, pb):
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        card.add_css_class("wall-card")

        # Clipped container for rounded image
        clip = Gtk.Box()
        clip.set_overflow(Gtk.Overflow.HIDDEN)
        clip.add_css_class("wall-card-img")

        ok, data = pb.save_to_bufferv("png", [], [])
        tex = Gdk.Texture.new_from_bytes(GLib.Bytes.new(data))
        pic = Gtk.Picture.new_for_paintable(tex)
        pic.set_size_request(THUMB_W, THUMB_H)
        pic.set_content_fit(Gtk.ContentFit.COVER)
        clip.append(pic)
        card.append(clip)

        # Label
        nm = os.path.splitext(os.path.basename(path))[0]
        lbl = Gtk.Label(label=nm[:35])
        lbl.add_css_class("wall-label")
        lbl.set_ellipsize(3)
        lbl.set_margin_top(4); lbl.set_margin_bottom(6)
        card.append(lbl)

        card._wp = path
        self.flow.append(card)
        return False

    # ── Events ──
    def on_click(self, flow, child):
        card = child.get_child()
        if hasattr(card, "_wp"):
            threading.Thread(target=self.apply_wallpaper, args=(card._wp,), daemon=True).start()
            GLib.timeout_add(350, self.win.close)

    def on_random(self, btn):
        import random
        if self.filtered:
            path = random.choice(self.filtered)
            threading.Thread(target=self.apply_wallpaper, args=(path,), daemon=True).start()
            GLib.timeout_add(350, self.win.close)

    def on_search(self, entry):
        txt = entry.get_text().lower().strip()
        while True:
            c = self.flow.get_first_child()
            if c is None: break
            self.flow.remove(c)
        self.filtered = [p for p in self.images if txt in os.path.basename(p).lower()] if txt else list(self.images)
        threading.Thread(target=self._load_thumbs, daemon=True).start()

    def on_key(self, ctrl, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self.win.close()
            return True
        return False


if __name__ == "__main__":
    WallpaperPicker().run(None)
