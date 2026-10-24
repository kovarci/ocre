# L'interface et le logo

[← Ocre](../../README.fr.md#documentation) · [English](../en/interface.md)

<p><img src="../img/fr/panneau.png" height="340" alt="Le panneau du clic droit"> <img src="../img/fr/apropos.png" height="340" alt="La fenêtre À propos"> <img src="../img/fr/osd.png" height="64" alt="La pastille à l'écran"></p>

## L'interface

Toutes les commandes — curseur, bascules, compteur, boutons, champs de
raccourci, drapeaux — sont **dessinées en GDI+** sur des `Picture`
([`lib/Ui.ahk`](../../lib/Ui.ahk), [`lib/Widgets.ahk`](../../lib/Widgets.ahk)). Ce n'est
pas de la coquetterie : dans une fenêtre sombre, le curseur et les cases à
cocher de Windows imposent leur bleu système, le champ numérique reste blanc,
et le contrôle `Hotkey` natif n'accepte ni option `Background` ni
`SetWindowTheme`. Les dessiner est le seul moyen de tenir une palette.

Le clic droit n'ouvre pas un menu Windows mais un panneau à nous
([`lib/Panneau.ahk`](../../lib/Panneau.ahk)) : la hauteur de ligne, la police, les
marges et les coins d'un menu système ne sont pas négociables, et le résultat
détonnait à côté d'une fenêtre entièrement peinte. Le panneau porte en prime le
curseur d'intensité, ce qu'un menu ne saurait faire. Il se ferme à la perte du
focus, comme un menu — AutoHotkey n'exposant pas d'événement de désactivation,
un minuteur surveille la fenêtre active.

Deux précautions gouvernent ce dessin :

- Un `Gui` met ses coordonnées à l'échelle du facteur d'affichage. Une image
  peinte à la taille demandée serait étirée : on interroge donc la taille
  **réelle** du contrôle et l'on peint à cette résolution.
- Le survol n'existe pas sur une `Picture`. Un minuteur unique relève la
  position de la souris et redessine les zones concernées.

Le clavier non plus : une `Picture` ne reçoit aucune touche. Les flèches,
`Tab`, `Origine`, `Fin` et `Échap` passent par des raccourcis conditionnés à
la fenêtre active (`HotIfWinActive`), qui ne vivent que tant que la nôtre a
le focus et ne prennent rien à personne. L'anneau qui marque le curseur visé
n'apparaît qu'à la première touche, comme le fait Windows : à la souris,
personne n'a besoin de savoir lequel des deux répondrait aux flèches.

La fenêtre des réglages se tire par ses bords comme n'importe quelle autre,
alors que son contenu est peint à coordonnées fixes. Les deux ne se
contredisent pas : le contenu vit dans une fenêtre enfant (`WS_CHILD`) que
porte un cadre redimensionnable ([`lib/Cadre.ahk`](../../lib/Cadre.ahk)). Plus
large, le cadre centre le contenu, comme les réglages de Windows centrent
leur colonne ; moins haut, il le fait défiler par un ascenseur — molette,
flèches de l'ascenseur, poignée — comme un navigateur fait défiler une page.
Rien n'est étiré : un curseur de 276 points reste un curseur de 276 points.
À la première ouverture, la fenêtre prend la hauteur du contenu, bornée à
l'écran ; ensuite elle garde la taille qu'on lui a donnée (`taille_reglages`
dans `ocre.ini`). Les quatre autres fenêtres — planificateur, raccourcis,
préréglages, lieu — sont portées par le même cadre, avec chacune sa clé. Les raccourcis de la fenêtre — flèches, Tab, Échap — se
conditionnent sur le cadre, qui est la fenêtre active ; c'est le seul endroit
où l'enfant se voit.

Les champs de raccourci lisent la touche par un `InputHook`, ce qui permet
d'affecter la touche Windows — que le contrôle natif refuse. `InputHook`
préfixe ses modificateurs de `<` ou `>` pour distinguer gauche et droite ; ces
préfixes n'ont pas de sens dans une définition de raccourci et sont retirés.

Les textes vivent dans [`lib/I18n.ahk`](../../lib/I18n.ahk), **encodé en UTF-8 avec
BOM** : sans lui AutoHotkey lirait les accents en ANSI. Les autres fichiers
restent en ASCII pur.

## Le logo

Une tache organique définie par neuf rayons polaires lissés par une courbe
fermée. Sa couleur suit l'intensité du filtre : gris bleuté quand le filtre est
coupé, ambre à mi-course, ocre brûlée à fond.

La même table de rayons sert des deux côtés : [`lib/Blob.ahk`](../../lib/Blob.ahk)
la dessine à chaud pour la zone de notification, la pastille et la fenêtre ;
[`tools/make-icon.ps1`](../../tools/make-icon.ps1) la dessine en System.Drawing pour
produire `Ocre.ico`, l'icône de l'exécutable.

Une icône ou un bitmap passé à AutoHotkey sous la forme `HICON:*` ou
`HBITMAP:*` — avec l'astérisque — lui fait prendre une **copie** ; l'original
reste à nous, et à détruire. On l'a cru longtemps l'inverse, et chaque
redessin de l'icône, chaque survol d'un bouton laissait trois objets GDI et
un objet USER derrière lui : deux mille cinq cents de plus par jour de
molette, et Windows tue un processus à dix mille. C'est `test-fuites` qui l'a
vu, le jour de son écriture. `Blob.Poser`, `Blob.Tray` et `Dessin.Poser`
font depuis les choses dans l'ordre : poser, puis détruire.

Dans la zone de notification, un petit disque clair dans le coin de la tache
dit que l'horaire est suspendu par un réglage à la main — un état que la
couleur ne montre pas, et qu'on ne devrait pas avoir à survoler l'icône pour
connaître. Il disparaît au basculement suivant, ou par *Reprendre l'horaire*
dans le panneau.

Le `.ico` mélange deux formats à dessein : DIB non compressé jusqu'à 64 px,
PNG au-delà. `System.Drawing` refuse de relire les entrées PNG en dessous de
256 px, et certains outils de ressources aussi.

### Le bouton de la barre des tâches

Il reste à l'orange de l'exe, et ce n'est pas un oubli. Poser l'icône
teintée sur la fenêtre (`WM_SETICON`) ne change rien : mesuré sur Windows
11, la barre l'ignore, en 32 comme en 256 px, icône de classe comprise. La
seule voie qui marche — la propriété `RelaunchIconResource` de la fenêtre,
avec un `.ico` sur disque — n'est lue qu'à la création du bouton, et la
faire relire à chaud impose soit de faire clignoter la fenêtre, soit de
changer l'identifiant d'application, ce qui envoie le bouton en fin de
barre. Un bouton fixe vaut mieux qu'un bouton qui saute.
