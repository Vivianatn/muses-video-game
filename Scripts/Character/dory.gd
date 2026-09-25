@tool
extends Vory
class_name Dory

## Dory : personnage non joueur. Il reprend tout le comportement de Vory
## (gravité, errance marche / pause, demi-tour devant un mur ou au bord d'un
## vide, immobilisation pendant un dialogue) : voir Scripts/Character/vory.gd.
##
## Ses réglages (vitesse, durées d'errance, rayon de patrouille...) se font
## dans l'inspecteur de sa scène, indépendamment de ceux de Vory. Ce qui lui
## est propre s'ajoute ici.
