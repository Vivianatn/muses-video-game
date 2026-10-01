# Muses

Prototype de **metroidvania 2D** développé avec [Godot Engine 4.7](https://godotengine.org/).

Le projet en est au stade du prototype jouable : une intro studio et un écran
titre animés, un héros au déplacement complet (course, double saut, dash,
escalade), un revolver améliorable, un premier ennemi avec IA, des PNJ qui
parlent, des objets à ramasser, un menu de jeu (inventaire, équipement,
compétences, sauvegardes, paramètres) et une direction artistique unifiée.

## Lancer le projet

1. Installer Godot **4.7** (Forward+).
2. Cloner le dépôt et ouvrir `project.godot` dans Godot.
3. Appuyer sur **F5**. Le jeu démarre sur l'intro du studio
   (`Scenes/UI/studio_splash.tscn`), puis l'écran titre. **Nouvelle partie**
   lance `Scenes/Levels/scene_test.tscn`.

Pour tester un niveau directement, l'ouvrir et appuyer sur **F6**.

## Contrôles

Les touches clavier sont mappées par **position physique** : elles tombent au
même endroit en AZERTY et en QWERTY. Le tableau donne les lettres d'un clavier
AZERTY.

### En jeu

| Action | Clavier | Manette |
|---|---|---|
| Se déplacer | ← → ou Q / D | Stick gauche |
| Courir | Double appui sur une direction (maintenir) ou Maj | ZL / LT (maintenir) |
| Sauter / double saut | Espace | A |
| Dash (direction requise) | E + ← ou → | B + stick |
| Tirer | Clic gauche ou F | ZR / RT |
| S'agripper à un mur | Automatique au contact en l'air | Automatique |
| Saut mural | Espace (le personnage se retourne seul) | A |
| Parler à un PNJ | E | A |
| Mode concentration (dézoom) | A (maintenir) | RB (maintenir) |
| Regarder autour (en concentration) | ← → ↑ ↓ ou Z / Q / S / D | Stick gauche |
| Menu (pause) | Échap | Start |
| Personnage (inventaire) | I | Select |
| Plein écran | F11 | — |

### Dans les menus

| Action | Clavier | Manette |
|---|---|---|
| Se déplacer | Flèches | Croix ou stick gauche |
| Valider | Entrée ou Espace | A |
| Retour | Retour arrière | B |
| Onglet précédent / suivant | A / E | LB / RB |
| Filtre précédent / suivant | W / C | LT / RT |

Toutes les touches se **réaffectent en jeu** : *Paramètres → Touches*, depuis
l'écran titre ou le menu pause. Chaque action accepte deux touches clavier et
un bouton de manette. Les valeurs par défaut sont dans **Projet → Paramètres
du projet → Contrôles**.

Quand une manette est branchée, les invites à l'écran (le « E » au-dessus des
PNJ, les touches des compétences) affichent les boutons de la manette.

## Fonctionnalités

### Intro et écran titre
- **Intro studio** : la vidéo du logo Tharros, puis un fondu vers l'écran
  titre, chargé en arrière-plan pendant la vidéo. Une touche, un clic ou un
  bouton la passe.
