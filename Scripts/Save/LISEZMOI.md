# Menu, inventaire et sauvegarde

## Les pièces

| Fichier | Autoload | Rôle |
| --- | --- | --- |
| `Scripts/UI/game_menu.gd` | `GameMenu` | Le menu : pause, inventaire, sauvegarder, charger, quitter. |
| `Scripts/Inventory/inventory.gd` | `Inventory` | Les quantités d'objets possédés. |
| `Scripts/Items/item_data.gd` | — | La fiche d'un objet (`ItemData`). |
| `Items/*.tres` | — | Les fiches, chargées toutes seules au démarrage. |
| `Scripts/Save/save_game.gd` | `SaveGame` | Écriture, lecture et emplacements de sauvegarde. |

## Touches

| Action | Clavier | Manette | Effet |
| --- | --- | --- | --- |
| `menu` | Échap | Start | Ouvre / ferme le menu. |
| `inventory` | I | Select (View) | Ouvre directement l'inventaire. |
| `menu_back` | Retour arrière | **B** | Ferme la fenêtre du dessus (la dernière ferme le menu). |
| `ui_accept` | Entrée, Espace | **A** | Valide. |

Déplacement dans les menus : flèches, croix ou stick gauche. Le menu ne s'ouvre
pas pendant un dialogue. Le jeu est en pause tant qu'il est ouvert.

## Ajouter un objet

1. Dans `Items/`, clic droit → **Nouvelle ressource** → `ItemData`.
2. Remplis **Id** (unique, sans espace, à ne plus changer ensuite),
   **Display Name**, **Description**, **Icon**.
3. Facultatif : **Max Count** (plafond), **Sort Order** (ordre dans
   l'inventaire), **Dialogue Var** (variable de dialogue tenue à jour avec la
   quantité, pour écrire `{connaissances}` ou `[si connaissances >= 3]`).
4. Pour un objet à ramasser dans un niveau : duplique
   `Scenes/Collectable/connaissance.tscn`, change son sprite et mets l'**Id**
   de la fiche dans **Item Id**.

```gdscript
Inventory.add(&"connaissance")        # renvoie la quantité réellement ajoutée
Inventory.remove(&"connaissance", 2)  # false s'il n'y en a pas assez
Inventory.count(&"connaissance")
Inventory.has(&"connaissance", 3)
Inventory.changed.connect(func(id, count): print(id, " : ", count))
```

## La sauvegarde

### Ce qui est enregistré

- le niveau en cours, la position, la vie et l'orientation du joueur ;
- l'inventaire ;
- toutes les variables de dialogue ;
- l'état des éléments du monde : objets ramassés, ennemis vaincus, avancement
  des conversations de chaque PNJ ;
- pour le menu : date, temps de jeu, nom du lieu et une miniature de l'écran.

### Emplacements

- **1 à 3** : sauvegardes manuelles, depuis le menu (`slot_count` sur
  l'autoload pour en changer le nombre).
- **Sauvegarde automatique** : toutes les 5 minutes de jeu, hors pause et hors
  dialogue (`autosave_interval`, 0 pour la couper). Elle se charge depuis le
  menu comme les autres. `SaveGame.autosave()` en force une, par exemple en
  entrant dans une nouvelle zone.

Les fichiers sont dans `user://saves/`, c'est-à-dire sous Windows
`%APPDATA%\Godot\app_userdata\Muses\saves\`.

### Solidité

- **Écriture sûre** : la sauvegarde est d'abord écrite dans un `.tmp`, relue
  et vérifiée, et seulement alors elle remplace l'ancienne. Une coupure en
  pleine écriture ne détruit jamais la dernière sauvegarde valide.
- **Copie de secours** : la sauvegarde précédente est gardée en `.bak`. Si le
  fichier principal est abîmé, c'est elle qui est chargée, et le menu l'indique.
- **Somme de contrôle** (SHA-256) : un fichier abîmé ou modifié à la main est
  détecté et signalé « Fichier abîmé » au lieu de planter le jeu.
- **Pas de code exécuté au chargement** : les données ne contiennent aucun
  objet, un fichier trafiqué ne peut rien lancer.
- **Version du format** : chaque fichier porte `FORMAT_VERSION`. Le jour où la
  structure change, augmente-la et convertis les anciennes données dans
  `_migrate()` : les sauvegardes des joueurs restent lisibles.

### Nom du lieu

Le menu affiche le nom du nœud racine du niveau (« Scene_test »). Pour un vrai
nom, ajoute sur ce nœud une métadonnée `level_name` (inspecteur, tout en bas →
**Ajouter une métadonnée**), par exemple « Ruines de la forêt ».

### Rendre un élément sauvegardable

N'importe quel nœud d'un niveau peut retenir son état :

```gdscript
func _ready() -> void:
    SaveGame.register(self)   # applique tout de suite l'état sauvegardé s'il y en a un

func save_state() -> Dictionary:
    return {"ouvert": _ouvert}

func load_state(data: Dictionary) -> void:
    _ouvert = data.get("ouvert", false)
```

Pour un nœud qui **disparaît** (objet ramassé, ennemi vaincu, porte détruite),
appelle aussi `SaveGame.store(self, {...})` au moment où ça arrive : une fois
libéré, on ne peut plus lui demander son état. C'est ce que font
`collectable.gd` et `ennemy_walker.gd`.

L'état est rangé sous « niveau + chemin du nœud ». **Renommer ou déplacer un
nœud dans l'arbre lui fait perdre son état** dans les sauvegardes existantes.

### Depuis un script

```gdscript
SaveGame.save_slot(1)
await SaveGame.load_slot(1)
SaveGame.latest_slot()        # la plus récente, pour un bouton « Continuer » (-1 si aucune)
SaveGame.get_slot_info(1)     # exists, corrupted, saved_at, playtime, location, thumbnail
SaveGame.delete_slot(1)
SaveGame.playtime             # temps de jeu en secondes

SaveGame.saved.connect(...)   # signaux : saved, loaded, failed
```
