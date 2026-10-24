# Le planificateur

[← Ocre](../../README.fr.md#documentation) · [English](../en/scheduler.md)

<p><img src="../img/fr/planificateur-soleil.png" height="260" alt="Le planificateur, qui suit le soleil"> <img src="../img/fr/planificateur-fixe.png" height="230" alt="Le planificateur, heures fixes"> <img src="../img/fr/lieu.png" height="260" alt="Le choix d'un lieu"></p>

Deux moments dans la journee : celui ou la montee vers l'intensite de nuit
commence, celui ou la descente vers celle de jour commence. Entre les deux,
rien ne bouge.

Le fondu est long a dessein -- trois heures par defaut, la ou les outils du
genre proposent vingt secondes ou une heure. A cette duree l'intensite monte
d'un point toutes les trois minutes : l'oeil suit sans jamais rien remarquer,
et c'est tout l'interet. Un fondu court, lui, se remarque, et c'est precisement
ce qu'on reproche a ces outils.

Il est **coupe par defaut**. Regler son filtre a la main est une preference
parfaitement legitime, et un programme qui bouge tout seul le premier soir se
fait desinstaller le lendemain.

Un reglage a la main pendant un fondu suspend le planificateur jusqu'au
basculement suivant : sans cela la valeur choisie serait reprise trois minutes
plus tard, ce qui donne l'impression d'un programme qui se bat contre son
utilisateur.

La suspension se voit : l'infobulle de l'icone dit « horaire suspendu jusqu'a
07:00 », et le panneau du clic droit porte alors une ligne *Reprendre
l'horaire* qui repose l'intensite de l'heure sans attendre. Un planificateur
qui se tait sans le dire passe pour un planificateur en panne.

L'intensite de jour n'a pas de commande dans la fenetre : elle vaut zero,
c'est-a-dire filtre coupe, dans a peu pres tous les cas ou l'on veut un
horaire. Qui tient a un fond de filtre en pleine journee pose `h_jour` dans
`ocre.ini`.

## Caler sur le soleil

Un horaire fixe derive, et c'est le seul defaut serieux du planificateur tel
qu'il etait. A Paris le soleil se couche a **17:00 en decembre et a 21:55 en
juin** : une montee calee sur 21:00 toute l'annee est quatre heures trop tard
la moitie du temps. Le fondu de trois heures perd alors l'ancrage qui le
justifie -- il derive de plus que sa propre duree.

Le mode *Soleil*, en tete de la fenetre du planificateur -- a cote de
*Manuel* et *Heures fixes* --, remplace les deux heures par deux decalages :
tant de minutes apres le coucher, tant de minutes apres le lever. Zero par
defaut, negatif si l'on veut commencer avant. Les trois modes etaient
repartis entre une bascule ici et une la-bas, et il fallait les deux pour
savoir ou l'on en etait ; la bascule *Suivre un horaire* de la fenetre
principale reste, et suit -- elle vaut « pas manuel ».

Le calcul est celui de la NOAA, dans [`lib/Soleil.ahk`](../../lib/Soleil.ahk). Il ne
demande que la date et un point sur le globe : **pas de reseau, pas de service,
rien a tenir a jour**. Le zenith retenu est 90,833 degres -- les 90 degres
geometriques plus 0,833 pour la refraction atmospherique et le demi-diametre du
disque, ce qui est la convention du lever et du coucher officiels.

Il se fait en deux passes. La premiere prend la position du soleil a 0 h UTC,
ce qui suffit sous nos latitudes. Plus haut, l'astre rase l'horizon : il y
passe une heure la ou il met dix minutes a Paris, et la declinaison a minuit
n'est plus celle du coucher. Mesure contre une implementation independante :
**4 minutes d'erreur a Tromso et a Reykjavik en septembre, ramenees a une seule
par la seconde passe**, qui recalcule la position a l'heure trouvee par la
premiere.

[`tools/test-soleil.ahk`](../../tools/test-soleil.ahk) verifie dix-huit cas contre
des valeurs produites par la bibliotheque Python *astral*, qui implemente le
meme algorithme depuis la publication d'origine : comparer une transcription a
une autre est ce qui attrape les fautes de recopie. Sept lieux, choisis pour
les pieges -- hemisphere sud, equateur, longitudes negatives, et Tromso ou le
soleil ne se leve ni ne se couche aux solstices. Tout tombe a deux minutes,
d'Ushuaia a Tromso.

Au-dela des cercles polaires, il arrive qu'il n'y ait ni lever ni coucher. Les
heures fixes reprennent alors la main : elles ne veulent pas dire grand-chose
la-bas non plus, mais elles ne laissent pas le planificateur sans reperes.

## Ou vous etes

Le calcul veut une latitude et une longitude, que personne ne connait par
coeur. La fenetre du lieu accepte donc un nom de ville -- « Lyon », « Lyon,
France », « Lyon, FR » -- ou les coordonnees directement.

La table est embarquee : **26 700 villes de plus de 20 000 habitants**, issues
de GeoNames, triees par population decroissante -- ce tri EST le classement des
resultats, taper « par » doit donner Paris avant Paranagua. Rien ne part sur le
reseau, ni a l'installation ni a l'usage.

Deux details de format ont coute cher et meritent d'etre dits.

**L'echappement.** La table a d'abord ete un litteral dans `Villes.ahk`.
AutoHotkey traite les sequences d'echappement d'une section de continuation
caractere par caractere : sur 700 Ko, cela ajoutait **1,1 seconde au
demarrage**, mesuree au chronometre sur cinq lancements -- pour une
application qui s'initialise en 0,35 s et se bat deja contre la file de
demarrage de Windows. L'option accent grave les desactivait, et le meme
fichier ne coutait plus que **33 ms**.

**Puis plus rien.** Trente-trois millisecondes a chaque demarrage pour une
fenetre qu'on ouvre une fois, c'etait encore trente-trois de trop. La table
vit maintenant dans [`lib/villes.txt`](../../lib/villes.txt), un enregistrement par
ligne, et n'est lue qu'a la premiere recherche : un fichier a cote du script
quand on l'interprete, une ressource de l'exe une fois compile -- le meme
mecanisme que la police de la pastille. Le demarrage ne la voit plus passer.

La table est en ASCII pur, noms compris, comme tous les fichiers du projet sauf
deux : c'est la saisie qui est rabattue sur l'ASCII avant comparaison, pas
l'inverse. « Geneve » accentue ou non trouve la meme ville, et une saisie
allemande est essayee sous ses deux formes -- GeoNames translittere Koln en
`Koeln` et Dusseldorf en `Duesseldorf`, la ou la mise a plat ordinaire donne
`Koln` et `Dusseldorf`.

Restent les exonymes : GeoNames nomme Geneve « Geneva », Seville « Sevilla »,
Cologne « Koeln ». Le champ `alternatenames` a ete essaye pour automatiser
cette table -- il est trie alphabetiquement et melange codes d'aeroport et
translitterations de toutes les langues : pour Geneve il donne `GVA`, `Cenevre`
et `Genava`, jamais le nom francais. La liste est donc ecrite a la main, et
chaque entree verifiee contre la table.

La fenetre affiche en permanence **le lever et le coucher du jour** pour le
lieu retenu. Ce n'est pas une decoration : il existe un Laval au Quebec et un
Laval en Mayenne, et la seule facon de savoir qu'on a pris le mauvais est de
voir le soleil s'y coucher six heures trop tot.

Sans lieu saisi, le mode solaire n'est pas muet pour autant : le **fuseau
horaire** de Windows -- « Romance Standard Time » pour la France -- donne une
ville par fuseau ([`lib/Fuseau.ahk`](../../lib/Fuseau.ahk)), et le soleil est bon a
quelques minutes pres pour toute une bande de longitude, ce qu'un fondu de
trois heures ne distingue pas. La fenetre du lieu le dit, « Paris (d'apres le
fuseau horaire) » : c'est un defaut, pas un choix, et un lieu saisi le
remplace. Le test verifie que chaque ville de cette table existe dans celle
des villes -- c'est lui qui a attrape « New York », que GeoNames nomme
« New York City ».

Regeneration de la table : [`tools/make-villes.ps1`](../../tools/make-villes.ps1).