- **Écran titre** : logo Muses animé en boucle (vidéo, voir
  [Logo animé](#logo-animé-de-lécran-titre)), séparateur végétal, entrée en
  scène des boutons un à un.
- Boutons *Nouvelle partie*, *Continuer* (dernière sauvegarde), *Charger*,
  *Paramètres* et *Quitter*.
- **Transition « Continuer »** : une ligne d'énergie s'ouvre sur la miniature
  sépia de la sauvegarde, qui reprend ses couleurs puis s'agrandit jusqu'à
  devenir le jeu, à l'endroit exact où on l'avait quitté.

### Héros
- Sprites haute définition, avec des planches distinctes **vers la gauche et
  vers la droite** pour l'attente, la marche, le saut et l'accroche au mur.
  Le sprint et le tir n'existent que vers la droite et sont retournés
  automatiquement.
- Animations : `idle`, `walk`, `run`, `jump`, `fall`, `grab`, `fire`. La chute
  réutilise le sprite de saut tant qu'il n'y a pas de sprite dédié.
- Quand le personnage se retourne au milieu d'une animation, elle reprend à la
  même frame au lieu de recommencer.
- Décalage et taille réglables par animation (groupe *Sprite*) : les pieds
  restent posés sur le bas de la capsule quelle que soit la planche.

### Déplacement
- Accélération et friction distinctes au sol et en l'air
- Marche et course, avec sprint par double appui qui persiste au changement de sens
- Saut à hauteur variable (relâcher tôt = saut court)
- Gravité renforcée en descente, vitesse de chute plafonnée
- *Coyote time* et *jump buffer*
- Double saut (nombre de sauts aériens configurable)
- Dash horizontal sans gravité, dans une direction indiquée, avec cooldown et
  recharge au sol. Le personnage se tourne dans le sens du dash.
- Agrippage automatique aux murs : glissade lente au contact, recharge du double
  saut et du dash ; diriger le personnage à l'opposé du mur fait lâcher prise
- Saut mural : la touche de saut suffit, le personnage se retourne immédiatement
  dos au mur et s'en éloigne (courte tolérance après avoir quitté la paroi)
- Dégâts de chute proportionnels à la hauteur parcourue, annulés si l'on
  s'accroche à un mur ou si l'on dashe pendant la chute

### Compétences
- Chaque mécanique (saut, double saut, course, dash, escalade, tir) est une
  **compétence** décrite par une fiche `SkillData` dans `Skills/`.
- Le joueur ne peut utiliser une mécanique que s'il possède la compétence :
  `Skills.has(&"dash")`, `Skills.unlock(&"dash")`. Les fiches précisent si la
  compétence est acquise dès le départ.
- Onglet *Compétences* du menu : nom, description et touches à utiliser.

### Arme à feu
- Tir à cadence limitée, dans la direction où regarde le personnage
- Le personnage s'immobilise et ne peut plus se retourner le temps que le coup
  parte, pour que la balle suive toujours la pose affichée
- La balle part sur la frame de l'éclair (4e frame de l'animation de tir) ;
  des tirs enchaînés relancent l'animation depuis le début
- Le projectile (`Scenes/Weapons/bullet.tscn`) vit dans le niveau, avance en ligne
  droite et disparaît au premier contact ou en fin de durée de vie
- Interface d'impact générique : tout noeud exposant `take_damage(amount, from)`
  réagit au tir. Le script `Scripts/Elements/shootable.gd` fournit une cible
  prête à l'emploi (points de vie, signal `triggered`) pour les ennemis comme
  pour les mécanismes à déverrouiller

### Équipement du revolver
- Des **pièces** (fiches `WeaponPartData` dans `Items/`) se ramassent comme des
  objets puis se montent sur le revolver, une par emplacement (canon,
  barillet, crosse, viseur).
- Pièces existantes :

  | Pièce | Emplacement | Effet |
  |---|---|---|
  | Canon rayé | Canon | Balles +30 % plus rapides, portée +40 % |
  | Barillet huilé | Barillet | Cadence de tir +25 % |
  | Crosse gravée | Crosse | +1 dégât par balle |

- Onglet *Équipement* du menu. Une pièce qui quitte l'inventaire est démontée.

### PNJ et dialogues
- **Vory**, **Dory** et **Léry** : soumis à la gravité, ils errent au hasard
  (marche / pause) sans jamais tomber d'une plateforme, et s'arrêtent pendant
  une conversation. Dory et Léry héritent du comportement de Vory et ont leurs
  propres réglages.
- Dialogues écrits en **texte** dans `Dialogues/*.txt` : répliques, choix,
  sauts entre étiquettes, conditions et variables (par exemple le nombre de
  Connaissances ramassées).
- Zone `DialogueTrigger` à poser dans un niveau : conversation à l'appui sur
  *Parler* ou automatique à l'entrée, enchaînement de plusieurs conversations.
- Boîte de dialogue avec portrait, nom, texte tapé lettre à lettre et choix.
- Format complet : [`Dialogues/LISEZMOI.md`](Dialogues/LISEZMOI.md).

### Objets et inventaire
- Objets décrits par des fiches `ItemData` dans `Items/` : Connaissance, Clé
  ancienne, pièces du revolver.
- Objets à ramasser (`Collectable`) : ils flottent, éclairent les alentours et
  disparaissent en fondu au contact. Un objet ramassé ne revient jamais, même
  après un chargement.
- Onglet *Inventaire* du menu, avec filtres.

### Menu, sauvegarde et paramètres
- **Menu pause** (Échap / Start) : fenêtre *Personnage* (inventaire,
  équipement, compétences), sauvegarder, charger, paramètres, retour à l'écran
  titre. Le jeu est en pause tant qu'il est ouvert, et le menu ne s'ouvre pas
  pendant un dialogue.
- **Sauvegardes** dans `user://saves/` : 8 emplacements manuels plus une
  sauvegarde automatique toutes les 5 minutes. Chaque emplacement affiche la
  date, le temps de jeu, le lieu et une miniature de l'écran.
- **Paramètres**, communs à toutes les parties (`user://settings.cfg`) : plein
  écran, volume général et réaffectation des touches.
- Détails : [`Scripts/Save/LISEZMOI.md`](Scripts/Save/LISEZMOI.md).

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
- Jauge de vie au HUD, branchée automatiquement sur le signal `health_changed`,
  qui bat en rouge quand la vie est basse
- Relance de la scène après un délai à la mort

### Caméra
- Suit le joueur avec lissage, zoom de base **x1.5**
- **Mode concentration** : maintenir la touche dédiée fige le joueur, dézoome la
  caméra et assombrit progressivement les bords de l'écran (vignette ovale via
  shader)
