# Système de dialogue

## Les pièces

| Fichier | Rôle |
| --- | --- |
| `Scripts/Dialogue/dialogue_manager.gd` | Autoload **`Dialogues`** : déroule les conversations. Le seul point d'entrée. |
| `Scenes/UI/dialogue_box.tscn` + `Scripts/UI/dialogue_box.gd` | L'affichage : portrait, nom, texte tapé, boutons de choix. |
| `Scenes/Elements/dialogue_trigger.tscn` + `Scripts/Elements/dialogue_trigger.gd` | Zone à poser dans un niveau pour lancer une conversation. |
| `Scripts/Dialogue/dialogue.gd` | Une conversation (`Dialogue`) + le lecteur du format texte. |
| `Scripts/Dialogue/dialogue_line.gd` | Une réplique (`DialogueLine`). |
| `Scripts/Dialogue/dialogue_choice.gd` | Une option (`DialogueChoice`). |
| `Dialogues/*.txt` | Les conversations, écrites en texte. |

L'autoload crée sa propre boîte au démarrage : rien à poser dans les niveaux.

## Écrire un dialogue

Un fichier `.txt` dans `Dialogues/` :

```
# commentaire (jusqu'à la fin de la ligne)

:: depart                     # étiquette, cible d'un saut
Vory: Tiens, de la visite.
Ça faisait longtemps.         # pas de nom = Vory continue de parler
Vory: Tu cherches quelque chose ?
- Oui, je suis perdu. -> aide # un choix, et l'étiquette où il mène
- Non, ça va. -> fin

:: aide
Vory: Le chemin redescend derrière les arbres.
@ marqueur_chemin             # événement envoyé au jeu
-> fin                        # saut inconditionnel

:: fin
Vory: Bonne route.
```

| Écriture | Effet |
| --- | --- |
| `Nom: texte` | Réplique de « Nom ». |
| `texte` | Réplique du dernier personnage nommé. |
| `:: etiquette` | Pose une étiquette sur la réplique suivante. |
| `-> etiquette` | Saute là. |
| `- texte -> etiquette` | Option (se raccroche à la réplique juste au-dessus). L'étiquette est facultative. |
| `@ nom argument` | Émet `Dialogues.event(nom, argument)`. |
| `# ...` | Commentaire. Pour un vrai `#`, écris `\#`. |
| ligne vide | Rien, juste de l'aération. |

Le texte accepte le BBCode : `[b]gras[/b]`, `[color=red]…[/color]`, `[shake]…[/shake]`.

## Poser un dialogue dans un niveau

Instancie `Scenes/Elements/dialogue_trigger.tscn` (en enfant du PNJ, comme sur
Vory dans `scene_test`), puis dans l'inspecteur :

- **Dialogue File** : `res://Dialogues/mon_dialogue.txt` ;
- ou **Dialogue Files** : plusieurs fichiers, si le PNJ n'a pas le même
  discours à chaque rencontre (voir la section suivante) ;
- ou **Inline Text** : le dialogue écrit directement sur le déclencheur ;
- ou **Dialogue** : une ressource `.tres` montée à la main.

