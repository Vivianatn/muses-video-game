# Muses

Prototype de **metroidvania 2D** développé avec [Godot Engine 4.7](https://godotengine.org/).

Le projet en est au stade du prototype de gameplay : un personnage jouable avec un
déplacement complet (course, double saut, dash), une caméra dynamique avec mode
« concentration » et une scène de test.

## Lancer le projet

1. Installer Godot **4.7** (Forward+).
2. Cloner le dépôt et ouvrir `project.godot` dans Godot.
3. Appuyer sur **F5** — la scène principale est `Scenes/Levels/scene_test.tscn`.

## Contrôles

| Action | Clavier | Manette |
|---|---|---|
| Se déplacer | ← → ou Q / D | Stick gauche |
| Courir | Double appui sur une direction (maintenir) ou Maj | X |
| Sauter / double saut | Espace | A |
| Dash | E | B |
| Mode concentration (dézoom) | A (maintenir) | RB (maintenir) |
| Regarder autour (en mode concentration) | ← → ↑ ↓ ou Z / Q / S / D | Stick gauche |

Les touches sont définies dans **Projet → Paramètres du projet → Contrôles**
(actions `move_left`, `move_right`, `look_up`, `look_down`, `jump`, `run`, `dash`,
`camera_zoom_out`). Les touches clavier sont mappées par position physique, donc
compatibles AZERTY et QWERTY.

## Fonctionnalités

### Déplacement
- Accélération et friction distinctes au sol et en l'air
- Marche et course, avec sprint par double appui qui persiste au changement de sens
- Saut à hauteur variable (relâcher tôt = saut court)
- Gravité renforcée en descente, vitesse de chute plafonnée
- *Coyote time* et *jump buffer*
- Double saut (nombre de sauts aériens configurable)
- Dash horizontal sans gravité, avec cooldown et recharge au sol
- Animations `idle`, `walk`, `run`, `jump`, `fall` (le sprite de chute ne s'affiche
  qu'après un certain temps de descente)

### Caméra
- Suit le joueur avec lissage
- **Mode concentration** : maintenir la touche dédiée fige le joueur, dézoome la
  caméra et assombrit progressivement les bords de l'écran (vignette ovale via
  shader)
- En mode concentration, les flèches déplacent la caméra dans une direction à la
  fois, jusqu'à une distance maximale ; elle revient au centre dès qu'on relâche
- Les limites de la caméra (`limit_left/right/top/bottom` du `Camera2D`) sont
  respectées, y compris pendant le déplacement manuel

## Structure du projet

```
Muses/
├── Scenes/
│   ├── Character/player.tscn   # Joueur : sprite animé, collision, caméra, vignette
│   ├── Elements/platform_test.tscn
│   └── Levels/scene_test.tscn  # Scène principale
├── Scripts/
│   └── Character/player.gd     # Toute la logique du joueur et de la caméra
├── Shaders/
│   └── vignette.gdshader       # Assombrissement des bords (mode concentration)
├── Sprites/Héros/              # Spritesheets du personnage
└── project.godot
```

## Réglages

Tous les paramètres de gameplay sont exposés dans l'inspecteur Godot, sans
toucher au code :

- **Nœud `player`** (`player.tscn`) — groupes *Déplacement*, *Saut*, *Dash*,
  *Caméra* et *Limites* : vitesses, hauteur de saut, coyote time, durée du dash,
  facteur de dézoom, distance de balayage caméra, intensité de la vignette, etc.
- **Nœud `Camera2D`** — zoom de base et limites de la caméra (à surcharger par
  scène si besoin).
- **Nœud `FocusLayer/Vignette`** → *Material* → *Shader Parameters* — forme,
  rayon, douceur et couleur de la vignette.

## Feuille de route

- [ ] Sprite de dash
- [ ] Wall slide / wall jump
- [ ] Niveaux et limites de caméra par salle
- [ ] Système de vie et ennemis
