"""Genere les fichiers GDScript des traductions a partir de src/*.tsv.

Un TSV : une ligne = `francais<TAB>anglais`. Dans une cellule : \n = retour a la ligne,
\t = tabulation, \\ = antislash. Les lignes vides et celles qui commencent par # sont ignorees.
Usage : python -I generer.py   (depuis jeu/langues)
"""
import glob
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
BS = chr(92)


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


def gdq(s):
    s = s.replace(BS, BS + BS).replace('"', BS + '"').replace('\n', BS + 'n').replace('\t', BS + 't')
    return '"' + s + '"'


def lire(chemin):
    res = {}
    for n, ligne in enumerate(open(chemin, encoding='utf-8').read().split('\n'), 1):
        ligne = ligne.rstrip('\r')
        if not ligne.strip() or ligne.startswith('#'):
            continue
        if '\t' not in ligne:
            print('ERREUR %s:%d pas de tabulation : %s' % (chemin, n, ligne[:60]))
            sys.exit(1)
        fr, en = ligne.split('\t', 1)
        res[decoder(fr)] = decoder(en)
    return res


def main():
    noms = []
    for t in sorted(glob.glob(os.path.join(ICI, 'src', '*.tsv'))):
        nom = os.path.splitext(os.path.basename(t))[0]
        d = lire(t)
        lignes = ['## GENERE par generer.py depuis src/%s.tsv : ne pas editer a la main.' % nom, 'extends RefCounted', '', 'const T := {']
        for fr, en in d.items():
            lignes.append('\t%s: %s,' % (gdq(fr), gdq(en)))
        lignes.append('}')
        open(os.path.join(ICI, 'en_%s.gd' % nom), 'w', encoding='utf-8', newline='\n').write('\n'.join(lignes) + '\n')
        noms.append(nom)
    corps = ['## GENERE par generer.py : la liste des fichiers de traduction anglaise.', 'class_name EnTextes', 'extends RefCounted', '',
             'static func sources() -> Array:', '\treturn [']
    for nom in noms:
        corps.append('\t\tpreload("res://langues/en_%s.gd").T,' % nom)
    corps.append('\t]')
    open(os.path.join(ICI, 'en_textes.gd'), 'w', encoding='utf-8', newline='\n').write('\n'.join(corps) + '\n')
    print('%d fichiers' % len(noms))


main()