- En mode concentration, les flèches déplacent la caméra dans une direction à la
  fois, jusqu'à une distance maximale ; elle revient au centre dès qu'on relâche
- Léger zoom avant pendant les dialogues
- Les limites de la caméra (`limit_left/right/top/bottom` du `Camera2D`) sont
  respectées, y compris pendant le déplacement manuel

### Interface et direction artistique
- La DA « Muses » est centralisée dans `Scripts/UI/muses.gd` (couleurs,
  polices, tailles). Règle : **chaud** (bordeaux, cuivre) pour la structure,
  **vert sève** pour ce qui vit ou fonctionne.
- Le thème de toute l'interface (`Scenes/UI/muses_theme.tres`) est **généré**
  par `tools/build_theme.gd` à partir de cette DA. Ne pas retoucher le `.tres`
  à la main : modifier la DA puis relancer
  `godot --headless --path . -s tools/build_theme.gd`.
- Polices libres (licence OFL, dans `Fonts/`) : Chakra Petch (titres), Barlow
  (texte), Silkscreen (chiffres pixel).
- Widgets maison : `Circuit` (séparateur en piste d'énergie, variante
  végétale), `Jauge` (barre segmentée du HUD), `StyleBoxChamfer` (cadres aux
  coins coupés comme les lettres du logo).
- Tous les boutons s'animent seuls au survol, à la sélection et à l'appui
  (autoload `UiMotion`).

### Ambiances visuelles
Chaque niveau reçoit une **ambiance** : on instancie l'une des scènes de
`Scenes/Ambiance/` à la racine du niveau. Les effets se règlent dans
*Effet/Ecran → Material → Shader Parameters*. Ils ne touchent que le monde,
pas le HUD, les dialogues ni le menu.

- **`exterieur.tscn`** (shader `Shaders/ambiance_exterieur.gdshader`) : le
  fond est remplacé par un ciel en dégradé avec un soleil. Les rayons du
  soleil sont bloqués par le terrain et les arbres, ce qui crée des rayons
  entre les feuillages et des ombres. S'y ajoutent un étalonnage chaud en
  lumière et froid à l'ombre, un halo autour des zones claires, du relief,
  une brume vers le bas de l'écran et une vignette.
- **`souterrain.tscn`** (shader `Shaders/ambiance_souterrain.gdshader`) : le
  monde est plongé dans la pénombre et seules les lumières éclairent. Leur
  couleur s'affirme sur ce qu'elles touchent, elles diffusent un halo coloré
  dans l'air et des poussières scintillent dans la lumière. Les ombres
  restent froides et lisibles.
- **`lumiere.tscn`** (nœud `Lumiere`) : une source de lumière à poser dans
  le niveau. Types : *Torche* (vacille), *Lanterne*, *Cristal*, *Champignon*,
  *Sève* (pulsent) ou *Personnalisée*. Le cœur lumineux s'affiche tout seul ;
  on le coupe si le décor dessine déjà la source.