Réglages utiles : `auto_start` (part sans appuyer), `once` (une seule fois),
`interact_action` (touche, par défaut **E**), `prompt_text` (l'invite flottante).

L'invite se pose toute seule au-dessus de la tête du PNJ, déduite de sa forme
de collision, et garde la même taille à l'écran quelle que soit l'échelle du
personnage. Règle la hauteur avec `prompt_margin` : c'est l'écart entre le
sommet du PNJ et le bas du « E », et une valeur négative le fait descendre sur
la tête.

Si le déclencheur n'est pas rattaché à un personnage, l'invite retombe sur
`prompt_height` ; `prompt_follows_speaker` permet de forcer ce placement manuel.

## Plusieurs conversations pour un même PNJ

Un PNJ n'a pas besoin de plusieurs déclencheurs : **un seul suffit**, avec une
liste de fichiers. Empiler deux `dialogue_trigger` sur le même personnage ne
marcherait pas — les deux invites se superposeraient et l'appui sur la touche
irait à l'un ou à l'autre selon leur ordre dans l'arbre.

Sur le déclencheur, groupe **Plusieurs conversations** :

- **Dialogue Files** — la liste, dans l'ordre : la première rencontre, la
  deuxième, etc. Chaque fichier est indépendant, donc le premier contact peut
  n'avoir aucun rapport avec la suite. Ce champ est prioritaire sur
  *Dialogue File*, qui est alors ignoré.
- **Repeat Mode** — ce qui se passe une fois la liste épuisée :

| Mode | Effet |
| --- | --- |
| `SEQUENCE` | Dans l'ordre, puis **la dernière se répète** indéfiniment. C'est ce que tu veux dans presque tous les cas. |
| `RANDOM` | Une au hasard à chaque fois. Pour un PNJ qui lance une phrase différente à chaque passage. |
| `LOOP` | Dans l'ordre, puis on repart de la première. |

### Exemple : Vory

C'est ce qui est réglé sur Vory dans `scene_test`, avec deux fichiers
complètement différents :

| Fichier | Quand |
| --- | --- |
| [`vory_intro.txt`](vory_intro.txt) | La première fois qu'on lui parle. |
| [`vory_habituel.txt`](vory_habituel.txt) | Toutes les fois suivantes (mode `SEQUENCE`). |

Pour ajouter une troisième conversation — par exemple après une quête —,
ajoute simplement un fichier à la liste.

### Choisir la conversation depuis un script

Le rang courant vit en mémoire : si tu recharges la scène, le PNJ repart de sa
première conversation. Pour le piloter (sauvegarde, avancement de quête) :

```gdscript
var vory_trigger := $Vory/DialogueTrigger

vory_trigger.get_next_dialogue()   # le rang qui sera joué au prochain contact
vory_trigger.set_next_dialogue(2)  # le faire passer à sa 3e conversation
vory_trigger.reset()               # tout reprendre au début
```

### L'autre approche : un seul fichier

Si les conversations d'un PNJ se ressemblent et partagent des morceaux, tu peux
aussi tout garder dans un seul fichier et brancher avec des étiquettes et des
choix, comme dans `vory_intro.txt`. Mais la lecture commence toujours à la
première ligne : cette approche sert à embrancher **à l'intérieur** d'une
conversation, pas à en changer le début. Pour « la première fois, c'est
complètement autre chose », utilise la liste.

## Le PNJ pendant la conversation

Le déclencheur immobilise son interlocuteur et le tourne vers le joueur, puis
lui rend sa liberté à la fin. Réglages sur le déclencheur : **Speaker Path**
(vide = son parent), **Freeze Speaker**, **Speaker Faces Player**.

Ça marche avec n'importe quel personnage : il lui suffit d'avoir ces deux
méthodes, que le déclencheur n'appelle que si elles existent.

```gdscript
func set_frozen(frozen: bool) -> void:   # s'arrêter / repartir
func face_toward(point: Vector2) -> void: # se tourner vers un point du monde
```

Vory les implémente (`Scripts/Character/vory.gd`) : pendant le dialogue il
freine, garde son orientation, et son minuteur d'errance est mis en pause.

## Lancer un dialogue depuis du code

```gdscript
Dialogues.start_file("res://Dialogues/vory_intro.txt")
Dialogues.start_text("Vory: Salut !")
Dialogues.start(ma_ressource_dialogue)

if Dialogues.is_active():
    return
Dialogues.stop()
```

## Réagir à ce qui se dit

```gdscript
func _ready() -> void:
    Dialogues.event.connect(_on_dialogue_event)
    Dialogues.finished.connect(_on_dialogue_finished)

func _on_dialogue_event(name: StringName, arg: String) -> void:
    match name:
        &"marqueur_chemin":
            $Chemin.visible = true
        &"donne_objet":
            inventaire.ajouter(arg)

func _on_dialogue_finished(_dialogue: Dialogue) -> void:
    Dialogues.get_context()  # le déclencheur qui a lancé la conversation
```

Signaux disponibles : `started`, `finished`, `line_shown`, `choice_made`, `event`.

## Personnaliser l'apparence

Deux niveaux :

1. **Partout** — ouvre `Scenes/UI/dialogue_box.tscn` et modifie-la : le
   `StyleBoxFlat` du `Panel`, la police, la position et la hauteur de la boîte.
   Sur la racine : `type_speed`, `fade_time`, `continue_hint`,
   `advance_actions`, les trois tailles de texte (voir ci-dessous), et surtout
   **Portraits** et **Speaker Colors** — deux dictionnaires
   `nom du personnage → texture / couleur` qui donnent son visage et sa
   couleur à chaque personnage du jeu.

2. **Pour un seul niveau** — instancie `dialogue_box.tscn` dans ce niveau,
   règle-la comme tu veux, et ajoute sa racine au groupe **`dialogue_box`**.
   L'autoload l'utilisera à la place de la sienne.

### Taille du texte

Groupe **Tailles de texte** sur la racine de `dialogue_box.tscn` :

| Réglage | Quoi | Défaut |
| --- | --- | --- |
| `text_size` | Les répliques | 26 |
| `speaker_size` | Le nom du personnage | 30 |
| `choice_size` | Les options de choix | 24 |

La taille du « E » au-dessus des PNJ se règle à part, sur le `DialogueTrigger` :
`prompt_size` (30 par défaut).

### Hauteur de la boîte

Par défaut, `auto_height` est actif : la boîte se règle sur la hauteur de son
contenu. Elle reste basse pour une simple réplique et ne s'agrandit que pour un
texte long ou une liste de choix, donc elle ne mange jamais plus d'écran qu'il
ne faut. `min_height` (110 px) l'empêche de devenir riquiqui sur une réplique
d'un mot.

Décoche `auto_height` si tu préfères une hauteur constante : c'est alors
`offset_top` du `Panel`, dans la scène, qui la fixe.

## Pendant la conversation

`Dialogues.lock_player` (vrai par défaut) appelle `set_input_locked(true)` sur
tous les nœuds du groupe `player` : le joueur finit sa chute puis reste planté,
touches ignorées. `Dialogues.pause_tree` met en plus tout le reste en pause
(ennemis compris) ; la boîte, elle, continue de fonctionner.
