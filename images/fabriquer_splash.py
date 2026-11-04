"""Fabrique l'image de démarrage de Nuit Blanche (jeu/images/splash.png, 1920x1080).

Montrée par Godot dès l'ouverture de la fenêtre (boot_splash), puis reprise comme décor par
l'écran de démarrage du jeu (ecran_demarrage.gd) : la bande du bas reste vide pour la ligne d'état.

    python jeu/images/fabriquer_splash.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
POLICES = os.path.join(ICI, "..", "polices")
L, H = 1920, 1080
S = 2  # suréchantillonnage des silhouettes (bords lisses)
FOND = (7, 9, 18)  # = application/boot_splash/bg_color
rng = random.Random(31)


def degrade_vertical():
    haut = np.array([5, 7, 16], dtype=np.float32)
    bas = np.array([20, 24, 42], dtype=np.float32)
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None, None] ** 1.6
    img = haut * (1 - t) + bas * t
    return np.repeat(img, L, axis=1)


def halo(cx, cy, rayon, couleur, force):
    ys, xs = np.mgrid[0:H, 0:L].astype(np.float32)
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / rayon
    a = np.clip(1.0 - d, 0, 1) ** 2.2 * force
    return a[:, :, None] * np.array(couleur, dtype=np.float32)


def silhouette(dessiner, couleur=(3, 4, 8)):
    """Un calque RGBA dessiné en grand puis réduit."""
    calque = Image.new("RGBA", (L * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(calque)
    dessiner(d, lambda x, y: (x * S, y * S), couleur + (255,))
    return calque.resize((L, H), Image.LANCZOS)


def colline(d, p, c, base, amp, phase, deb, fin):
    pts = [p(deb, H + 5)]
    for x in range(deb, fin + 1, 8):
        y = base + math.sin(x * 0.0035 + phase) * amp + math.sin(x * 0.011 + phase * 2) * amp * 0.3
        pts.append(p(x, y))
    pts.append(p(fin, H + 5))
    d.polygon(pts, fill=c)


def maison(d, p, c, x, sol, w, h, toit, cheminee=True):
    d.rectangle([p(x, sol - h), p(x + w, sol + 4)], fill=c)
    d.polygon([p(x - 8, sol - h + 3), p(x + w / 2, sol - h - toit), p(x + w + 8, sol - h + 3)], fill=c)
    if cheminee:
        d.rectangle([p(x + w * 0.7, sol - h - toit * 0.8), p(x + w * 0.7 + 12, sol - h - toit * 0.3)], fill=c)


def sapin(d, p, c, x, sol, h):
    d.rectangle([p(x - 3, sol - 10), p(x + 3, sol + 4)], fill=c)
    for k in range(4):
        y1 = sol - 10 - k * h * 0.22
        larg = h * 0.2 * (1 - k * 0.2)
        d.polygon([p(x - larg, y1), p(x, y1 - h * 0.34), p(x + larg, y1)], fill=c)


def eglise(d, p, c, x, sol):
    d.rectangle([p(x, sol - 150), p(x + 56, sol + 4)], fill=c)
    d.polygon([p(x - 4, sol - 150), p(x + 28, sol - 240), p(x + 60, sol - 150)], fill=c)
    d.rectangle([p(x + 56, sol - 90), p(x + 150, sol + 4)], fill=c)
    d.polygon([p(x + 50, sol - 90), p(x + 103, sol - 130), p(x + 156, sol - 90)], fill=c)
    d.rectangle([p(x + 27, sol - 262), p(x + 29, sol - 238)], fill=c)  # croix
    d.rectangle([p(x + 21, sol - 255), p(x + 35, sol - 253)], fill=c)


def lisser(pts, tours=3):
    """Arrondit un contour fermé (coins coupés de Chaikin) : plus de facettes de polygone."""
    for _ in range(tours):
        n = []
        for i in range(len(pts)):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
            n += [(0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1), (0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1)]
        pts = n
    return pts


def _ellipse(cx, cy, rx, ry, n=36):
    return [(cx + rx * math.cos(i * math.tau / n), cy + ry * math.sin(i * math.tau / n)) for i in range(n)]


def _trait_epais(chemin, rayons):
    """Un trait épais qui s'affine : une suite de disques le long du chemin (queue touffue)."""
    r = []
    for i in range(len(chemin) - 1):
        (x0, y0), (x1, y1) = chemin[i], chemin[i + 1]
        r0, r1 = rayons[i], rayons[i + 1]
        for t in np.linspace(0, 1, 8):
            r.append(_ellipse(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r0 + (r1 - r0) * t, r0 + (r1 - r0) * t, 14))
    return r


