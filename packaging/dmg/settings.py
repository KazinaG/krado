# dmgbuild settings for krado's DMG window. Values come from `-D` defines set by
# scripts/make-dmg.sh; geometry is shared with make_backgrounds.py via layout.json.
import json
import os.path

app = defines["app"]  # noqa: F821 (provided by dmgbuild)
style = defines["style"]  # noqa: F821
here = defines["dmgdir"]  # noqa: F821
layout = json.load(open(os.path.join(here, "layout.json")))
w, h = layout["window"]["width"], layout["window"]["height"]
app_name = os.path.basename(app)

format = "UDZO"
filesystem = "HFS+"
size = None
files = [app]
symlinks = {"Applications": "/Applications"}
hide_extension = [app_name]
icon = defines["volume_icon"]  # noqa: F821

# background.png + background@2x.png are combined into one HiDPI TIFF by dmgbuild.
background = os.path.join(here, style, "background.png")
# Finder honours toolbar and sidebar per window, but View > Show Path Bar / Show
# Status Bar (and "Show all filename extensions") are the user's global preferences:
# the false values below are ignored when the user has them on. The background keeps
# its bottom layout["bars_reserve"] pt free of art for that case (make_backgrounds.py).
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
# window_rect is the whole window frame: the title bar is 32 pt on macOS 26 (measured
# from v0.1.0, which assumed 28 pt). The background PNG is h + bleed tall.
window_rect = ((200, 640), (w, h + layout["titlebar"]))
default_view = "icon-view"
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
label_pos = "bottom"
text_size = layout["text_size"]
icon_size = layout["icon_size"]
icon_locations = {
    app_name: tuple(layout["app"]),
    "Applications": tuple(layout["applications"]),
}
