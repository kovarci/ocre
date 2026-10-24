# Utiliser Ocre

[← Ocre](../../README.fr.md#documentation) · [English](../en/usage.md)

<p><img src="../img/fr/panneau.png" height="340" alt="Le panneau du clic droit"> <img src="../img/fr/osd.png" height="64" alt="La pastille à l'écran"></p>

Filtre de lumière chaude piloté au clavier, sur Windows 11.

| | Jeu principal | Jeu de secours |
|---|---|---|
| filtre moins fort | `Ctrl+F5` | `Ctrl+Alt+Retour arrière` |
| filtre plus fort | `Ctrl+F6` | `Ctrl+Alt+Entrée` |
| coupe / rétablit | `Ctrl+F7` | `Ctrl+Alt+Espace` |

Les deux jeux sont actifs en même temps et entièrement reconfigurables. Le
principal exige que le Fn-lock du portable soit en mode *touche de fonction*
(voir plus bas) ; le secours n'utilise aucune touche de fonction et marche
partout.

`Ctrl+Alt` + **molette de la souris** ajuste l'intensité en continu : un
réglage de ce genre se cherche plutôt qu'il ne se saisit, et aucune touche ne
donne cette progressivité. La même molette avec **`Maj`** en plus règle la
luminosité. Et la molette **sur l'icône** près de l'heure, sans rien d'autre,
règle l'intensité aussi.

Un **clic gauche** sur l'icône ouvre les réglages, un **clic droit** un petit
panneau où l'on règle l'intensité, la luminosité et trois préréglages sans rien
ouvrir, un **clic du milieu** coupe ou rétablit le filtre — Ctrl+F7 pour qui
a la main sur la souris. Interface en français et en anglais.

L'intensité s'affiche en **pour cent ou en Kelvin** — 3400 K parle à qui
vient de f.lux ou du Night Light, 58 % ne dit rien. Un clic sur la valeur, en
haut du panneau du clic droit, bascule de l'un à l'autre ; c'est le seul
endroit où cela se choisit. Seul l'affichage change : le curseur, les
raccourcis et le fichier de configuration comptent toujours en pour cent.

Dans les fenêtres, les **flèches** règlent le curseur visé, `Tab` passe de
l'un à l'autre, `Origine` et `Fin` vont aux bornes, `Échap` ferme.

Tout se pilote aussi en ligne de commande — `Ocre.exe /set 40`, `/kelvin
3400`, `/preset nuit`, `/get` — pour un boîtier à boutons ou une macro.
