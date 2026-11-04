"""Liste les chaines francaises VISIBLES probables du code (heuristique).
Usage : python -I extraire.py [racine_jeu]   -> affiche les candidates SANS traduction ni ignore.
Sert aussi au test de couverture (tests/test_traductions.gd lit le meme resultat via --json).
"""
import json
import os
import re
import sys
sys.stdout.reconfigure(encoding='utf-8')

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
BS = chr(92)
MOTS = set('le la les un une des de du tu ton ta tes est et en pas ne ce cette que qui sur dans pour avec au aux vous il elle se sa son ses mon ma mes nous ou où par plus ils elles sont es suis as a ai ont fait faire être avoir tout tous toute chaque aucun aucune sans sous vers entre mais donc car ni quand si comme encore déjà puis seul seule peut peux veux doit dois va vas'.split())
ACCENTS = re.compile('[à-ÿœ«»’…—–À-Ü]')
CAMEL = re.compile(r'^[a-z]+[A-Z]')


def literals(src):
    out = []
    i = 0
    n = len(src)
    line = 1
    while i < n:
        c = src[i]
        if c == '\n':
            line += 1
            i += 1
            continue
        if c == '#':
            while i < n and src[i] != '\n':
                i += 1
            continue
        if c in '"\'':
            if src.startswith(c * 3, i):
                j = src.find(c * 3, i + 3)
                s = src[i + 3:j]
                out.append((line, s))
                line += s.count('\n')
                i = j + 3
                continue
            j = i + 1
            buf = []
            while j < n and src[j] != c:
                if src[j] == BS and j + 1 < n:
                    e = src[j + 1]
                    m = {'n': '\n', 't': '\t', '"': '"', "'": "'", BS: BS}
                    buf.append(m.get(e, BS + e))
                    j += 2
                else:
                    buf.append(src[j])
                    j += 1
            out.append((line, ''.join(buf)))
            i = j + 1
            continue
        i += 1
    return out


def candidat(s):
    t = s.strip()
    if len(t) < 2 or not re.search(r'[A-Za-zÀ-ÿ]{2}', t):
        return False
    if any(k in s for k in ('shader_type', 'void ', 'uniform ', 'vec3', 'GDScript', 'extends ')):
        return False
    if t.startswith(('res://', 'user://', 'http', '--', 'DEF-', 'MI_', 'T_', 'Prop_', 'Wall_', 'Door_', 'Window', 'Roof_', 'Floor_', 'Corner_')):
        return False
    if '_' in t and ' ' not in t:
        return False
    if CAMEL.match(t) and ' ' not in t:
        return False
    if re.fullmatch(r'[A-Za-z0-9_./:\-#@\[\]{}]+', t):
        # un seul mot ASCII : « Rien », « Homme »... on garde les Capitalises, pas les identifiants
        return bool(re.fullmatch(r'[A-Z][a-z]{2,}', t))
    if ACCENTS.search(t):
        return True
    mots = re.findall(r"[A-Za-zà-ÿ']+", t.lower())
    if ' ' in t and any(m in MOTS or m.split("'")[0] in ('l', 'd', 'j', 'n', 'qu', 's', 'c') for m in mots):
        return True
    if t[0].isupper() and ' ' in t and re.fullmatch(r"[A-Za-zà-ÿ0-9' ,.!?:;\-%]+", t):
        return True
    return False


def scan(root):
    res = []
    for d, _, fs in os.walk(root):
        dd = d.replace(BS, '/')
        if '/tests' in dd or 'addons' in dd or '/langues' in dd:
            continue
        for f in sorted(fs):
            if f.endswith('.gd'):
                p = os.path.join(d, f)
                for ln, s in literals(open(p, encoding='utf-8').read()):
                    if candidat(s):
                        res.append((os.path.relpath(p, root).replace(BS, '/'), ln, s))
    return res


def decoder(c):
    out = []
    i = 0
    while i < len(c):
        if c[i] == BS and i + 1 < len(c):
            e = c[i + 1]
            out.append({'n': '\n', 't': '\t', BS: BS}.get(e, BS + e))
            i += 2
        else:
            out.append(c[i])
            i += 1
    return ''.join(out)


def deja(dossier_src):
    """(traduites, ignorees)"""
    tr = set()
    ig = set()
    for f in os.listdir(dossier_src):
        p = os.path.join(dossier_src, f)
        if f.endswith('.tsv'):
            for l in open(p, encoding='utf-8').read().split('\n'):
                l = l.rstrip('\r')
                if l and not l.startswith('#') and '\t' in l:
                    tr.add(decoder(l.split('\t', 1)[0]))
        elif f.startswith('ignore'):
            for l in open(p, encoding='utf-8').read().split('\n'):
                l = l.rstrip('\r')
                if l and not l.startswith('#'):
                    ig.add(decoder(l))
    return tr, ig


if __name__ == '__main__':
    racine = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else os.path.abspath(os.path.join(ICI, '..'))
    tr, ig = deja(os.path.join(ICI, 'src'))
    manque = [x for x in scan(racine) if x[2] not in tr and x[2] not in ig]
    if '--json' in sys.argv:
        json.dump(manque, sys.stdout, ensure_ascii=False)
    else:
        for f, ln, s in manque:
            print('%s:%d\t%s' % (f, ln, s.replace('\n', BS + 'n')))
        print('# %d manquantes (%d uniques)' % (len(manque), len(set(x[2] for x in manque))), file=sys.stderr)
