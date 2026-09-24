# Muses

Prototype de **metroidvania 2D** développé avec [Godot Engine 4.7](https://godotengine.org/).

Le projet en est au stade du prototype de gameplay : un personnage jouable au
déplacement complet (course, double saut, dash, saut mural), une arme à feu, un
premier ennemi avec IA, un système de vie pour les deux camps, une caméra
dynamique avec mode « concentration », et des niveaux construits au TileSet.

## Lancer le projet

1. Installer Godot **4.7** (Forward+).
2. Cloner le dépôt et ouvrir `project.godot` dans Godot.
3. Appuyer sur **F5** — la scène principale est `Scenes/Levels/scene_test.tscn`.

## Contrôles

| Action | Clavier | Manette |
|---|---|---|
| Se déplacer | ← → ou Q / D | Stick gauche |
| Courir | Double appui sur une direction (maintenir) ou Maj | ZL (maintenir) |
| Sauter / double saut | Espace | A |
| Dash (en l'air, direction requise) | E + ← ou → | B + stick |
| Tirer | Clic gauche ou F | ZR / RT |
| S'agripper à un mur | Automatique au contact en l'air | Automatique |
| Saut mural | Espace (le personnage se retourne seul) | A |
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
- Dash horizontal sans gravité, uniquement en l'air et dans une direction
  indiquée, avec cooldown et recharge au sol
- Agrippage automatique aux murs : glissade lente au contact, recharge du double
  saut et du dash ; diriger le personnage à l'opposé du mur fait lâcher prise
- Saut mural : la touche de saut suffit, le personnage se retourne immédiatement
  dos au mur et s'en éloigne (courte tolérance après avoir quitté la paroi)
- Dégâts de chute proportionnels à la hauteur parcourue, annulés si l'on
  s'accroche à un mur ou si l'on dashe pendant la chute
- Animations `idle`, `walk`, `run`, `jump`, `fall`, `grab`, `fire` (le sprite de
  chute ne s'affiche qu'après un certain temps de descente)
- Décalage de sprite réglable par animation, pour compenser des tailles de frame
  différentes d'une planche à l'autre

### Arme à feu
- Tir à cadence limitée, dans la direction où regarde le personnage
- Le personnage s'immobilise et ne peut plus se retourner le temps que le coup
  parte, pour que la balle suive toujours la pose affichée
- Le départ de la balle est calé sur la frame voulue de l'animation de tir
- Le projectile (`Scenes/Weapons/bullet.tscn`) vit dans le niveau, avance en ligne
  droite et disparaît au premier contact ou en fin de durée de vie
- Interface d'impact générique : tout noeud exposant `take_damage(amount, from)`
  réagit au tir. Le script `Scripts/Elements/shootable.gd` fournit une cible
  prête à l'emploi (points de vie, signal `triggered`) pour les ennemis comme
  pour les mécanismes à déverrouiller

### Ennemis
- `EnnemyWalker` : soumis à la gravité, il alterne marche et pauses de durées
  aléatoires, fait demi-tour devant un mur ou au bord d'un vide
- Champ de vision orienté : il ne repère le joueur que devant lui, dans un angle
  réglable, et seulement si aucun obstacle ne coupe la ligne de vue
- Poursuit le joueur tant qu'il le voit, et l'abandonne après un délai une fois
  perdu de vue
- Se déplace plus vite et accélère plus franchement une fois le joueur repéré,
  avec une animation de course distincte de sa marche
- Se place à distance de frappe et recule s'il se retrouve collé au joueur
- Attaque en trois temps (préparation, fenêtre active, récupération) avec une
  zone de frappe qui n'est dangereuse que pendant la fenêtre active. La
  préparation dure exactement le temps de l'animation d'attaque, lue dans le
  `SpriteFrames` : changer la vitesse de l'animation suffit à régler le timing
- Encaisse les tirs (points de vie, recul, clignotement), joue une animation de
  mort et laisse une dépouille débarrassée de toutes ses collisions

### Joueur : vie et dégâts
- Points de vie, invulnérabilité temporaire avec clignotement, recul et
  interruption de l'action en cours (tir amorcé, dash, agrippage) quand un coup
  est encaissé
- Sources de dégâts multiples : attaque d'ennemi, contact optionnel, chute
- Barre de vie à l'écran, branchée automatiquement sur le signal `health_changed`
- Relance de la scène après un délai à la mort

### Niveaux
- Décors construits avec un `TileMapLayer` et le TileSet `Tilesets/`
- Les collisions des tuiles se définissent dans l'éditeur de TileSet
  (couche physique + polygone par tuile)

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
│   ├── Ennemies/ennemy_walker.tscn
│   ├── UI/health_bar.tscn
│   ├── Weapons/bullet.tscn
│   ├── Levels/scene_test.tscn  # Scène principale
│   └── Tilesets/Forest_tileset.tscn
├── Scripts/
│   ├── Character/player.gd     # Toute la logique du joueur et de la caméra
│   ├── Ennemies/ennemy_walker.gd # IA de l'ennemi de base
│   ├── UI/health_bar.gd        # Barre de vie
│   ├── Weapons/bullet.gd       # Projectile
│   └── Elements/shootable.gd   # Cible générique (ennemi, interrupteur...)
├── Shaders/
│   └── vignette.gdshader       # Assombrissement des bords (mode concentration)
├── Sprites/
│   ├── Héros/                  # Spritesheets du personnage
│   └── Ennemies/               # Spritesheets des ennemis
├── Tilesets/                   # Planches de tuiles des décors
├── tools/                      # Scripts de synchronisation Git
└── project.godot
```

## Réglages

Tous les paramètres de gameplay sont exposés dans l'inspecteur Godot, sans
toucher au code :

- **Nœud `player`** (`player.tscn`) — groupes *Déplacement*, *Saut*, *Mur*,
  *Dash*, *Arme*, *Vie*, *Dégâts de chute*, *Sprite*, *Caméra* et *Limites* :
  vitesses, hauteur de saut, coyote time, conditions du dash, cadence de tir,
  points de vie, seuil de dégâts de chute, décalages de sprite, facteur de
  dézoom, intensité de la vignette, etc.
- **Nœud `EnnemyWalker`** (`ennemy_walker.tscn`) — groupes *Déplacement*,
  *Errance*, *Détection du terrain*, *Vision*, *Poursuite*, *Attaque*, *Combat*,
  *Retour visuel*, *Mort*, *Animations* et *Sprite* : vitesses, rythme des
  pauses, angle de vision, portée et timing d'attaque, points de vie, recul,
  clignotement, comportement de la dépouille.
- **Nœud `Camera2D`** — zoom de base et limites de la caméra (à surcharger par
  scène si besoin).
- **Nœud `FocusLayer/Vignette`** → *Material* → *Shader Parameters* — forme,
  rayon, douceur et couleur de la vignette.
- **Nœud `HUD/HealthBar`** — position, couleurs et vitesse de remplissage de la
  barre de vie.

Les sondes de l'ennemi (rayons de sol, de mur et de vue) ainsi que sa zone de
frappe sont **placées et dimensionnées automatiquement** au lancement d'après ces
exports et d'après sa forme de collision : inutile de les régler à la main sur
les nœuds.

## Couches de collision

| Couche | Usage |
|---|---|
| 1 | Monde (tuiles, plateformes) |
| 2 | Joueur |
| 3 | Ennemis et cibles destructibles (ce que les tirs touchent) |
| 4 | Zones de dégâts infligées au joueur |

## Feuille de route

- [ ] Sprite de dash et sprite de dégâts pour le joueur
- [ ] Ligne de vue de l'ennemi affinée (deux rayons pour voir par-dessus un muret)
- [ ] Niveaux et limites de caméra par salle
- [ ] Portes et mécanismes déclenchés au tir
- [ ] Autres types d'ennemis (volant, tireur)
- [ ] Sauvegarde et points de contrôle

## Journal des mises à jour

### 25 septembre 2026 — combat et survie

**Ennemi `EnnemyWalker`** (nouveau)
- IA complète : errance aléatoire (marche / pauses de durées tirées au hasard),
  demi-tour devant un mur ou au bord d'un vide, limite de patrouille optionnelle
- Champ de vision orienté et réglable en degrés, avec ligne de vue bloquée par
  les murs, et repérage automatique à très courte distance
- Poursuite plus rapide que la marche, avec animation de course dédiée, maintien
  d'une distance de frappe et recul s'il se retrouve collé au joueur
- Attaque en trois temps, zone de frappe réglable, dégâts appliqués à la fin de
  l'animation d'attaque
- Points de vie, recul et clignotement rouge à l'impact, animation de mort, puis
  dépouille dont toutes les collisions et zones sont retirées

**Joueur**
- Points de vie, invulnérabilité temporaire, clignotement, recul, et
  interruption des actions en cours à l'encaissement
- Dégâts de chute proportionnels à la hauteur, annulés par l'agrippage ou le dash
- Dash restreint à l'air et conditionné à une direction, avec mémorisation de
  l'appui pour permettre les deux ordres de saisie
- Barre de vie à l'écran, autonome, avec remplissage animé et alerte en rouge

**Divers**
- Couches de collision formalisées (monde, joueur, ennemis, zones de dégâts)
- Projectiles capables de trouver la cible à travers une `Hurtbox` enfant
- Décalages de sprite par animation, côté joueur comme côté ennemi

## Synchroniser avec GitHub

Des scripts dans `tools/` automatisent les opérations Git courantes (double-clic
sur le `.bat` ou lancement depuis un terminal) :

| Commande | Effet |
|---|---|
| `sync.bat` (à la racine) ou `.\tools\sync.ps1` | **Tout en un** : pull puis commit + push |
| `tools\pull.bat` ou `.\tools\pull.ps1` | Récupère les modifications distantes (`git pull --rebase`), en mettant de côté puis restaurant les modifications locales non commitées |
| `tools\push.bat` ou `.\tools\push.ps1` | `git add -A`, commit, puis push de la branche courante |

Un message de commit peut être passé en argument, sinon un message horodaté est
généré automatiquement :

```
sync.bat "Ajout du système de dash"
```
