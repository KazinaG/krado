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
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
# window_rect height is the whole window; Finder's title bar takes about 28 pt.
window_rect = ((200, 640), (w, h + 28))
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