- **`parallax_foret.tscn`** : le décor de l'île, en parallax, à poser à la
  racine d'un niveau extérieur. Du fond vers l'avant : la mer et des îlots
  boisés à l'horizon (défilement 0.1), les collines de l'île couvertes de
  forêt, avec de la brume dans les creux (0.2), une jungle lointaine dans la
  brume bleutée (0.4) et la jungle (0.65). Chaque couche se répète à l'infini.
  Les images (`Sprites/Parallax/`) sont générées par
  `python tools/generer_parallax.py`. Les deux jungles viennent de l'image
  `Sprites/Parallax/Source/jungle.png` (dossier ignoré par Godot) : le script
  la rend raccordable et la réduit. Pour changer de jungle, remplacer cette
  image et relancer le script.

La **couleur de fond** de l'ambiance sert de repère au ciel : la garder
différente de toutes les couleurs des décors. *Effet actif* coupe le
post-traitement, pour comparer.

### Niveaux
- Décors construits avec un `TileMapLayer` et le TileSet `Tilesets/`
- Les collisions des tuiles se définissent dans l'éditeur de TileSet
  (couche physique + polygone par tuile)

## Structure du projet

```
Muses/
├── Dialogues/                  # Conversations en texte + LISEZMOI du format
├── Fonts/                      # Polices de l'interface (OFL)
├── Items/                      # Fiches des objets et pièces du revolver (.tres)
├── Multimédia/                 # Vidéos : intro studio, logo animé de l'écran titre
├── Scenes/
│   ├── Ambiance/               # exterieur, souterrain, lumiere, parallax_foret
│   ├── Character/              # player, vory, dory, léry
│   ├── Collectable/            # connaissance, ancient_key
│   ├── Elements/               # dialogue_trigger, platform_test
│   ├── Ennemies/ennemy_walker.tscn
│   ├── Levels/scene_test.tscn  # Premier niveau
│   ├── Tilesets/Forest_tileset.tscn
│   ├── UI/                     # studio_splash, title_screen, dialogue_box, health_bar, thèmes
│   └── Weapons/bullet.tscn
├── Scripts/
│   ├── Character/              # player.gd, PNJ, sprite_fit.gd, sprite_bounds.gd
│   ├── Collectable/            # Objets à ramasser
│   ├── Dialogue/               # Autoload Dialogues + lecteur du format texte
│   ├── Elements/               # dialogue_trigger.gd, shootable.gd
│   ├── Ennemies/               # IA de l'ennemi de base
│   ├── Equipment/              # Autoload Equipment (pièces du revolver)
│   ├── Input/                  # Autoload InputDevice (clavier ou manette)
│   ├── Inventory/              # Autoload Inventory
│   ├── Items/                  # ItemData, WeaponPartData
│   ├── Save/                   # Autoload SaveGame + LISEZMOI
│   ├── Settings/               # Autoload Settings
│   ├── Skills/                 # Autoload Skills, SkillData
│   ├── UI/                     # Menus, écrans, DA, widgets
│   └── Weapons/bullet.gd
├── Shaders/                    # vignette (concentration), ambiances extérieur et souterrain
├── Skills/                     # Fiches des compétences (.tres)
├── Sprites/
│   ├── Héros/                  # Planches actuelles du héros (156 px / 112 px)
│   ├── Héros_ancien/           # Anciennes planches, plus utilisées
│   ├── Vory/, Dory/, Léry/     # PNJ
│   ├── Ennemies/               # Ennemis
│   ├── Parallax/               # Couches du décor de fond (générées)
│   ├── Elements/               # Objets
│   └── UI/                     # Icônes d'interface (curseurs, interrupteurs)
├── Tilesets/                   # Planches de tuiles des décors
├── tools/                      # build_theme.gd, generer_parallax.py, scripts Git
└── project.godot
```

### Autoloads

| Nom | Script | Rôle |
|---|---|---|
| `UiMotion` | `Scripts/UI/motion.gd` | Animations des boutons et fenêtres |
| `Dialogues` | `Scripts/Dialogue/dialogue_manager.gd` | Déroule les conversations |
| `Inventory` | `Scripts/Inventory/inventory.gd` | Objets possédés |
| `Skills` | `Scripts/Skills/skills.gd` | Compétences du joueur |
| `Equipment` | `Scripts/Equipment/equipment.gd` | Pièces montées sur le revolver |
| `SaveGame` | `Scripts/Save/save_game.gd` | Sauvegardes et emplacements |
| `GameMenu` | `Scripts/UI/game_menu.gd` | Menu pause et fenêtre Personnage |
| `InputDevice` | `Scripts/Input/input_device.gd` | Clavier ou manette, pour les invites |
| `Settings` | `Scripts/Settings/settings.gd` | Paramètres du joueur |

