"""Génère les couches de parallax (pixel art) de Sprites/Parallax/ : le décor
d'une île couverte de forêt. Du fond vers l'avant : la mer et des îlots à
l'horizon, les collines boisées de l'île, puis deux couches de jungle tirées
de Sprites/Parallax/Source/jungle.png (dossier ignoré par Godot).

Chaque couche se répète sans raccord à l'horizontale. Une ligne de base
marque le pied du relief : en dessous, la couleur du pied continue sur
EXTENSION pixels, pour ne jamais voir le vide quand la caméra descend.
Lumière : le soleil de l'ambiance extérieure est en haut à droite, donc les
faces tournées vers la droite sont éclairées.

Relancer après un changement (depuis la racine du projet) :
    python tools/generer_parallax.py
"""
import math
import os
import random
from PIL import Image, ImageDraw

SORTIE = "Sprites/Parallax/"
SOURCE_JUNGLE = "Sprites/Parallax/Source/jungle.png"
EXTENSION = 260
HORIZON = (219, 204, 189)  # brume chaude vers l'horizon


def c(r, g, b):
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def melange(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def periodique(w, octaves, graine):
    """Bruit 1D qui boucle exactement sur w pixels."""
    rnd = random.Random(graine)
    phases = [(f, a, rnd.random() * math.tau) for f, a in octaves]
    return [sum(a * math.sin(math.tau * f * x / w + p) for f, a, p in phases) for x in range(w)]


def arbre(draw, x, y_pied, taille, sorte, lumiere, base, tronc=None):
    """Dessine un arbre : d'abord la silhouette éclairée, puis le corps décalé
    à gauche, ce qui laisse un liseré de lumière côté soleil."""
    if tronc:
        tw = max(1, taille // 14)
        draw.rectangle([x - tw, y_pied - taille // 3, x + tw, y_pied], fill=tronc)
    for col, dx in ((lumiere, 0), (base, -max(1, taille // 12))):
        if sorte == "sapin":
            etages = 4
            for i in range(etages):
                haut = y_pied - taille + i * taille // (etages + 1)
                larg = taille * (i + 2) // (etages * 2 + 2)
                draw.polygon([(x + dx, haut), (x + dx - larg, haut + taille // 3), (x + dx + larg, haut + taille // 3)], fill=col)
        else:
            r = taille // 3
            for ox, oy, rr in ((0, -taille + r, r), (-r * 0.7, -taille + r * 1.7, r * 0.8),
                               (r * 0.7, -taille + r * 1.6, r * 0.85), (0, -taille + r * 2.2, r * 0.9)):
                draw.ellipse([x + dx + ox - rr, y_pied + oy - rr, x + dx + ox + rr, y_pied + oy + rr], fill=col)


def foret(nom, w, h, base, graine, nombre, taille, couleurs, sortes, brume=0.0, tronc=None):
    corps, eclaire, ombre = couleurs
    rnd = random.Random(graine)
    large = Image.new("RGBA", (w * 3, h + EXTENSION), (0, 0, 0, 0))
    draw = ImageDraw.Draw(large)
    # Sous-bois continu au pied des arbres.
    sol = periodique(w, [(3, 3), (7, 2), (13, 1)], graine + 1)
    for x in range(w * 3):
        draw.line([(x, base - 4 - sol[x % w]), (x, h + EXTENSION)], fill=ombre)
    arbres = sorted(((rnd.random() * w, taille * rnd.uniform(0.6, 1.0), rnd.choice(sortes), rnd.randint(0, 3))
                     for _ in range(nombre)), key=lambda a: a[1])
    for x, t, s, dy in arbres:
        for decal in (0, w, 2 * w):
            arbre(draw, int(x + decal), base + dy, int(t), s, eclaire, corps, tronc)
    img = large.crop((w, 0, 2 * w, h + EXTENSION))
    if brume > 0.0:
        px = img.load()
        for y in range(h + EXTENSION):
            t = max(0.0, min(1.0, (y - (base - taille * 0.6)) / (taille * 0.6))) * brume
            for x in range(w):
                if px[x, y][3]:
                    px[x, y] = melange(px[x, y], HORIZON, t)
    img.save(SORTIE + nom)


def couronnes(draw, rnd, x, y, r, lumiere, corps):
    """Une cime d'arbre vue de loin : un rond éclairé, puis le corps décalé à
    gauche, ce qui laisse un liseré de lumière côté soleil."""
    draw.ellipse([x - r, y - r, x + r, y + r], fill=lumiere)
    d = max(1, r // 3)
    draw.ellipse([x - r - d, y - r + d // 2, x + r - d, y + r + d // 2], fill=corps)


def mer(nom, w, h, horizon, graine, ilots, mer_couleurs, ilot_couleur):
    """La mer jusqu'à l'horizon, avec quelques îlots boisés posés dessus."""
    rnd = random.Random(graine)
    loin, pres, reflet = mer_couleurs
    img = Image.new("RGBA", (w, h + EXTENSION), (0, 0, 0, 0))
    px = img.load()
    for y in range(horizon, h + EXTENSION):
        t = min(1.0, (y - horizon) / 40)
        col = melange(loin, pres, t)
        for x in range(w):
            px[x, y] = col
    draw = ImageDraw.Draw(img)
    # Reflets : traits courts, plus serrés près de l'horizon.
    for _ in range(140):
        y = horizon + 2 + int(rnd.random() ** 2 * 50)
        x = rnd.randrange(w)
        long = rnd.randint(2, 7)
        for dx in range(long):
            px[(x + dx) % w, y] = reflet
    # Îlots : bosses arrondies couvertes de cimes, avec une bande de brume au pied.
    large = Image.new("RGBA", (w * 3, h + EXTENSION), (0, 0, 0, 0))
    dl = ImageDraw.Draw(large)
    reperes = [(rnd.random() * w, rnd.randint(30, 80), rnd.randint(8, 22)) for _ in range(ilots)]
    for decal in (0, w, 2 * w):
        r2 = random.Random(graine + 1)
        for x, larg, haut in reperes:
            x += decal
            dl.ellipse([x - larg, horizon - haut, x + larg, horizon + haut], fill=ilot_couleur)
            for _ in range(larg // 3):
                cx = x + r2.uniform(-0.8, 0.8) * larg
                bosse = haut * math.sqrt(max(0.0, 1 - ((cx - x) / larg) ** 2))
                couronnes(dl, r2, int(cx), int(horizon - bosse + 1), r2.randint(2, 3),
                          melange(ilot_couleur, (255, 255, 255), 0.18), ilot_couleur)
    ilots_img = large.crop((w, 0, 2 * w, horizon + 1))
    img.alpha_composite(ilots_img, (0, 0))
    draw.line([(0, horizon), (w, horizon)], fill=melange(loin, (255, 255, 255), 0.35))
    img.save(SORTIE + nom)


def collines(nom, w, h, graine, sommet, creux, couleurs, brume=0.0):
    """Collines arrondies couvertes de forêt : une ligne de cimes bosselée,
    des cimes plus petites semées sur les pentes, les flancs tournés vers le
    soleil plus clairs, et de la brume qui s'accumule dans les creux."""
    corps, eclaire, sombre = couleurs
    rnd = random.Random(graine)
    bruit = periodique(w, [(1, 0.7), (2, 1.0), (3, 0.6), (5, 0.25)], graine)
    mini, maxi = min(bruit), max(bruit)
    profil = [creux - (v - mini) / (maxi - mini) * (creux - sommet) for v in bruit]
    large = Image.new("RGBA", (w * 3, h + EXTENSION), (0, 0, 0, 0))
    draw = ImageDraw.Draw(large)
    for X in range(w * 3):
        x = X % w
        pente = profil[(x + 6) % w] - profil[x - 6]
        # Flanc tourné vers le soleil (le relief descend vers la droite) : plus clair.
        col = melange(corps, eclaire, max(0.0, min(1.0, pente / 10))) if pente > 0 else melange(corps, sombre, min(1.0, -pente / 14))
        draw.line([(X, profil[x] + 3), (X, h + EXTENSION)], fill=col)
    # Ligne de cimes sur la crête, puis cimes semées sur les pentes.
    cimes = []
    x = 0.0
    while x < w:
        cimes.append((x, profil[int(x)] + 2, rnd.randint(3, 5)))
        x += rnd.uniform(3, 6)
    for _ in range(w * 2):
        x = rnd.random() * w
        prof = rnd.random() ** 1.5 * (h - profil[int(x)])
        cimes.append((x, profil[int(x)] + 6 + prof, rnd.randint(3, 5)))
    cimes.sort(key=lambda c_: c_[1])
    for decal in (0, w, 2 * w):
        for x, y, r in cimes:
            ix = int(x) % w
            pente = profil[(ix + 6) % w] - profil[ix - 6]
            base = melange(corps, sombre, 0.35) if pente < 0 else corps
            # Liseré adouci sous la crête : une texture de feuillage, pas des bulles.
            lisere = eclaire if y <= profil[ix] + 3 else melange(base, eclaire, 0.45)
            couronnes(draw, rnd, int(x + decal), int(y), r, lisere, base)
    img = large.crop((w, 0, 2 * w, h + EXTENSION))
    if brume > 0.0:
        px = img.load()
        for y in range(h + EXTENSION):
            t = max(0.0, min(1.0, (y - sommet) / max(1, creux - sommet + 30))) ** 1.4 * brume
            for x in range(w):
                if px[x, y][3]:
                    px[x, y] = melange(px[x, y], HORIZON, t)
    img.save(SORTIE + nom)


def jungle(nom, largeur, brume=0.0, teinte=None, raccord=0.1):
    """Une couche de jungle tirée de l'image source : rendue raccordable (le
    bord droit est fondu dans le bord gauche), réduite à `largeur` pixels,
    puis prolongée vers le bas par la teinte sombre du sous-bois."""
    src = Image.open(SOURCE_JUNGLE).convert("RGBA")
    src = src.crop(src.getbbox())
    w, h = src.size
    n = int(w * raccord)
    tuile = src.crop((0, 0, w - n, h))
    # Les n premières colonnes reçoivent un fondu de la fin de l'image : le
    # bord droit de la tuile retombe ainsi sur son bord gauche.
    fin, debut = src.crop((w - n, 0, w, h)), src.crop((0, 0, n, h))
    masque = Image.linear_gradient("L").rotate(90, expand=True).resize((n, h))
    tuile.paste(Image.composite(fin, debut, masque), (0, 0))
    haut = round(h * largeur / tuile.size[0])
    tuile = tuile.resize((largeur, haut), Image.LANCZOS)
    img = Image.new("RGBA", (largeur, haut + EXTENSION), (0, 0, 0, 0))
    img.paste(tuile, (0, 0))
    px = img.load()
    # Couleur du sous-bois : la moyenne, assombrie, des dernières lignes pleines.
    bas = [px[x, y] for x in range(largeur) for y in range(int(haut * 0.8), int(haut * 0.9)) if px[x, y][3] > 200]
    sous_bois = tuple(int(sum(p[i] for p in bas) / len(bas) * 0.55) for i in range(3)) + (255,)
    for x in range(largeur):
        plein = False
        for y in range(int(haut * 0.85), haut + EXTENSION):
            if px[x, y][3] > 200:
                plein = True
            elif plein or y >= haut:
                px[x, y] = sous_bois
    # Alpha net : pas de franges semi-transparentes en pixel art.
    for y in range(haut + EXTENSION):
        for x in range(largeur):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
            else:
                col = (r, g, b, 255)
                if teinte:
                    col = melange(col, teinte, 0.25)
                if brume > 0.0:
                    t = max(0.0, min(1.0, y / haut)) ** 1.5 * brume
                    col = melange(col, HORIZON, max(t, brume * 0.5))
                px[x, y] = col
    img.save(SORTIE + nom)


if __name__ == "__main__":
    os.makedirs(SORTIE, exist_ok=True)
    mer("1_mer.png", 640, 120, 60, 5, 5,
        (c(0.66, 0.78, 0.86), c(0.40, 0.60, 0.76), c(0.92, 0.95, 0.98)), c(0.38, 0.53, 0.56))
    collines("2_collines.png", 560, 200, 11, 70, 160,
             (c(0.26, 0.45, 0.42), c(0.40, 0.58, 0.46), c(0.19, 0.35, 0.37)), brume=0.45)
    jungle("3_jungle_lointaine.png", 250, brume=0.5, teinte=(60, 95, 120))
    jungle("4_jungle.png", 384, brume=0.15)
    print("ok")
