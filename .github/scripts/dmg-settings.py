# Settings of dmgbuild for the disk image of ProVoc (see package.sh): a window in icon
# view with ProVoc.app on the left, a shortcut to the Applications folder on the right
# and an arrow between them. dmgbuild writes the layout itself; the Finder is not needed.
application = defines['app']    # noqa: F821 (given by dmgbuild)

format = 'UDZO'
filesystem = 'HFS+'
files = [application]
symlinks = {'Applications': '/Applications'}

background = 'builtin-arrow'
window_rect = ((200, 160), (640, 400))
default_view = 'icon-view'
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
arrange_by = None
icon_size = 128
text_size = 13
icon_locations = {
    'ProVoc.app': (160, 200),
    'Applications': (480, 200),
}
