# Lists the outlet / action / binding connections of a keyed nib archive.
import plistlib, sys, io
def connections(data):
    pl = plistlib.loads(data)
    objs = pl['$objects']
    def deref(v):
        return objs[v.data] if isinstance(v, plistlib.UID) else v
    def cname(o):
        if isinstance(o, dict) and '$class' in o:
            return deref(o['$class'])['$classname']
        return type(o).__name__
    def s(v):
        v = deref(v)
        if isinstance(v, dict) and 'NS.string' in v: return v['NS.string']
        return v
    def describe(o):
        o = deref(o)
        if o == '$null': return 'FirstResponder'
        n = cname(o)
        if n in ('NSCustomObject', 'NSCustomView', 'NSClassSwapper', 'NSWindowTemplate'):
            for k in ('NSClassName', 'NSWindowClass'):
                if k in o: return str(s(o[k]))
        if n == 'NSMenuItem' and 'NSTitle' in o: return 'NSMenuItem(%s)' % s(o['NSTitle'])
        if n in ('NSButton', 'NSTextField', 'NSPopUpButton', 'NSSearchField') and 'NSCell' in o:
            c = deref(o['NSCell'])
            t = s(c.get('NSContents', '')) if isinstance(c, dict) else ''
            return '%s(%s)' % (n, str(t)[:24])
        return n
    out = []
    for o in objs:
        if not isinstance(o, dict): continue
        n = cname(o)
        if n == 'NSNibOutletConnector':
            out.append(('outlet', describe(o['NSSource']), s(o['NSLabel']), describe(o['NSDestination'])))
        elif n == 'NSNibControlConnector':
            out.append(('action', describe(o['NSSource']), s(o['NSLabel']), describe(o['NSDestination']) if 'NSDestination' in o else 'FirstResponder'))
        elif n == 'NSNibBindingConnector':
            out.append(('binding', describe(o['NSSource']), '%s <- %s' % (s(o['NSBinding']), s(o['NSKeyPath'])), describe(o['NSDestination'])))
    return out
if __name__ == '__main__':
    kinds = sys.argv[2].split(',') if len(sys.argv) > 2 else ['outlet', 'action']
    for c in sorted(set(connections(open(sys.argv[1], 'rb').read()))):
        if c[0] in kinds: print('%s\t%s\t%s\t%s' % c)
