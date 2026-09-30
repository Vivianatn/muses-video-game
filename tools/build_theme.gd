extends SceneTree

## Construit Scenes/UI/muses_theme.tres, le thème de toute l'interface, à
## partir de la DA (Scripts/UI/muses.gd). Il est branché dans Projet →
## Paramètres du projet → GUI → Thème → Personnalisé : tous les Control du jeu
## le reçoivent, y compris sous un CanvasLayer.
##
## À relancer après un changement de la DA. Les retouches faites à la main
## dans le .tres seraient écrasées : c'est ici qu'on règle le thème.
##   godot --headless --path . -s tools/build_theme.gd
##
## Variations de type (champ « Theme Type Variation » d'un nœud) :
##   Button        (défaut) bouton principal, un seul par écran
##                 BoutonSecondaire, Filtre, Choix, Emplacement, EmplacementVide
##   Label         (défaut) récit ; TitreEcran, TitreEtage, TitrePanneau,
##                 SousTitre, NomObjet, Legende, HudEtiquette, HudValeur,
##                 Categorie, Quantite, Touche
##   RichTextLabel (défaut) récit ; Dialogue
##   PanelContainer (défaut) panneau ; PanneauEntete, Entete, EnteteCompact,
##                 Notification
##
## Tous les styles sont des StyleBoxFlat natifs (coins coupés par
## corner_detail = 1). Un StyleBox scripté ne convient pas : Godot charge le
## thème du projet avant l'arbre de scène, et lancé depuis l'éditeur, le
## débogueur se plaint alors de chaque script exécuté.
## Les styles en capitales (titres, boutons, HUD) ne le deviennent pas tout
## seuls : cocher « Uppercase » sur le Label, ou écrire le texte en capitales.

const OUTPUT := "res://Scenes/UI/muses_theme.tres"

var _chakra: FontFile = load("res://Fonts/ChakraPetch-SemiBold.ttf")
var _chakra_bold: FontFile = load("res://Fonts/ChakraPetch-Bold.ttf")
var _silkscreen: FontFile = load("res://Fonts/Silkscreen-Regular.ttf")
var _barlow: FontFile = load("res://Fonts/Barlow-Regular.ttf")
var _barlow_italic: FontFile = load("res://Fonts/Barlow-Italic.ttf")
var _barlow_bold: FontFile = load("res://Fonts/Barlow-Bold.ttf")
var _barlow_bold_italic: FontFile = load("res://Fonts/Barlow-BoldItalic.ttf")

var _theme := Theme.new()


func _init() -> void:
	_build()
	var error := ResourceSaver.save(_theme, OUTPUT)
	if error != OK:
		push_error("Thème non écrit (%s) : %s" % [OUTPUT, error_string(error)])
	else:
		print("Thème écrit : ", OUTPUT)
	quit(error)