# Le loup (Edwin, 01/11 : « on dirait des cornes de cerf », puis « il ne ressemble pas à un loup de dos ») :
# la silhouette classique du loup ASSIS DE PROFIL qui hurle à la lune, museau levé, gueule ouverte, UNE
# oreille dressée, collerette de poils au cou, grosse queue touffue posée au sol. Repère : origine au sol
# sous le loup, y vers le haut négatif, ~420 px de haut à k = 1.
CORPS = [
    (-114, 0), (-128, -38), (-124, -84), (-108, -126), (-88, -168), (-72, -212), (-62, -252),    # croupe, dos
    (-56, -288), (-50, -318), (-40, -342),                                                       # nuque épaisse
    (-34, -356), (-22, -418), (0, -372),                                                         # l'oreille dressée
    (18, -380), (44, -398), (76, -424), (98, -436), (108, -428),                                 # front, long museau levé
    (78, -408), (56, -390), (86, -396), (92, -384),                                              # gueule ouverte
    (56, -356), (40, -332),                                                                      # dessous de la mâchoire
    (56, -312), (40, -302), (58, -288), (42, -276), (56, -262), (46, -248),                     # collerette
    (54, -214), (58, -174), (50, -136),                                                          # poitrail
    (52, -98), (52, -40), (66, -10), (70, 0), (26, 0), (28, -46), (22, -80),                     # patte avant
    (2, -74), (-8, -44), (-4, -14), (16, -6), (18, 0),                                           # cuisse, patte arrière
]


def pieces_loup():
    return [lisser(CORPS, 1)]


def pieces_queue():
    return _trait_epais([(-100, -22), (-150, -14), (-196, -12), (-232, -26), (-250, -46)], [26, 30, 28, 22, 14])


def loup(d, p, c, ox, oy, k):
    for pts in pieces_loup() + pieces_queue():
        d.polygon([p(ox + x * k, oy + y * k) for x, y in pts], fill=c)