## Réglages

Tous les paramètres de gameplay sont exposés dans l'inspecteur Godot, sans
toucher au code :

- **Nœud `player`** (`player.tscn`) : groupes *Déplacement*, *Saut*, *Mur*,
  *Dash*, *Arme*, *Vie*, *Dégâts de chute*, *Sprite*, *Caméra* et *Limites*.
  On y règle les vitesses, la hauteur de saut, le coyote time, les conditions
  du dash, la cadence et le timing du tir, les points de vie, le seuil de
  dégâts de chute, les décalages et la taille du sprite (0.5 par défaut), le
  facteur de dézoom, l'intensité de la vignette, etc.
- **Nœud `EnnemyWalker`** (`ennemy_walker.tscn`) : groupes *Déplacement*,
  *Errance*, *Détection du terrain*, *Vision*, *Poursuite*, *Attaque*, *Combat*,
  *Retour visuel*, *Mort*, *Animations* et *Sprite*. On y règle les vitesses,
  le rythme des pauses, l'angle de vision, la portée et le timing d'attaque,
  les points de vie, le recul, le clignotement et le comportement de la
  dépouille.
- **PNJ** (`vory.tscn`, `dory.tscn`, `léry.tscn`) : vitesse, durées d'errance,
  rayon de patrouille, décalage du sprite (visible en direct dans l'éditeur).
- **Nœud `Camera2D`** du joueur : zoom de base et limites de la caméra (à
  surcharger par scène si besoin).
- **Nœud `FocusLayer/Vignette`** → *Material* → *Shader Parameters* : forme,
  rayon, douceur et couleur de la vignette.
- **Nœud `HUD/HealthBar`** : position, couleurs et vitesse de remplissage de la
  barre de vie.
- **Autoload `SaveGame`** : nombre d'emplacements, intervalle de sauvegarde
  automatique, largeur des miniatures.

Les sondes de l'ennemi (rayons de sol, de mur et de vue) ainsi que sa zone de
frappe sont **placées et dimensionnées automatiquement** au lancement d'après ces
exports et d'après sa forme de collision : inutile de les régler à la main sur
les nœuds.

## Ajouter du contenu

| Je veux ajouter… | Comment |
|---|---|
| Un objet | Nouvelle ressource `ItemData` dans `Items/`. Voir [`Scripts/Save/LISEZMOI.md`](Scripts/Save/LISEZMOI.md) |
| Un objet à ramasser | Dupliquer `Scenes/Collectable/connaissance.tscn`, changer le sprite et l'*Item Id* |
| Une pièce de revolver | Nouvelle ressource `WeaponPartData` dans `Items/` (emplacement + bonus) |
| Une compétence | Nouvelle ressource `SkillData` dans `Skills/`, puis `Skills.has(&"id")` dans le code |
| Un dialogue | Un `.txt` dans `Dialogues/` + un `DialogueTrigger` dans le niveau. Voir [`Dialogues/LISEZMOI.md`](Dialogues/LISEZMOI.md) |
| Une animation du héros | Ajouter l'animation au `SpriteFrames` du joueur. Pour une version par sens, la nommer `nom_left` / `nom_right` : le script choisit la bonne tout seul |
| Une touche | Nouvelle action dans *Contrôles* : elle apparaît d'elle-même dans le panneau *Touches* |

## Logo animé de l'écran titre

Le logo Muses est un SVG animé (`muses-logo-anime_1.svg`). Godot affiche les
SVG en image fixe : le logo est donc joué sous forme de **vidéo**,
`Multimédia/muses-logo-anime.ogv` (Theora, 1200×342, 30 i/s, boucle de 24 s).

- La vidéo a été capturée image par image dans Chrome à partir du SVG, pour
  garder lueurs, flous et masques.
- Pour que la boucle soit sans raccord, certaines durées ont été recalées dans
  la copie utilisée pour la capture (pas dans le SVG d'origine) :
  9 s → 8 s, 10 s → 12 s, 3,5 s → 4 s, 2,5 s → 2,4 s, 0,9 s → 0,96 s.
- La vidéo n'a pas de transparence : son fond est peint de la couleur de
  l'écran titre (`#140b0c`), et un petit shader sur le nœud `Logo` rend cette
  couleur transparente.
- **Après une modification du SVG, la vidéo doit être régénérée.**

## Couches de collision

| Couche | Usage |
|---|---|
| 1 | Monde (tuiles, plateformes) |
| 2 | Joueur |
| 3 | Ennemis et cibles destructibles (ce que les tirs touchent) |
| 4 | Zones de dégâts infligées au joueur |

## Feuille de route

- [x] Sauvegarde et chargement
- [x] PNJ et dialogues
- [x] Inventaire, équipement et compétences
- [x] Écran titre, menu pause et paramètres
- [x] Nouveaux sprites du héros
- [ ] Sprites de chute, de dash et de dégâts pour le héros
- [ ] Points de contrôle dans les niveaux
- [ ] Ligne de vue de l'ennemi affinée (deux rayons pour voir par-dessus un muret)
- [ ] Niveaux et limites de caméra par salle
- [ ] Portes et mécanismes déclenchés au tir (utilisation de la Clé ancienne)
- [ ] Autres types d'ennemis (volant, tireur)
- [ ] Musique et effets sonores

## Journal des mises à jour

### 1er octobre 2026 : nouveaux visuels

**Héros**
- Remplacement de toutes les planches par les nouveaux sprites
  (`Sprites/Héros/`), avec des animations séparées vers la gauche et vers la
  droite (`idle_left` / `idle_right`…). Les anciennes planches sont rangées
  dans `Sprites/Héros_ancien/`.
- Sprite affiché à l'échelle 0.5 et recalé pour que les pieds touchent le bas
  de la capsule. Point de sortie des balles déplacé au bout du nouveau canon.
- Animation de tir à 5 frames (15 i/s), balle synchronisée sur l'éclair.
- Le dash oriente désormais le personnage : le tir suivant part dans le sens
  du dash.
- Caméra du joueur dézoomée de x2 à x1.5 pour mieux voir autour du héros.

**Interface**
- Nouvelle DA « Muses » : thème généré, polices, widgets `Circuit`, `Jauge`
  et `StyleBoxChamfer`, animations des boutons.
- Intro vidéo du studio Tharros avant l'écran titre.
- Logo de l'écran titre remplacé par le logo animé, joué en vidéo en boucle.
- Transition animée du bouton *Continuer*.

**Ambiances**
- Shaders d'ambiance extérieur (ciel, soleil, rayons, étalonnage) et
  souterrain (pénombre, lumières colorées, halo, poussières).
- Nœud `Lumiere` avec types prêts à l'emploi.
- Décor en parallax de l'île : mer et îlots, collines boisées, jungle.
- Le niveau de test utilise l'ambiance extérieure et le parallax.

**Corrections**
- Avertissements GDScript supprimés : conversions explicites vers les types
  de touches dans `settings.gd`, division entière assumée dans
  `sprite_bounds.gd`.

### 29 septembre 2026 : paramètres et commandes
- Paramètres accessibles depuis le menu pause, plus seulement depuis l'écran
  titre : plein écran, volume, touches.
- Panneau de réaffectation des touches (deux touches clavier et un bouton de
  manette par action), enregistré dans `user://settings.cfg`.
- Nouvelles commandes par défaut.

### 28 septembre 2026 : systèmes de jeu
- **Compétences** (`Skills`) : chaque mécanique du héros est conditionnée par
  une fiche `SkillData`.
- **Équipement** (`Equipment`) : pièces du revolver (canon rayé, barillet
  huilé, crosse gravée) qui modifient dégâts, cadence, vitesse et portée.
- **Écran titre** et fenêtre *Personnage* du menu (inventaire, équipement,
  compétences).
- Détection clavier / manette pour adapter les invites à l'écran.

### 25 au 27 septembre 2026 : PNJ, dialogues et objets
- PNJ **Vory**, **Dory** et **Léry** qui errent sans tomber des plateformes.
- Système de dialogue complet, écrit en texte, avec choix et conditions.
- Objets à ramasser (Connaissance, Clé ancienne), inventaire, menu pause et
  sauvegardes avec miniature.
- Calage des sprites par animation partagé entre joueur, ennemis et PNJ
  (`SpriteFit`).

### 25 septembre 2026 : combat et survie

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

### 20 au 23 septembre 2026 : débuts
- Initialisation du projet, déplacement du héros, caméra et mode concentration.
- Premier tileset (forêt).
- Scripts de synchronisation Git.

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
