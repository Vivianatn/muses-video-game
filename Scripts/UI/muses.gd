class_name Muses
extends RefCounted

## La direction artistique du jeu, en constantes. Source : le design system
## « Muses » (https://claude.ai/artifact/5Gm2Y51KKXYrcgFsW2G9Bg).
##
## Le thème de toute l'interface (Scenes/UI/muses_theme.tres) est construit à
## partir d'ici par tools/build_theme.gd : après un changement de la DA, on
## modifie ce fichier puis on relance l'outil.
##
## La règle à tenir partout : chaud (bordeaux, cuivre) pour la structure,
## vert pour ce qui vit ou fonctionne.

# --- Couleurs : une seule ambiance, Nuit ----------------------------------

## Fond de base de tous les écrans.
const NUIT := Color8(0x14, 0x0b, 0x0c)
## Fond des panneaux, un cran au-dessus de NUIT.
const SURFACE := Color8(0x22, 0x11, 0x14)
## Creux : relief, emplacements vides, état désactivé.
const RACINE := Color8(0x3a, 0x0d, 0x17)

## La pierre : en-têtes, appui, bas de la jauge de vie.
const BORDEAUX := Color8(0x6e, 0x1a, 0x2b)
## Face du bouton principal. Seul PARCHEMIN s'écrit dessus.
const BORDEAUX_CLAIR := Color8(0x8c, 0x2a, 0x33)
## Survol du bouton principal, haut de la jauge de vie. Jamais en texte courant.
const BRIQUE := Color8(0xa8, 0x45, 0x2f)
## Le contour de tous les widgets.
const CUIVRE := Color8(0xc8, 0x75, 0x3a)

## Texte principal.
const PARCHEMIN := Color8(0xf1, 0xe8, 0xda)
## Texte secondaire : descriptions, légendes, étiquettes.
const ARGILE := Color8(0xd8, 0xc3, 0xa5)
## Texte sur les rares fonds clairs.
const ENCRE := Color8(0x24, 0x10, 0x0f)

## La nature : tiges, feuilles, objets naturels.
const FORET := Color8(0x2f, 0x5d, 0x3a)
const MOUSSE := Color8(0x6b, 0x8f, 0x3c)
const MOUSSE_OMBRE := Color8(0x4f, 0x6f, 0x2a)
const JADE := Color8(0x3f, 0xa3, 0x7a)
const JADE_OMBRE := Color8(0x2f, 0x7d, 0x5c)

## La technologie : circuits, focus, valeurs importantes, lueur.
const SEVE := Color8(0xa8, 0xd1, 0x8d)
const SEVE_OMBRE := Color8(0x7f, 0xb0, 0x69)

# --- Formes ---------------------------------------------------------------

## Épaisseur du contour cuivre, des pistes de circuit et de l'anneau de focus.
const TRAIT := 2.0
## Coin coupé des boutons, infobulles, emplacements et jauges.
const CHANFREIN_SM := 6.0
## Coin coupé des panneaux et fenêtres.
const CHANFREIN_MD := 12.0
## Décalage du relief, l'ombre portée nette reprise des lettres du logo.
const RELIEF := Vector2(4, 5)
## Lueur des éléments énergétiques ou tout juste découverts.
const LUEUR := Color(SEVE, 0.45)
const LUEUR_TAILLE := 12
## Diamètre des points de connexion, les seuls cercles de l'interface.
const NOEUD := 8.0

# --- Espacements ----------------------------------------------------------

## Écart entre icône et libellé, entre emplacements d'inventaire.
const ESPACE_1 := 8
## Marge intérieure des boutons et des infobulles.
const ESPACE_2 := 16
## Marge intérieure des panneaux.
const ESPACE_3 := 24
## Marges d'écran.
const ESPACE_4 := 40

## Hauteur minimale d'une cible (souris, manette).
const CIBLE_MIN := 48.0
## Côté d'une case d'inventaire.
const EMPLACEMENT := 64
## Largeur d'un panneau : au-delà, on découpe en plusieurs panneaux.
const PANNEAU_MIN := 400.0
const PANNEAU_MAX := 720.0
## Voile posé sur le jeu derrière un panneau.
const VOILE := Color(NUIT, 0.7)