func _build() -> void:
	# Chakra Petch : titres et boutons, toujours en capitales espacées.
	var display := _spaced(_chakra, 2)
	var display_1 := _spaced(_chakra, 1)
	var display_3 := _spaced(_chakra, 3)
	var display_bold := _spaced(_chakra_bold, 4)
	# Silkscreen : le HUD et les petites étiquettes techniques, jamais une phrase.
	var pixel := _silkscreen
	# Barlow : tout ce qui se lit, dialogues compris. Une sans-serif sobre et
	# très lisible, légèrement industrielle, qui s'accorde à Chakra Petch.
	var body := _barlow
	var body_bold := _barlow_bold
	var body_bold_italic := _barlow_bold_italic
	var speech := body
	var speech_bold := body_bold
	var speech_bold_italic := body_bold_italic

	_theme.default_font = body
	_theme.default_font_size = 18

	# --- Textes -----------------------------------------------------------
	_label(&"Label", body, 18, 26, Muses.PARCHEMIN)
	_label(&"TitreEcran", display_bold, 48, 52, Muses.PARCHEMIN)
	_label(&"TitreEtage", display_3, 32, 36, Muses.PARCHEMIN)
	_label(&"TitrePanneau", display, 18, 24, Muses.PARCHEMIN)
	_label(&"SousTitre", display, 15, 20, Muses.CUIVRE)
	_label(&"NomObjet", display_1, 15, 20, Muses.PARCHEMIN)
	_label(&"Legende", body, 15, 20, Muses.ARGILE)
	_label(&"HudEtiquette", pixel, 12, 16, Muses.ARGILE)
	_label(&"HudValeur", pixel, 16, 20, Muses.PARCHEMIN)
	_label(&"Categorie", pixel, 12, 16, Muses.SEVE)
	_label(&"Quantite", pixel, 12, 16, Muses.PARCHEMIN)
	# Une touche à presser (au-dessus d'un PNJ...) : un petit bouton principal,
	# face bordeaux-clair et relief.
	_label(&"Touche", pixel, 16, 20, Muses.PARCHEMIN)
	_theme.set_stylebox(&"normal", &"Touche", _chamfer(Muses.BORDEAUX_CLAIR, Muses.CHANFREIN_SM, true, [12, 6, 12, 6]))

	var rich := &"RichTextLabel"
	_theme.set_color(&"default_color", rich, Muses.PARCHEMIN)
	_theme.set_font(&"normal_font", rich, body)
	_theme.set_font(&"italics_font", rich, _barlow_italic)
	_theme.set_font(&"bold_font", rich, body_bold)
	_theme.set_font(&"bold_italics_font", rich, body_bold_italic)
	_theme.set_font(&"mono_font", rich, pixel)
	for size_name in [&"normal_font_size", &"italics_font_size", &"bold_font_size",
			&"bold_italics_font_size", &"mono_font_size"]:
		_theme.set_font_size(size_name, rich, 18)
	_theme.set_constant(&"line_separation", rich, _line_gap(body, 18, 26))

	# Les répliques des dialogues.
	var dialogue := &"Dialogue"
	_variation(dialogue, rich)
	_theme.set_color(&"default_color", dialogue, Muses.PARCHEMIN)
	_theme.set_font(&"normal_font", dialogue, speech)
	_theme.set_font(&"italics_font", dialogue, _barlow_italic)
	_theme.set_font(&"bold_font", dialogue, speech_bold)
	_theme.set_font(&"bold_italics_font", dialogue, speech_bold_italic)
	for size_name in [&"normal_font_size", &"italics_font_size", &"bold_font_size",
			&"bold_italics_font_size"]:
		_theme.set_font_size(size_name, dialogue, 19)
	_theme.set_constant(&"line_separation", dialogue, _line_gap(speech, 19, 26))

	# --- Boutons ----------------------------------------------------------
	# Principal : face bordeaux-clair, relief. Survol brique, appui bordeaux.
	_button(&"Button", display, 15, [Muses.BORDEAUX_CLAIR, Muses.BRIQUE, Muses.BORDEAUX], true, Muses.ESPACE_2)
	# Secondaire : face surface, survol racine. Onglet choisi : bordeaux.
	var secondary := [Muses.SURFACE, Muses.RACINE, Muses.BORDEAUX]
	_button(&"BoutonSecondaire", display, 15, secondary, false, Muses.ESPACE_2)
	# Filtre de l'inventaire : un secondaire en police pixel, plus étroit.
	_button(&"Filtre", pixel, 12, secondary, false, 12)
	# Option de dialogue : un secondaire en Barlow, face translucide pour
	# laisser voir le jeu (les choix flottent à gauche de l'écran).
	_button(&"Choix", speech, 19, [Color(Muses.SURFACE, 0.72), Color(Muses.RACINE, 0.85),
			Color(Muses.BORDEAUX, 0.9)], false, Muses.ESPACE_2)
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		(_theme.get_stylebox(state, &"Choix") as StyleBoxFlat).border_color = Color(Muses.CUIVRE, 0.85)
	# Case d'inventaire : fond surface (occupée) ou racine (vide), l'icône
	# de 40 px au centre. Seul le focus la change : contour sève.
	_button(&"Emplacement", pixel, 12, [Muses.SURFACE, Muses.SURFACE, Muses.SURFACE], false, 12)
	_button(&"EmplacementVide", pixel, 12, [Muses.RACINE, Muses.RACINE, Muses.RACINE], false, 12)
	for type in [&"Emplacement", &"EmplacementVide"]:
		for margin in [SIDE_TOP, SIDE_BOTTOM]:
			for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
				_theme.get_stylebox(state, type).set_content_margin(margin, 12)

	# Interrupteur (plein écran...) : une ligne secondaire et son curseur.
	var check := &"CheckButton"
	_button(check, display, 15, [Muses.SURFACE, Muses.RACINE, Muses.SURFACE], false, Muses.ESPACE_2)
	_theme.set_stylebox(&"hover_pressed", check, _theme.get_stylebox(&"hover", check))
	_theme.set_icon(&"checked", check, load("res://Sprites/UI/interrupteur_on.svg"))
	_theme.set_icon(&"unchecked", check, load("res://Sprites/UI/interrupteur_off.svg"))
	_theme.set_icon(&"checked_disabled", check, load("res://Sprites/UI/interrupteur_on_desactive.svg"))
	_theme.set_icon(&"unchecked_disabled", check, load("res://Sprites/UI/interrupteur_off_desactive.svg"))

	# Curseur (volume...) : une piste de circuit, sève jusqu'au curseur.
	var slider := &"HSlider"
	_theme.set_stylebox(&"slider", slider, _flat(Muses.RACINE, 3))
	_theme.set_stylebox(&"grabber_area", slider, _flat(Muses.SEVE, 3))
	_theme.set_stylebox(&"grabber_area_highlight", slider, _flat(Muses.SEVE, 3))
	_theme.set_stylebox(&"focus", slider, _focus_ring(Muses.CHANFREIN_SM))
	_theme.set_icon(&"grabber", slider, load("res://Sprites/UI/curseur.svg"))
	_theme.set_icon(&"grabber_highlight", slider, load("res://Sprites/UI/curseur_survol.svg"))
	_theme.set_icon(&"grabber_disabled", slider, load("res://Sprites/UI/curseur_desactive.svg"))

	# Barres de défilement : un creux racine, une poignée cuivre, sève tenue.
	for bar in [&"VScrollBar", &"HScrollBar"]:
		_theme.set_stylebox(&"scroll", bar, _flat(Muses.RACINE, 4))
		_theme.set_stylebox(&"scroll_focus", bar, _flat(Muses.RACINE, 4))
		_theme.set_stylebox(&"grabber", bar, _flat(Muses.CUIVRE, 4))
		_theme.set_stylebox(&"grabber_highlight", bar, _flat(Muses.CUIVRE, 4))
		_theme.set_stylebox(&"grabber_pressed", bar, _flat(Muses.SEVE, 4))

	# --- Panneaux ---------------------------------------------------------
	var m := Muses.TRAIT + Muses.ESPACE_3
	var panel := _chamfer(Muses.SURFACE, Muses.CHANFREIN_MD, true, [m, m, m, m])
	_theme.set_stylebox(&"panel", &"PanelContainer", panel)
	_theme.set_stylebox(&"panel", &"Panel", panel)
	# Panneau à en-tête : le contenu (Entete, Circuit, marges) touche le cadre.
	_variation(&"PanneauEntete", &"PanelContainer")
	var t := Muses.TRAIT
	_theme.set_stylebox(&"panel", &"PanneauEntete", _chamfer(Muses.SURFACE, Muses.CHANFREIN_MD, true, [t, t, t, t]))
	# En-tête bordeaux, dont le coin suit le biseau du panneau.
	_variation(&"Entete", &"PanelContainer")
	_theme.set_stylebox(&"panel", &"Entete", _header([Muses.ESPACE_3, Muses.ESPACE_1, Muses.ESPACE_3, Muses.ESPACE_1]))
	# En-tête resserré, pour la boîte de dialogue qui doit rester basse.
	_variation(&"EnteteCompact", &"PanelContainer")
	_theme.set_stylebox(&"panel", &"EnteteCompact", _header([Muses.ESPACE_3, 4, Muses.ESPACE_3, 4]))
	# Bandeau de notification : un panneau compact.
	_variation(&"Notification", &"PanelContainer")
	_theme.set_stylebox(&"panel", &"Notification", _chamfer(Muses.SURFACE, Muses.CHANFREIN_MD, true,
			[t + Muses.ESPACE_3, t + Muses.ESPACE_2, t + Muses.ESPACE_3, t + Muses.ESPACE_2]))

	# Infobulle : cadre cuivre, fond nuit, jamais d'action dedans.
	_theme.set_stylebox(&"panel", &"TooltipPanel", _chamfer(Muses.NUIT, Muses.CHANFREIN_SM, false,
			[t + Muses.ESPACE_2, t + Muses.ESPACE_1, t + Muses.ESPACE_2, t + 12]))
	_theme.set_font(&"font", &"TooltipLabel", display_1)
	_theme.set_font_size(&"font_size", &"TooltipLabel", 15)
	_theme.set_color(&"font_color", &"TooltipLabel", Muses.PARCHEMIN)