def main():
    img = degrade_vertical()
    img += halo(1580, 300, 700, (58, 70, 120), 0.55)
    img += halo(1580, 300, 300, (140, 150, 190), 0.55)
    # Étoiles
    etoiles = Image.new("RGB", (L, H), (0, 0, 0))
    de = ImageDraw.Draw(etoiles)
    for _ in range(420):
        x, y = rng.randint(0, L - 1), rng.randint(0, int(H * 0.62))
        if (x - 1580) ** 2 + (y - 300) ** 2 < 170 ** 2:
            continue
        v = rng.randint(70, 190)
        de.point((x, y), fill=(v, v, min(255, v + 20)))
        if rng.random() < 0.07:
            de.ellipse([x - 1, y - 1, x + 1, y + 1], fill=(v, v, v + 40 if v < 215 else 255))
    img += np.asarray(etoiles, dtype=np.float32) * 0.9
    # Lune : disque pâle, cratères discrets, croissant d'ombre
    lune = Image.new("RGBA", (L * S, H * S), (0, 0, 0, 0))
    dl = ImageDraw.Draw(lune)
    cx, cy, r = 1580 * S, 300 * S, 118 * S
    dl.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(236, 230, 208, 255))
    for _ in range(14):
        a, dist = rng.random() * math.tau, rng.random() * r * 0.8
        x, y, rr = cx + math.cos(a) * dist, cy + math.sin(a) * dist, rng.randint(8, 26) * S
        dl.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(208, 200, 176, 255))
    ombre = Image.new("RGBA", lune.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(ombre)
    dd.ellipse([cx - r + 46 * S, cy - r - 8 * S, cx + r + 46 * S, cy + r - 8 * S], fill=(0, 0, 0, 0))
    masque = Image.new("L", lune.size, 0)
    ImageDraw.Draw(masque).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    ombre_a = np.asarray(ombre.split()[3], dtype=np.float32) / 255.0
    lune_a = np.asarray(masque, dtype=np.float32) / 255.0
    teinte = Image.new("RGBA", lune.size, (10, 12, 26, 255))
    lune = Image.composite(teinte, lune, Image.fromarray((ombre_a * lune_a * 0).astype(np.uint8)))
    lune = lune.filter(ImageFilter.GaussianBlur(1.2 * S)).resize((L, H), Image.LANCZOS)
    base = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGBA")
    base = Image.alpha_composite(base, lune)

    # Collines lointaines, brume, village, collines proches
    def loin(d, p, c):
        colline(d, p, c, 860, 40, 1.0, 0, L)
    base = Image.alpha_composite(base, silhouette(loin, (14, 18, 32)))
    brume = Image.fromarray(np.clip(halo(900, 880, 900, (60, 70, 100), 0.35), 0, 255).astype(np.uint8)).convert("RGB")
    fond_arr = np.asarray(base.convert("RGB"), dtype=np.float32) + np.asarray(brume, dtype=np.float32) * 0.5
    base = Image.fromarray(np.clip(fond_arr, 0, 255).astype(np.uint8)).convert("RGBA")

    fenetres = []

    def village(d, p, c):
        colline(d, p, c, 930, 22, 2.0, 0, L)
        sol = 950
        x = 120
        eglise(d, p, c, 360, 955)
        fenetres.extend([(388, 955 - 130), (388, 955 - 100), (430, 955 - 40)])
        for i, (w, h, t) in enumerate([(70, 56, 40), (86, 64, 46), (64, 50, 36), (96, 70, 52), (74, 58, 40),
                                       (84, 62, 44), (70, 52, 38), (92, 66, 48), (66, 54, 36)]):
            xx = [140, 240, 560, 660, 780, 890, 1010, 1120, 1240][i]
            s = sol + math.sin(xx * 0.01) * 6
            maison(d, p, c, xx, s, w, h, t)
            if i % 2 == 0:
                fenetres.append((xx + w * 0.3, s - h * 0.55))
            if i % 3 == 1:
                fenetres.append((xx + w * 0.62, s - h * 0.4))
        for xs in [60, 100, 500, 535, 1340, 1380, 1420, 1730, 1800, 1860]:
            sapin(d, p, c, xs, 955 + math.sin(xs * 0.01) * 6, rng.randint(150, 230))
    base = Image.alpha_composite(base, silhouette(village, (6, 8, 15)))

    # Fenêtres allumées et leur lueur
    lueur = np.zeros((H, L, 3), dtype=np.float32)
    calque = Image.new("RGBA", (L, H), (0, 0, 0, 0))
    dc = ImageDraw.Draw(calque)
    for (x, y) in fenetres:
        dc.rectangle([x, y, x + 9, y + 13], fill=(244, 178, 82, 255))
        lueur += halo(x + 4, y + 6, 46, (170, 100, 34), 0.5)
    base = Image.alpha_composite(base, calque)
    arr = np.asarray(base.convert("RGB"), dtype=np.float32) + lueur
    base = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")

    # Colline du loup, au premier plan à droite : la silhouette se découpe sur la lune
    def avant(d, p, c):
        colline(d, p, c, 985, 28, 4.0, 0, L)
        d.polygon([p(1380, 1000), p(1440, 935), p(1520, 905), p(1600, 902), p(1700, 925), p(1760, 1000)], fill=c)
        loup(d, p, c, 1560, 905, 1.0)
        for xs in [1790, 1850, 1900]:
            sapin(d, p, c, xs, 1000, rng.randint(220, 300))
        for xs in [-10, 40]:
            sapin(d, p, c, xs, 1000, rng.randint(240, 300))
    base = Image.alpha_composite(base, silhouette(avant, (2, 3, 6)))
    # Liseré de lune sur le haut du loup : la silhouette se détache du ciel
    masque = Image.new("L", (L * S, H * S), 0)
    loup(ImageDraw.Draw(masque), lambda x, y: (x * S, y * S), 255, 1560, 905, 1.0)
    m = np.asarray(masque, dtype=np.float32) / 255.0
    decale = np.zeros_like(m)
    decale[5 * S:, :-2 * S] = m[:-5 * S, 2 * S:]   # la silhouette décalée vers le bas : reste le bord haut
    bord = Image.fromarray((np.clip(m - decale, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2 * S))
    bord = bord.resize((L, H), Image.LANCZOS)
    lisere = Image.new("RGBA", (L, H), (120, 134, 190, 0))
    lisere.putalpha(bord.point(lambda v: int(v * 0.55)))
    base = Image.alpha_composite(base, lisere)

    # Brume basse
    brume2 = halo(960, 1000, 1100, (70, 82, 120), 0.35) * np.array([1, 1, 1], dtype=np.float32)
    arr = np.asarray(base.convert("RGB"), dtype=np.float32)
    arr += brume2 * 0.55
    # Voile sombre aux bords (vignette)
    ys, xs = np.mgrid[0:H, 0:L].astype(np.float32)
    v = np.sqrt(((xs - L / 2) / (L * 0.62)) ** 2 + ((ys - H / 2) / (H * 0.7)) ** 2)
    arr *= np.clip(1.15 - v * 0.55, 0.45, 1.0)[:, :, None]
    base = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")

    # Titre
    titre = ImageFont.truetype(os.path.join(POLICES, "IMFell-SC.ttf"), 170)
    sous = ImageFont.truetype(os.path.join(POLICES, "IMFell-Italic.ttf"), 40)
    texte = "Nuit Blanche"
    boite = titre.getbbox(texte)
    tx = (L - (boite[2] - boite[0])) // 2 - boite[0] - 330
    ty = 300
    ombre = Image.new("RGBA", (L, H), (0, 0, 0, 0))
    ImageDraw.Draw(ombre).text((tx + 4, ty + 7), texte, font=titre, fill=(0, 0, 0, 230))
    base = Image.alpha_composite(base, ombre.filter(ImageFilter.GaussianBlur(10)))
    lueur_t = Image.new("RGBA", (L, H), (0, 0, 0, 0))
    ImageDraw.Draw(lueur_t).text((tx, ty), texte, font=titre, fill=(214, 160, 70, 120))
    base = Image.alpha_composite(base, lueur_t.filter(ImageFilter.GaussianBlur(18)))
    lettres = Image.new("RGBA", (L, H), (0, 0, 0, 0))
    ImageDraw.Draw(lettres).text((tx, ty), texte, font=titre, fill=(238, 206, 132, 255))
    # un dégradé or -> parchemin sur les lettres
    degr = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    ligne = np.asarray(lettres, dtype=np.float32).copy()
    haut = np.array([248, 226, 160], dtype=np.float32)
    bas = np.array([196, 140, 62], dtype=np.float32)
    t = np.clip((degr - (ty + 20) / H) / (150 / H), 0, 1)
    ligne[:, :, :3] = haut * (1 - t[:, :, None]) + bas * t[:, :, None]
    ligne[:, :, 3] = np.asarray(lettres, dtype=np.float32)[:, :, 3]
    base = Image.alpha_composite(base, Image.fromarray(ligne.astype(np.uint8)))
    # Filet orné et sous-titre
    d = ImageDraw.Draw(base)
    cx0 = tx + (boite[2] - boite[0]) // 2 + boite[0]
    y_f = ty + 215
    for sens in (-1, 1):
        d.line([(cx0 + sens * 18, y_f), (cx0 + sens * 330, y_f)], fill=(196, 150, 78, 200), width=2)
        d.line([(cx0 + sens * 330, y_f), (cx0 + sens * 360, y_f)], fill=(196, 150, 78, 90), width=2)
    d.polygon([(cx0, y_f - 10), (cx0 + 10, y_f), (cx0, y_f + 10), (cx0 - 10, y_f)], fill=(226, 184, 100, 255))
    phrase = "le village dort. pas toi."
    bb = sous.getbbox(phrase)
    d.text((cx0 - (bb[2] - bb[0]) // 2 - bb[0], y_f + 30), phrase, font=sous, fill=(168, 160, 150, 255))

    sortie = os.path.join(ICI, "splash.png")
    base.convert("RGB").save(sortie, optimize=True)
    print("écrit", sortie)


if __name__ == "__main__":
    main()
