# Lists the menu items of a keyed nib: title, key equivalent, action (or binding), tag.
import plistlib, sys
MODS = [(1 << 20, '⌘'), (1 << 17, '⇧'), (1 << 19, '⌥'), (1 << 18, '⌃')]
def main(path):
    pl = plistlib.load(open(path, 'rb'))
    objs = pl['$objects']
    d = lambda v: objs[v.data] if isinstance(v, plistlib.UID) else v
    def s(v):
        v = d(v)
        if isinstance(v, dict) and 'NS.string' in v: return v['NS.string']
        return v if isinstance(v, str) else ''
    cname = lambda o: d(o['$class'])['$classname'] if isinstance(o, dict) and '$class' in o else ''
    actions = {}; bindings = {}
    for o in objs:
        if cname(o) == 'NSNibControlConnector':
            actions[o['NSSource'].data] = s(o['NSLabel'])
        if cname(o) == 'NSNibBindingConnector':
            bindings.setdefault(o['NSSource'].data, []).append('%s<-%s' % (s(o['NSBinding']), s(o['NSKeyPath'])))
    def walk(menu, depth):
        items = d(menu.get('NSMenuItems'))
        for uid in items['NS.objects']:
            item = objs[uid.data]
            title = s(item.get('NSTitle'))
            if item.get('NSIsSeparator'):
                continue
            key = s(item.get('NSKeyEquiv'))
            mask = item.get('NSKeyEquivModMask', 0)
            shortcut = ''
            if key:
                mods = ''.join(sym for bit, sym in MODS if mask & bit)
                if key != key.lower() and '⇧' not in mods: mods += '⇧'
                shortcut = mods + {'': '←', '': '→', '': '↑', '': '↓', '\x1b': 'Esc', '\r': 'Return', '\x7f': 'Delete', '\x08': 'Delete', ' ': 'Space'}.get(key, key.upper())
            sub = item.get('NSSubmenu')
            print('%s%-34s %-8s %-28s tag=%s %s' % ('  ' * depth, title, shortcut, actions.get(uid.data, ''), item.get('NSTag', 0), ' '.join(bindings.get(uid.data, []))))
            if sub is not None:
                walk(d(sub), depth + 1)
    for i, o in enumerate(objs):
        if cname(o) == 'NSMenu' and s(o.get('NSName')) in ('_NSMainMenu',) :
            walk(o, 0)
if __name__ == '__main__':
    main(sys.argv[1])