# --- Outils ---------------------------------------------------------------

## Chakra Petch avec l'espacement des lettres de la DA (letterSpacing).
func _spaced(font: FontFile, spacing: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = font
	variation.spacing_glyph = spacing
	return variation


## Déclare une variation, sauf pour une classe de Godot (Label, CheckButton...)
## qui se règle directement.
func _variation(type: StringName, base: StringName) -> void:
	if not ClassDB.class_exists(type):
		_theme.set_type_variation(type, base)


## Un style de texte : police, taille, hauteur de ligne de la DA, couleur.
func _label(type: StringName, font: Font, size: int, line_height: int, color: Color) -> void:
	_variation(type, &"Label")
	_theme.set_font(&"font", type, font)
	_theme.set_font_size(&"font_size", type, size)
	_theme.set_color(&"font_color", type, color)
	_theme.set_constant(&"line_spacing", type, _line_gap(font, size, line_height))


## Écart à ajouter entre deux lignes pour tomber sur la hauteur de la DA.
func _line_gap(font: Font, size: int, line_height: int) -> int:
	return line_height - roundi(font.get_height(size))


## Un type de bouton. `faces` = [repos, survol, appui]. La hauteur atteint
## juste 48 px, la taille minimale d'une cible.
func _button(type: StringName, font: Font, size: int, faces: Array, relief: bool, padding: int) -> void:
	_variation(type, &"Button")
	var h := Muses.TRAIT + padding
	var v := maxf((Muses.CIBLE_MIN - font.get_height(size)) * 0.5, Muses.TRAIT)
	var margins := [h, v, h, v]
	_theme.set_stylebox(&"normal", type, _chamfer(faces[0], Muses.CHANFREIN_SM, relief, margins))
	_theme.set_stylebox(&"hover", type, _chamfer(faces[1], Muses.CHANFREIN_SM, relief, margins))
	_theme.set_stylebox(&"pressed", type, _chamfer(faces[2], Muses.CHANFREIN_SM, relief, margins))
	_theme.set_stylebox(&"hover_pressed", type, _chamfer(faces[2], Muses.CHANFREIN_SM, relief, margins))
	# Désactivé : face et contour racine, sans relief.
	var disabled := _chamfer(Muses.RACINE, Muses.CHANFREIN_SM, false, margins)
	disabled.border_color = Muses.RACINE
	_theme.set_stylebox(&"disabled", type, disabled)
	# Focus (clavier, manette) : le contour passe au sève.
	_theme.set_stylebox(&"focus", type, _focus_ring(Muses.CHANFREIN_SM))

	_theme.set_font(&"font", type, font)
	_theme.set_font_size(&"font_size", type, size)
	for color_name in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_hover_pressed_color", &"font_focus_color"]:
		_theme.set_color(color_name, type, Muses.PARCHEMIN)
	_theme.set_color(&"font_disabled_color", type, Muses.ARGILE)
	_theme.set_constant(&"h_separation", type, Muses.ESPACE_1)
	_theme.set_constant(&"outline_size", type, 0)


## Un cadre de la DA : face, contour cuivre, coins haut-gauche et bas-droit
## coupés (corner_detail = 1 change l'arrondi en biseau). Le relief est une
## ombre décalée de 1 px de fondu seulement : nette à l'œil.
func _chamfer(face: Color, cut: float, relief: bool, margins: Array) -> StyleBoxFlat:
	var box := _cut(cut)
	box.bg_color = face
	box.border_color = Muses.CUIVRE
	box.set_border_width_all(int(Muses.TRAIT))
	if relief:
		box.shadow_color = Muses.RACINE
		box.shadow_size = 1
		box.shadow_offset = Muses.RELIEF
	_margins(box, margins)
	return box


## Focus (clavier, manette) : dessiné par-dessus le cadre, il remplace son
## contour cuivre par un contour sève.
func _focus_ring(cut: float) -> StyleBoxFlat:
	var box := _cut(cut)
	box.draw_center = false
	box.border_color = Muses.SEVE
	box.set_border_width_all(int(Muses.TRAIT))
	return box


## En-tête bordeaux d'un panneau, dont le coin suit le biseau du cadre.
func _header(margins: Array) -> StyleBoxFlat:
	var box := _cut(Muses.CHANFREIN_MD - Muses.TRAIT, false)
	box.bg_color = Muses.BORDEAUX
	_margins(box, margins)
	return box


func _cut(cut: float, bottom_right: bool = true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.corner_detail = 1
	box.corner_radius_top_left = int(cut)
	box.corner_radius_bottom_right = int(cut) if bottom_right else 0
	return box


## Aplat simple, pour les pistes fines (curseur, défilement).
func _flat(color: Color, thickness: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_content_margin_all(thickness)
	return box


## [gauche, haut, droite, bas]
func _margins(box: StyleBox, margins: Array) -> void:
	box.content_margin_left = margins[0]
	box.content_margin_top = margins[1]
	box.content_margin_right = margins[2]
	box.content_margin_bottom = margins[3]
