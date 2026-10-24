# Ocre

Filtre de lumiere chaude pilote au clavier, sur Windows 11.
*English version: [README.en.md](README.en.md).*

![Le logo aux cinq intensites](tools/apercu-logo.png)

| | Jeu principal | Jeu de secours |
|---|---|---|
| filtre moins fort | `Ctrl+F5` | `Ctrl+Alt+Retour arriere` |
| filtre plus fort | `Ctrl+F6` | `Ctrl+Alt+Entree` |
| coupe / retablit | `Ctrl+F7` | `Ctrl+Alt+Espace` |

Les deux jeux sont actifs en meme temps et entierement reconfigurables. Le
principal exige que le Fn-lock du portable soit en mode *touche de fonction*
(voir plus bas) ; le secours n'utilise aucune touche de fonction et marche
partout.

`Ctrl+Alt` + **molette de la souris** ajuste l'intensite en continu : un
reglage de ce genre se cherche plutot qu'il ne se saisit, et aucune touche ne
donne cette progressivite. La meme molette avec **`Maj`** en plus regle la
luminosite. Et la molette **sur l'icone** pres de l'heure, sans rien d'autre,
regle l'intensite aussi.

Un **clic gauche** sur l'icone ouvre les reglages, un **clic droit** un petit
panneau ou l'on regle l'intensite, la luminosite et trois prereglages sans rien
ouvrir, un **clic du milieu** coupe ou retablit le filtre -- Ctrl+F7 pour qui
a la main sur la souris. Interface en francais et en anglais.

L'intensite s'affiche en **pour cent ou en Kelvin** -- 3400 K parle a qui
vient de f.lux ou du Night Light, 58 % ne dit rien. Un clic sur la valeur, en
haut du panneau du clic droit, bascule de l'un a l'autre ; c'est le seul
endroit ou cela se choisit. Seul l'affichage change : le curseur, les
raccourcis et le fichier de configuration comptent toujours en pour cent.

Dans les fenetres, les **fleches** reglent le curseur vise, `Tab` passe de
l'un a l'autre, `Origine` et `Fin` vont aux bornes, `Echap` ferme.

Tout se pilote aussi en ligne de commande -- `Ocre.exe /set 40`, `/kelvin
3400`, `/preset nuit`, `/get` -- pour un boitier a boutons ou une macro.

---

## Pourquoi Ocre n'utilise pas le Night Light de Windows

C'etait l'intention de depart, et elle a echoue pour une raison qui merite
d'etre documentee, parce qu'elle invalide tous les outils existants sur les
builds recents.

Le Night Light n'a pas d'API. Son reglage est persiste dans deux valeurs
`REG_BINARY` sous `HKEY_CURRENT_USER`, au format **Microsoft Bond
CompactBinary v1** encapsule dans une enveloppe **CloudStore**. Toute la
litterature communautaire affirme qu'ecrire ces valeurs applique le reglage
immediatement.

**Ce n'est plus vrai depuis Windows 11 25H2 (build 26200).** Mesures faites
sur un Acer Aspire 14 AI, 25H2 build 26200.9168 :

| Observation | Consequence |
|---|---|
| Le codec de ce depot produit **exactement les memes octets** que Windows pour une meme temperature | le format est correctement compris |
| Les Parametres relisent bien la valeur ecrite (le curseur suit) | l'ecriture aboutit |
| Le rendu a l'ecran, lui, ne bouge pas | le moteur ne relit pas le registre |
| « Turn off now » n'ecrit **meme pas** la cle d'etat | l'etat vivant n'est plus dans CloudStore |

Ont ete essayes sans succes : ecriture de la temperature seule, reecriture de
la cle d'etat avec horodatage frais, cycle extinction/rallumage avec des delais
de 120 ms a 2,5 s, et le drapeau « reglage en cours » (champ 70) que
l'interface leve pendant qu'on fait glisser le curseur.

Conclusion : sur ces builds, le registre est un vestige de persistance, relu a
l'ouverture de session et plus jamais ensuite.

Contre-epreuve dans l'autre sens, en allumant puis en eteignant le Night
Light a la main depuis les reglages rapides, en surveillant les cles :

| Cle | Contenu | Ecrite |
|---|---|---|
| `Store\...\Cloud\...state` | un horodatage seul, pas d'etat | a chaque basculement |
| `Store\...\Current\...state` | « force ON » date de deux jours plus tot | touchee au basculement, **contenu inchange** |
| `Store\...\Current\...settings` | horaire, temperature | jamais |

Windows note donc *qu'il y a eu* un basculement, pas *lequel*. C'est
pourquoi Ocre ne sait pas voir un Night Light allume a la main (voir
[le bandeau](#quand-un-filtre-de-windows-se-cumule)).

Le codec reste dans [`recherche/`](recherche/) : il est correct, teste, et
permet toujours de **preregler** le Night Light pour la prochaine ouverture de
session.

## Ce que fait Ocre a la place

Une rampe gamma, via `SetDeviceGammaRamp`. Elle s'applique instantanement et
ne depend d'aucun service.

L'objection habituelle est que Windows bride l'amplitude des rampes. C'est
vrai par defaut, et c'est **desactivable** :

```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM
  GdiIcmGammaRange  (REG_DWORD)  =  256
```

Une reouverture de session est necessaire ensuite. `install.ps1` s'en charge.
[`tools/test-clamp.ahk`](tools/test-clamp.ahk) verifie que la rampe demandee
est bien appliquee telle quelle, en la relisant apres ecriture.

### La courbe

[`lib/Gamma.ahk`](lib/Gamma.ahk) part de l'approximation de Tanner Helland
(temperature de couleur vers RVB) avec deux corrections :

- **Normalisation.** A 6500 K le modele brut renvoie (255, 254, 250), soit un
  residu chaud a intensite nulle. On divise par cette reference pour que 0 %
  soit exactement l'identite.
- **Prolongement.** Le modele plafonne : a 1200 K il laisse encore le vert a
  0,34, en deca du Night Light natif a fond. Au-dela de 60 % d'intensite, le
  vert est ecrase davantage, jusqu'a 0,15. En dessous, le rendu reste celui
  d'une vraie temperature de couleur.

Le filtre ne peut que retrancher de la lumiere : plus l'intensite monte, plus
l'ecran s'assombrit. C'est inherent au procede.

### Tous les ecrans

`GetDC(0)` donne le contexte du bureau entier, mais une rampe posee dessus ne
touche que l'ecran principal : sur une machine a deux ecrans, le moniteur
externe resterait bleu pendant que le portable vire a l'ocre. Ocre enumere donc
les affichages attaches au bureau avec `EnumDisplayDevices`, ouvre un contexte
par ecran et pose la meme rampe sur chacun. Un ecran qui la refuse -- certains
moniteurs externes n'ont pas de table gamma -- ne prive pas les autres du
filtre.

Les contextes restent ouverts d'une pose a l'autre : les rouvrir a chaque cran
couterait plus cher que la rampe elle-meme, et la molette en demande plusieurs
dizaines par seconde. Le chien de garde les referme quand le nombre d'ecrans
change.

**La meme rampe partout n'est pourtant pas toujours ce qu'on veut.** Une dalle
de portable et un IPS externe n'ont pas la meme temperature native : a 60 %
l'un vire a l'orange quand l'autre reste jaune, et il n'existe pas de reglage
unique qui aille aux deux. Une bascule *Regler chaque ecran separement* donne
alors a chacun son intensite et sa luminosite.

Elle **n'apparait que s'il y a de quoi choisir**. Sur une machine a un seul
ecran, la question n'a pas d'objet, et une bascule sans objet vole de la
hauteur a une fenetre qui n'en a plus. Branchez un second ecran, rouvrez les
reglages : la section est la, avec un selecteur nommant chaque moniteur.
Debranchez-le, elle repart -- le reglage, lui, reste ecrit et redeviendra actif
au rebranchement suivant.

Separes, un raccourci doit bien s'appliquer quelque part, et les deux gestes ne
designent pas la meme chose : **au clavier** on regle l'ecran de la fenetre
active, celui qu'on regarde ; **a la molette** celui qu'elle survole, puisque
la main y est deja. La pastille suit, et s'affiche sur l'ecran concerne plutot
que toujours sur le principal -- une reponse qui apparait derriere soi ne
repond pas.

Reconnaitre un ecran d'une session a l'autre demande un identifiant stable.
C'est le `DeviceID` du moniteur, du genre `MONITOR\ACR0429\{4d36e96e-...}\0001`,
qui porte le code constructeur et le modele lus dans l'EDID ; le suffixe
numerique separe deux exemplaires identiques. Ni le `HMONITOR` ni le nom
`\.\DISPLAY1` ne conviennent : tous deux changent au gre des branchements.

### La luminosite

La rampe sait aussi assombrir : un facteur applique aux trois canaux a
l'identique, donc sans deplacer la teinte. Sur un portable c'est un bon
procede, parce qu'il descend l'ecran **sous le minimum du retroeclairage**, ce
que le materiel ne sait pas faire -- utile la nuit, quand la luminosite au plus
bas reste encore trop forte.

Sur un moniteur de bureau, c'est le mauvais. Le retroeclairage y reste a fond
et l'on ne fait qu'ecraser les niveaux : le noir cesse d'etre noir, le
contraste s'effondre. C'est le probleme que Twinkle Tray et Monitorian
resolvent, et le seul reproche serieux qu'on pouvait faire au curseur d'Ocre.

Les deux se completent au lieu de se concurrencer :

```
    100 %  ......  le materiel a fond
      |            on descend le retroeclairage
     25 %  ......  le materiel a son plancher
      |            la rampe gamma prend le relais
      0 %  ......  aussi sombre que cette machine sait l'etre
```

Deux mecanismes selon l'ecran, et ils n'ont rien en commun. **DDC/CI**
(`dxva2.dll`) parle au moniteur par le cable video : c'est le seul moyen pour
un ecran externe, et c'est lent -- une cinquantaine de millisecondes par
ecriture, la ou la molette en demanderait plusieurs dizaines par seconde. Les
ecritures sont donc regroupees sur 120 ms, comme le sont deja celles du
fichier de configuration. **WMI** (`WmiMonitorBrightnessMethods`) pilote la
dalle integree d'un portable ; c'est le meme chemin que le curseur de Windows,
donc le meme reglage : la valeur trouvee au demarrage est relevee et rendue en
sortant, exactement comme la rampe.

Le plancher materiel n'est pas le minimum annonce mais un dixieme de la course
au-dessus. Sur beaucoup de dalles, zero eteint franchement le retroeclairage --
et un ecran noir emporte avec lui la commande qui permettrait de remonter. Le
dixieme restant est rendu par la rampe, qui elle ne descend pas sous 0,30 pour
la meme raison.

Les touches Fn du portable et le curseur de Windows ecrivent la meme valeur
qu'Ocre. Il la relit donc, toutes les dix secondes et avant de quitter, et la
compare a ce qu'il a pose en dernier. Si elle a bouge, c'est quelqu'un
d'autre : Ocre **adopte** le changement -- son curseur de luminosite se
recale dessus au lieu de l'ecraser au geste suivant -- et, en quittant, ne
rend la valeur du matin que si c'est encore la sienne qui est en place.
Rendre la valeur du matin par-dessus un reglage fait a la main dans la
journee etait une surprise. Deux unites de tolerance absorbent les moniteurs
qui arrondissent ce qu'on leur ecrit, sans quoi 58 relu pour 57 ecrit
passerait pour un reglage exterieur, adopte, reecrit, relu, sans fin.
La relecture n'a lieu que si quelqu'un a touche au clavier ou a la souris
depuis le tour precedent : une touche Fn est une touche, le curseur de
Windows se prend a la souris, et une lecture DDC coute trente a cent
millisecondes de bus I2C que certains moniteurs n'aiment pas subir sans
arret.

Un moniteur qui n'a pas de table de luminosite, un pilote qui refuse, une
strategie d'entreprise qui ferme WMI : le curseur retombe alors sur la rampe
seule, et couvre toute sa course avec elle. Le bas du curseur veut toujours
dire *aussi sombre que possible*, quelle que soit la machine.
[`tools/sonde-ecrans.ahk`](tools/sonde-ecrans.ahk) dit ce que la votre sait
faire, sans rien modifier.

### Et en HDR

Deux modes de Windows ignorent la table gamma, et pour la meme raison. En **HDR**, Windows compose en virgule flottante 10 ou 16 bits et **ne consulte
plus la table gamma** : `SetDeviceGammaRamp` reussit, et ne fait rien. Ocre
poserait sa rampe, l'icone se teinterait, la pastille dirait « 60 % » -- et
l'ecran resterait bleu. Le pire cas pour une application de ce genre : un echec
muet.

La rampe multiplie chaque canal par un coefficient. **Une matrice de couleur
du compositeur fait exactement la meme chose** -- c'est l'API Magnification,
celle que Windows emploie pour ses filtres d'accessibilite -- et le
compositeur, lui, tourne aussi en HDR. Quand un ecran est en HDR, la teinte
passe donc par cette matrice ([`lib/Compositeur.ahk`](lib/Compositeur.ahk))
au lieu de la rampe. Mesure en SDR, les deux voies donnent le meme resultat
au chiffre pres : un blanc sous 60 % vaut (255, 188, 133) par l'une comme par
l'autre. Le gris s'y compose par produit de matrices.

Deux choses a savoir. L'effet est **plein ecran** : en HDR, les reglages par
ecran s'appliquent a tous, sous la valeur de l'ecran regarde. Et en HDR le
compositeur travaille en lumiere lineaire la ou la rampe multipliait des
valeurs encodees : le coefficient y est eleve a la puissance 2,2 pour que
60 % en HDR ressemble a 60 % en SDR. Cet exposant est la valeur theorique de
la courbe sRGB ; il n'a pas encore ete mesure sur un ecran HDR allume.

La detection ([`lib/Hdr.ahk`](lib/Hdr.ahk)) merite un mot, parce que la
premiere API essayee **ment**. `GET_ADVANCED_COLOR_INFO` (Windows 10) leve
« couleur avancee active » aussi bien pour le HDR que pour la gestion
automatique des couleurs (ACM), que Windows 11 active tout seul sur les dalles
a gamme etendue -- et qui, elle, laisse la rampe intacte. Sur la machine de
developpement : drapeau a 1, HDR eteint, Ocre fonctionne. S'y fier aurait fait
basculer sur le compositeur des gens pour qui la rampe marche tres bien.
`GET_ADVANCED_COLOR_INFO_2` (Windows 11 24H2) distingue SDR, WCG et HDR ;
c'est elle qu'on lit. Sur un Windows plus ancien, on conclut « pas HDR », et
la cle `voie = compositeur` de `ocre.ini` force la voie a la main.

Et le WCG, la *gestion automatique des couleurs* que Windows 11 active tout
seul sur les dalles a gamme etendue ? La rampe y marche. On a cru un temps le
contraire, et fait basculer Ocre sur le compositeur des le mode WCG : le
curseur de la souris, que la matrice du compositeur ne touche pas, restait
blanc, et la teinte etait plus faible qu'a la rampe -- le compositeur compose
en lineaire sous WCG sans que l'exposant 2,2 ne soit applique. Mesure a l'oeil
depuis : en WCG, une rampe (1 ; 0,3 ; 0) posee par `SetDeviceGammaRamp` teinte
l'ecran tres visiblement. `Hdr.RampeIgnoree` ne bascule donc qu'en vrai HDR ;
en cas de doute, la cle `voie` de `ocre.ini` tranche a la main.

### La chambre noire

Cousine du mode *Darkroom* de f.lux : l'image rendue sur le seul canal
rouge. Ce qui est sombre reste noir, ce qui est clair devient rouge, et
l'ecran n'emet que la lumiere qui derange le moins une vision adaptee a
l'obscurite. Avec des applications en mode sombre, c'est du texte rouge sur
fond noir -- l'effet cherche, sans rien d'autre.

f.lux, lui, inverse l'image en plus. C'etait pense pour des fonds blancs, qui
devenaient noirs ; sur des applications deja sombres, l'inversion fait
l'inverse du but, chaque fond noir devenant rouge vif -- et les photos
passent en negatif. Ocre n'inverse pas.

C'est une matrice de plus posee par le compositeur (`Compositeur.CHAMBRE`),
et un etat de session : ni raccourci, ni case dans les reglages, ni cle dans
`ocre.ini`, et une session s'ouvre toujours en couleur. Seule une ligne du
panneau du clic droit y mene et en sort. La luminosite continue d'assombrir ;
le gris, lui, n'a plus rien a faire et n'est pas compose.

### Reposer le filtre de force

Un jeu plein ecran, une sortie de veille ou un changement de mode couleur peut
effacer l'effet du compositeur, que le chien de garde ne surveille pas comme il
surveille la rampe. Trois choses le remettent : les messages `WM_DISPLAYCHANGE`
et compagnie appellent `Filtre.Forcer`, qui vide la detection HDR/WCG et le
cache du compositeur avant de reposer ; un bouton **Reappliquer**, a cote de la
case du gris, fait la meme chose a la main ; et `Ocre.exe /gris` bascule le gris
seul, utile pour verifier d'un coup.

### Chien de garde

Windows reinitialise la rampe de lui-meme apres une sortie de veille, un
changement de resolution, une invite UAC ou la sortie d'un jeu plein ecran.

Trois de ces quatre cas s'annoncent, et Ocre les ecoute plutot que de les
attendre : `WM_DISPLAYCHANGE` pour la resolution et les branchements d'ecran,
`WM_POWERBROADCAST` pour la veille, `WM_WTSSESSION_CHANGE` pour le verrouillage
et le changement de session. La rampe revient alors dans la milliseconde. Comme
le pilote n'a pas toujours fini de reconfigurer l'affichage quand le message
arrive, elle est reposee une seconde fois 1,2 s plus tard : une pose de trop ne
coute rien, une pose trop tot est perdue.

Reste l'invite UAC, qui n'annonce rien. Un sondage toutes les 10 secondes la
couvre, et ne sert plus qu'a cela.

## Le planificateur

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

### Caler sur le soleil

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

Le calcul est celui de la NOAA, dans [`lib/Soleil.ahk`](lib/Soleil.ahk). Il ne
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

[`tools/test-soleil.ahk`](tools/test-soleil.ahk) verifie dix-huit cas contre
des valeurs produites par la bibliotheque Python *astral*, qui implemente le
meme algorithme depuis la publication d'origine : comparer une transcription a
une autre est ce qui attrape les fautes de recopie. Sept lieux, choisis pour
les pieges -- hemisphere sud, equateur, longitudes negatives, et Tromso ou le
soleil ne se leve ni ne se couche aux solstices. Tout tombe a deux minutes,
d'Ushuaia a Tromso.

Au-dela des cercles polaires, il arrive qu'il n'y ait ni lever ni coucher. Les
heures fixes reprennent alors la main : elles ne veulent pas dire grand-chose
la-bas non plus, mais elles ne laissent pas le planificateur sans reperes.

### Ou vous etes

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
vit maintenant dans [`lib/villes.txt`](lib/villes.txt), un enregistrement par
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
ville par fuseau ([`lib/Fuseau.ahk`](lib/Fuseau.ahk)), et le soleil est bon a
quelques minutes pres pour toute une bande de longitude, ce qu'un fondu de
trois heures ne distingue pas. La fenetre du lieu le dit, « Paris (d'apres le
fuseau horaire) » : c'est un defaut, pas un choix, et un lieu saisi le
remplace. Le test verifie que chaque ville de cette table existe dans celle
des villes -- c'est lui qui a attrape « New York », que GeoNames nomme
« New York City ».

Regeneration de la table : [`tools/make-villes.ps1`](tools/make-villes.ps1).

## L'interface

Toutes les commandes -- curseur, bascules, compteur, boutons, champs de
raccourci, drapeaux -- sont **dessinees en GDI+** sur des `Picture`
([`lib/Ui.ahk`](lib/Ui.ahk), [`lib/Widgets.ahk`](lib/Widgets.ahk)). Ce n'est
pas de la coquetterie : dans une fenetre sombre, le curseur et les cases a
cocher de Windows imposent leur bleu systeme, le champ numerique reste blanc,
et le controle `Hotkey` natif n'accepte ni option `Background` ni
`SetWindowTheme`. Les dessiner est le seul moyen de tenir une palette.

Le clic droit n'ouvre pas un menu Windows mais un panneau a nous
([`lib/Panneau.ahk`](lib/Panneau.ahk)) : la hauteur de ligne, la police, les
marges et les coins d'un menu systeme ne sont pas negociables, et le resultat
detonnait a cote d'une fenetre entierement peinte. Le panneau porte en prime le
curseur d'intensite, ce qu'un menu ne saurait faire. Il se ferme a la perte du
focus, comme un menu -- AutoHotkey n'exposant pas d'evenement de desactivation,
un minuteur surveille la fenetre active.

Deux precautions gouvernent ce dessin :

- Un `Gui` met ses coordonnees a l'echelle du facteur d'affichage. Une image
  peinte a la taille demandee serait etiree : on interroge donc la taille
  **reelle** du controle et l'on peint a cette resolution.
- Le survol n'existe pas sur une `Picture`. Un minuteur unique releve la
  position de la souris et redessine les zones concernees.

Le clavier non plus : une `Picture` ne recoit aucune touche. Les fleches,
`Tab`, `Origine`, `Fin` et `Echap` passent par des raccourcis conditionnes a
la fenetre active (`HotIfWinActive`), qui ne vivent que tant que la notre a
le focus et ne prennent rien a personne. L'anneau qui marque le curseur vise
n'apparait qu'a la premiere touche, comme le fait Windows : a la souris,
personne n'a besoin de savoir lequel des deux repondrait aux fleches.

La fenetre des reglages se tire par ses bords comme n'importe quelle autre,
alors que son contenu est peint a coordonnees fixes. Les deux ne se
contredisent pas : le contenu vit dans une fenetre enfant (`WS_CHILD`) que
porte un cadre redimensionnable ([`lib/Cadre.ahk`](lib/Cadre.ahk)). Plus
large, le cadre centre le contenu, comme les reglages de Windows centrent
leur colonne ; moins haut, il le fait defiler par un ascenseur -- molette,
fleches de l'ascenseur, poignee -- comme un navigateur fait defiler une page.
Rien n'est etire : un curseur de 276 points reste un curseur de 276 points.
A la premiere ouverture, la fenetre prend la hauteur du contenu, bornee a
l'ecran ; ensuite elle garde la taille qu'on lui a donnee (`taille_reglages`
dans `ocre.ini`). Les quatre autres fenetres -- planificateur, raccourcis,
prereglages, lieu -- sont portees par le meme cadre, avec chacune sa cle. Les raccourcis de la fenetre -- fleches, Tab, Echap -- se
conditionnent sur le cadre, qui est la fenetre active ; c'est le seul endroit
ou l'enfant se voit.

Les champs de raccourci lisent la touche par un `InputHook`, ce qui permet
d'affecter la touche Windows -- que le controle natif refuse. `InputHook`
prefixe ses modificateurs de `<` ou `>` pour distinguer gauche et droite ; ces
prefixes n'ont pas de sens dans une definition de raccourci et sont retires.

Les textes vivent dans [`lib/I18n.ahk`](lib/I18n.ahk), **encode en UTF-8 avec
BOM** : sans lui AutoHotkey lirait les accents en ANSI. Les autres fichiers
restent en ASCII pur.

## Le logo

Une tache organique definie par neuf rayons polaires lisses par une courbe
fermee. Sa couleur suit l'intensite du filtre : gris bleute quand le filtre est
coupe, ambre a mi-course, ocre brulee a fond.

La meme table de rayons sert des deux cotes : [`lib/Blob.ahk`](lib/Blob.ahk)
la dessine a chaud pour la zone de notification, la pastille et la fenetre ;
[`tools/make-icon.ps1`](tools/make-icon.ps1) la dessine en System.Drawing pour
produire `Ocre.ico`, l'icone de l'executable.

Une icone ou un bitmap passe a AutoHotkey sous la forme `HICON:*` ou
`HBITMAP:*` -- avec l'asterisque -- lui fait prendre une **copie** ; l'original
reste a nous, et a detruire. On l'a cru longtemps l'inverse, et chaque
redessin de l'icone, chaque survol d'un bouton laissait trois objets GDI et
un objet USER derriere lui : deux mille cinq cents de plus par jour de
molette, et Windows tue un processus a dix mille. C'est `test-fuites` qui l'a
vu, le jour de son ecriture. `Blob.Poser`, `Blob.Tray` et `Dessin.Poser`
font depuis les choses dans l'ordre : poser, puis detruire.

Dans la zone de notification, un petit disque clair dans le coin de la tache
dit que l'horaire est suspendu par un reglage a la main -- un etat que la
couleur ne montre pas, et qu'on ne devrait pas avoir a survoler l'icone pour
connaitre. Il disparait au basculement suivant, ou par *Reprendre l'horaire*
dans le panneau.

Le `.ico` melange deux formats a dessein : DIB non compresse jusqu'a 64 px,
PNG au-dela. `System.Drawing` refuse de relire les entrees PNG en dessous de
256 px, et certains outils de ressources aussi.

### Le bouton de la barre des taches

Il reste a l'orange de l'exe, et ce n'est pas un oubli. Poser l'icone
teintee sur la fenetre (`WM_SETICON`) ne change rien : mesure sur Windows
11, la barre l'ignore, en 32 comme en 256 px, icone de classe comprise. La
seule voie qui marche -- la propriete `RelaunchIconResource` de la fenetre,
avec un `.ico` sur disque -- n'est lue qu'a la creation du bouton, et la
faire relire a chaud impose soit de faire clignoter la fenetre, soit de
changer l'identifiant d'application, ce qui envoie le bouton en fin de
barre. Un bouton fixe vaut mieux qu'un bouton qui saute.

## Installation

### L'installateur

Le plus simple : `Ocre-<version>-setup.exe`, dans les Releases GitHub. Un
double-clic, un assistant, et Ocre s'installe comme n'importe quelle
application -- dans Program Files, avec un raccourci du menu Demarrer, une
entree dans Parametres > Applications pour le retirer, et, au choix, le
lancement a l'ouverture de session. Il pose `GdiIcmGammaRange` (c'est pour
cette cle HKLM qu'il demande l'elevation) et desactive `Win+Ctrl+C` (voir plus
bas) ; la desinstallation arrete Ocre proprement, retire la tache de demarrage
et retablit `Win+Ctrl+C`. Pour mettre a jour, on lance la version suivante par
dessus : Ocre est arrete puis remplace, les reglages restent.

En silence, pour un deploiement :

```
Ocre-<version>-setup.exe /VERYSILENT /TASKS="demarrage,filtres"
```

Tant que l'installateur n'est pas signe, Windows affiche « Windows a protege
votre ordinateur » : voir « SmartScreen » plus bas.

#### Retour arriere

Avant de toucher a Windows, l'installateur note ce qu'il va changer, dans
`C:\Program Files\Ocre\sauvegarde\` :

- `avant-installation.reg` : les valeurs de registre d'origine
  (`GdiIcmGammaRange`, `HotkeyEnabled`). Un double-clic -- ou le raccourci
  « Ocre - restaurer les reglages Windows d'origine » du menu Demarrer -- et
  Windows retrouve son etat d'avant, Ocre installe ou non. Une valeur qui
  n'existait pas s'y lit `"nom"=-` : elle est supprimee.
- `avant-installation.ini` : la meme chose, pour la desinstallation.

C'est valeur par valeur, jamais une cle entiere : l'export d'une cle
ecraserait aussi ce que vous avez change depuis. L'etat note est celui
**d'avant la premiere installation** ; une mise a jour ne le reecrit pas.

La desinstallation ne rend que ce que l'installation a vraiment change -- si
`GdiIcmGammaRange` valait deja 256, elle n'y touche pas -- et seulement si la
valeur est encore celle que l'installation a posee : ce qu'un autre outil a
regle depuis n'est pas a elle. Le dossier `sauvegarde\` part avec le reste.
`tools/test-installateur.ps1` joue tout cela (installation, mise a jour,
retrait, quatre etats de depart) sans elevation, sur des cles factices.

### Sans installateur

Deux facons : l'archive `Ocre-<version>.zip` des Releases GitHub -- l'executable,
`install.ps1` et les licences, rien a construire --, ou le depot entier, ou
`install.ps1` construit l'executable s'il manque (AutoHotkey v2 et son
compilateur sont recuperes au besoin). Dans les deux cas, depuis le dossier
decompresse ou clone :

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**A lancer en administrateur la premiere fois**, pour poser `GdiIcmGammaRange`
s'il manque (une cle HKLM). La tache planifiee de demarrage, elle, se cree
sans elevation ; seul le remplacement d'une tache posee par une version
precedente la demande, et le script le dit le cas echeant.

Le script desactive aussi `Win+Ctrl+C`, le raccourci des filtres de couleur
de Windows, qui entre en collision avec `Ctrl+F7` sur certains portables
(voir plus bas) ; `install.ps1 -Uninstall` le retablit.

### Pourquoi une tache planifiee plutot qu'un raccourci

Un raccourci depose dans le dossier Demarrage n'est lance par l'explorateur
qu'une fois le shell pret, derriere toute la file des autres elements de
demarrage. Mesure faite sur un portable charge en services constructeur :

| | |
|---|---|
| Windows demarre a | 06:34:59 |
| Ocre lance a | 06:35:45 |
| ecart | **46 secondes** |

Alors que l'application s'initialise en 0,35 s. Le retard ne vient donc pas
d'elle. `StartupDelayInMSec` valait deja 0 : ce n'est pas non plus le delai
configurable de Windows, mais la serialisation des elements de demarrage.

Une tache declenchee a l'ouverture de session echappe a cette file. Sa creation
exige l'elevation ; sans elle, `install.ps1` se replie automatiquement sur le
raccourci, qui fonctionne mais reste soumis au meme retard.

`Ocre.exe` est autonome : une fois construit, ni AutoHotkey ni le compilateur
ne sont necessaires pour s'en servir. `-Build` force la regeneration de
l'icone et la recompilation ; `-Uninstall` retire le raccourci de demarrage et
arrete l'application ; `-Test` lance les tests.

### Les tests

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test.ps1
```

enchaine `test-courbe`, `test-soleil`, `test-cli` et `test-ui` -- la courbe,
le soleil, ce que la 1.3 a ajoute (Kelvin, unite, respiration, raccourcis,
export, et la ligne de commande elle-meme en sous-processus, jugee sur ses
codes de retour), puis chaque fenetre, ouverte avec une configuration
jetable, cliquee, verifiee et photographiee dans `%TEMP%\ocre-test-ui` --
puis `test-fuites`, qui redessine huit cents fois tout ce qui se redessine
et compare les compteurs du gestionnaire des taches avant et apres, et
`test-perf`, qui chronometre le chargement de tout ce qu'Ocre charge (moins
d'une seconde et demie, interpreteur compris ; 125 ms sur la machine de
developpement) et mesure le processeur au repos, minuteurs en marche, puis
celui d'`Ocre.exe` lui-meme s'il tourne (moins d'un pour cent d'un coeur ;
un demi pour cent mesure souris en mouvement, zero sans -- le hook souris de
la molette sur l'icone est le seul cout) -- et rend le nombre de tests en echec. Les trois premiers ne touchent a rien ;
les deux suivants montrent les fenetres d'Ocre une vingtaine de secondes
sans poser de rampe, les rappels vers le programme etant remplaces par des
fonctions qui notent ce qu'on leur demande. `test-ui` attrape ce que les
tests de calcul ne voient pas : un bouton dont la fermeture a capture la
mauvaise variable, deux noms qui ne different que par la casse.
`test-fuites` a trouve, le jour de son ecriture, que chaque redessin
laissait trois objets GDI derriere lui -- voir « Le logo ». `-Clamp` ajoute
`test-clamp`, qui pose une rampe extreme sur vos ecrans pendant une
demi-seconde pour verifier que Windows ne la rogne pas. L'interpreteur
AutoHotkey est necessaire : les tests ne sont pas compiles.

Deux details de `test-ui` valent d'etre connus si l'on en ecrit d'autres :
un clic envoye par `SendInput` se perd des qu'un autre processus tient un
hook souris -- Ocre en tient un pour la molette sur son icone --, on poste
donc l'enfoncement et le relachement au controle lui-meme ; et une fleche
envoyee dans la foulee d'une tabulation arrive avant que le curseur soit
pris, d'ou une touche a la fois.

C'est la compilation en executable qui donne une entree propre au gestionnaire
des taches : sans elle, Windows affiche `AutoHotkey64.exe` avec son icone
verte, puisque c'est l'interpreteur qui demarre.

**Laissez l'eclairage nocturne de Windows desactive** : les deux filtres se
cumuleraient. La fenetre des reglages le signale en rouge s'il est programme.

### SmartScreen

Au premier lancement chez quelqu'un d'autre, Windows affiche « Windows a
protege votre ordinateur ». Ce n'est pas Ocre : c'est le sort de tout
executable **non signe** dont SmartScreen n'a jamais entendu parler, et un
exe AutoHotkey compile y a droit plus qu'un autre -- certains antivirus le
mettent meme en quarantaine, l'interpreteur ayant servi a assez de
mauvaises choses. *Informations complementaires > Executer quand meme* passe
outre.

La reponse propre est une **signature de code**. `tools/sign.ps1` signe
`Ocre.exe` (SHA-256, horodate) avec un certificat de signature de code trouve
dans le magasin de l'utilisateur ou dans un PFX, et `install.ps1 -Build`
l'appelle de lui-meme s'il en trouve un. Le certificat, lui, ne se fabrique
pas ici : [SignPath Foundation](https://signpath.org) signe gratuitement les
projets open source depuis leur depot GitHub, Azure Trusted Signing coute
quelques euros par mois apres verification d'identite, un certificat OV
classique environ deux cents euros par an. `-SelfSigned` en fabrique un de
test qui ne convainc personne, mais verifie la chaine.

### Si l'ecran reste chaud

La rampe n'appartient pas a l'application : c'est un etat global du pilote
graphique. Ocre la rend en sortant, mais un « Fin de tache » dans le
gestionnaire des taches ne laisse rien s'executer, et l'ecran garde sa teinte
sans qu'aucune commande visible ne permette d'y revenir.

```
Ocre.exe /reset
```

remet l'ecran a plat et arrete Ocre.

## Reglages

Clic gauche sur l'icone. On y trouve l'intensite et la luminosite avec apercu
en direct, le pas par appui, le demarrage automatique, le retroeclairage
materiel, le gris couple au filtre, le choix de la langue, et des boutons
*Configurer...* vers les fenetres des raccourcis, des prereglages, des
habitudes et du planificateur.

**Pas de bouton Enregistrer, pas de bouton Fermer** -- ni ici ni dans les
fenetres secondaires. Comme dans les reglages de Windows, chaque commande
s'applique a l'instant ou on la touche : une bascule, un compteur, un
raccourci capture, une ville choisie, c'est fait, et `ocre.ini` est ecrit
deux cents millisecondes plus tard. La fenetre se ferme par sa croix ou par
Echap. On y perd le « fermer sans garder » ; on y gagne de ne jamais perdre
un reglage, et deux boutons par fenetre. Ce qui touche au fichier entier --
*Reinitialiser...*, *Exporter...*, *Importer...*, *Oublier...* -- garde un
bouton : ce sont des gestes qu'on veut explicites. Au premier lancement, la langue est celle de Windows :
francais si l'interface est en francais, anglais pour tout le reste ; le
drapeau fait le choix suivant. En anglais, les heures se lisent « 9:00 PM »
partout ou elles s'affichent -- l'infobulle, le planificateur, le lieu --,
et `ocre.ini` accepte aussi cette ecriture (`h_debut=9:00 PM`) ; ce qu'Ocre
y ecrit reste en 24 h. La section des ecrans n'apparait que sur une machine qui en a
plusieurs. En bas a gauche, *Reinitialiser...* remet `ocre.ini` a ses
valeurs d'origine, apres confirmation ; le demarrage automatique, qui est un
etat de Windows, n'est pas touche. A cote, *Exporter...* et *Importer...*
copient `ocre.ini` dans les deux sens, par les boites de dialogue de Windows :
tout tient dans ce fichier -- raccourcis, lieu, prereglages, langue -- et une
copie l'emporte sur une autre machine. Un fichier importe fait foi, meme sur
ce qui n'etait pas encore ecrit ; un fichier sans section `[ocre]` est
refuse.

Au premier lancement, deux pastilles disent le geste de base et ou sont les
reglages -- Ocre demarre a 0 % et rien ne se passerait sinon. Une fois, et
plus jamais. Le numero de version, lui, ne s'affiche qu'a un endroit :
l'infobulle de l'icone, la ou l'on va le chercher.

### Les raccourcis

Ils ont leur fenetre : six champs pour le filtre, un pour le gris seul, et
les deux **molettes**, dont on choisit les modificateurs parmi huit
combinaisons -- une capture de modificateurs seuls ne se fait pas proprement.
Deux cents points de hauteur que la fenetre principale n'avait plus : avec le
bandeau d'alerte et deux ecrans, elle debordait sous la barre des taches a
150 %.

Un raccourci que Windows refuse -- certaines combinaisons sont prises par le
pilote graphique ou reservees -- est nomme sous les champs, *Refuse par
Windows : Ctrl + F7*, et note dans `erreurs.log` ; la fenetre principale en
donne le nombre sans qu'on ait a ouvrir. Un raccourci qu'on croit en place et
qui ne repond pas passerait pour un programme casse.

Le bouton **Tester** repond a l'autre question, celle que Windows ne peut pas
poser : les touches arrivent-elles seulement ? Cinq secondes d'ecoute par
crochet clavier, les raccourcis du programme suspendus le temps de l'essai,
et la ligne dit lesquels ont ete recus et lesquels ne sont jamais arrives --
c'est le cas de `F5` a `F7` sur un portable dont le Fn-lock est en mode
multimedia, et jusqu'ici seul `tools/sonde-touches.ahk` savait le dire.

### Quand un filtre de Windows se cumule

Un **bandeau rouge** sous l'en-tete previent si l'eclairage nocturne de
Windows est programme ou si son filtre de couleur est actif : le premier
rechaufferait l'ecran une seconde fois le soir venu, le second le laisserait
gris des qu'Ocre se coupe. Les deux sont lus dans le registre
([`lib/Concurrents.ahk`](lib/Concurrents.ahk)), sans rien modifier. Il
previent aussi si **f.lux, Iris, LightBulb ou Twinkle Tray** tournent : deux
programmes qui ecrivent la meme rampe se battent, et c'est le conflit le plus
probable chez quelqu'un qui essaie Ocre en gardant l'ancien.

Pourquoi « programme » et non « actif » : sur 25H2, la cle d'etat du Night
Light n'est plus reecrite (voir le tableau plus haut) ; seule celle des
reglages, et son drapeau d'horaire, est tenue a jour par les Parametres. Un
Night Light allume a la main sans horaire passe donc sous le radar -- c'est
le prix de ne pas crier faux.

Le planificateur a **sa propre fenetre**, ouverte par *Configurer…*. Ce n'est
pas un caprice de rangement : avec le mode solaire, le lieu et les deux
decalages, la fenetre principale atteignait 1244 pixels sur un ecran de 1200 a
150 % de mise a l'echelle, et ne tenait plus. C'etait le bon candidat au
depart -- un horaire se regle une fois et ne se retouche plus, alors que
l'intensite et les raccourcis se reprennent. La bascule *Suivre un horaire*,
elle, reste dans la fenetre principale, ou elle se voit d'un coup d'oeil.

Pour un simple changement d'intensite, le clic droit suffit : le panneau porte
les deux curseurs et **trois prereglages** -- Lecture, Film, Nuit. Une rangee
de trois boutons plutot que trois rangees pleines : le panneau doit tenir
au-dessus de la zone de notification. Leurs valeurs se reglent dans une
fenetre a part, *Prereglages du panneau > Configurer...*, sur le modele du
planificateur : trois rangees de compteurs n'auraient pas tenu dans la
fenetre principale, qui n'a plus de hauteur a donner. Chaque clic sur un
compteur pose le couple de sa rangee sur l'ecran, sans pastille : 3 400 K ne
se choisit pas a l'aveugle. Et ce qu'on voit en fermant reste, comme pour
tout le reste des reglages -- pas de Valider, pas de retour en arriere : le
dernier couple essaye est celui qu'on garde, et il compte comme un reglage a
la main (l'horaire se suspend, les habitudes le notent).

Le panneau porte aussi la ligne *Pastille a l'ecran*, cochee par defaut : la
decocher fait taire la vignette qui accompagne chaque geste -- raccourci,
molette, prereglage. Elle n'est que la, et dans `ocre.ini` (`pastille=0`) :
comme l'unite, c'est un gout qu'on choisit une fois. Les deux pastilles
d'accueil du premier lancement passent quand meme : elles ne repondent pas a
un geste, elles disent ou est la porte.

### L'ecran qu'on ne regarde plus

*Assombrir l'ecran inactif apres N minutes* : sans clavier ni souris pendant
ce temps, la luminosite descend au plancher -- en trois secondes de fondu,
plus lentement encore que la bascule de `Ctrl+F7`, pour que l'ecran ne
« tombe » jamais sous les yeux de qui vient de lever la tete -- et remonte de
la meme facon au premier geste, a la valeur d'avant. Un film en plein ecran
ne bouge ni clavier ni souris pendant deux heures : quand la fenetre active
couvre tout son ecran, on ne s'assombrit pas. Coupe par defaut, comme tout ce
qui bouge tout seul ([`lib/Inactif.ahk`](lib/Inactif.ahk)).

### Sur batterie

*Sur batterie, baisser la luminosite de N %* : au debranchement du chargeur,
la luminosite d'Ocre -- retroeclairage puis rampe, comme le curseur --
descend de N points en trois secondes, et remonte au rebranchement. Un
reglage fait a la main entre-temps est adopte : on ne remonte que ce qu'on a
baisse soi-meme. Windows a son propre reglage pour le retroeclairage dans
les options d'alimentation ; celui-ci porte sur la luminosite d'Ocre, et se
combine avec le reste. Le changement d'alimentation arrive par
`WM_POWERBROADCAST`, deja ecoute pour la veille ; une session ouverte sur
batterie part deja baissee. La rangee n'existe que sur une machine qui a une
batterie, et le reglage est coupe par defaut
([`lib/Batterie.ahk`](lib/Batterie.ahk)).

### Suivre le contenu de l'ecran

*Suivre le contenu de l'ecran, de 30 a 100 %* : c'est l'idee de Gammy. Une
page blanche a 100 % de retroeclairage eblouit, un film sombre a 40 % ne se
voit plus ; plutot que de regler la luminosite a chaque changement de
fenetre, Ocre regarde ce que l'ecran affiche et descend la luminosite quand
le contenu est clair, la remonte quand il est sombre, entre les deux bornes.
Contenu noir : la borne haute ; page blanche : la borne basse ; gris moyen :
le milieu.

La mesure vient de la **duplication de bureau DXGI**
([`lib/Capture.ahk`](lib/Capture.ahk)), celle de Gammy et des logiciels de
capture : la carte graphique donne une texture du bureau, on la copie dans
une texture a nous munie d'une chaine de mipmaps, la carte genere la chaine
-- chaque niveau est la moyenne du precedent -- et l'on ne relit que le
niveau de trente points de large, dont on moyenne la luminance (Rec. 601).
C'est une vraie moyenne de tout l'ecran, pas un echantillon, pour deux
millisecondes de processeur quand l'image a change, et rien du tout quand
elle n'a pas change : `AcquireNextFrame` le dit sans rien rendre. Sept
mesures par seconde. Si la duplication manque -- session distante, machine
sans Direct3D --, une copie GDI prend le relais, plus chere, une fois sur
trois. La rampe et le retroeclairage ne sont dans aucune des deux : on
mesure le contenu, pas ce qu'on en fait, et rien ne boucle.

Entre la mesure et l'ecran, deux amortisseurs : une moyenne glissante courte
(six dixiemes de la mesure neuve -- une page qui change est suivie en trois
mesures, une demi-seconde) et un pas minimal de deux points. Le mouvement
est un fondu de six dixiemes de seconde, relance depuis la valeur du moment
a chaque nouvelle cible : quand le contenu bouge encore, la luminosite le
suit sans jamais sauter. Une page blanche qui s'ouvre est suivie en deux
dixiemes de seconde et rejointe en moins d'une. Un ecran tout noir -- un jeu
en plein ecran exclusif, que la duplication ne voit pas -- ne dit rien, et
l'on garde la valeur d'avant. Trois cles d'`ocre.ini` sans commande dans
les reglages, pour qui veut regler la nervosite : `adapt_periode` (ms entre
deux mesures, 150), `adapt_fondu` (ms du mouvement, 600), `adapt_lissage`
(part de la mesure neuve, 0,6).

La duplication DXGI par les tables de fonctions COM, a la main, a couche
quatre pieges, tous commentes dans le module : `DllCall` decharge
`d3d11.dll` apres l'appel si on ne la tient pas, et les objets Direct3D
pointent alors dans le vide ; la toute premiere image d'une duplication
n'en est pas une -- une surface restreinte, en demi-flottants, sans
contenu, dont il ne faut surtout pas faire le modele de sa texture de
lecture ; `CopyResource` veut le meme nombre de niveaux des deux cotes ; un
`HRESULT` revient signe sur 32 bits et se compare non signe.

Quand ce suivi est actif, c'est lui qui tient le curseur de luminosite : les
bornes sont le reglage. Il se tait tant qu'une fenetre a curseur est ouverte
-- on ne dispute pas le curseur a la main qui le tient --, quand l'ecran est
assombri pour inactivite, et retire ce que la batterie a retire. Ecrans
separes, chaque ecran suit son propre contenu ; ensemble, c'est l'ecran
qu'on regarde qui decide pour tous. Coupe par defaut
([`lib/Adaptatif.ahk`](lib/Adaptatif.ahk)).

### Apprendre les habitudes

*Habitudes > Configurer... > Apprendre mes habitudes* : quelqu'un qui
remonte la luminosite tous les soirs apres le coucher du soleil, ou qui
baisse le filtre des qu'un film passe en plein ecran, le fait a la main des
dizaines de fois avant de penser a un horaire. Ocre regarde ces gestes,
retient dans quelles circonstances ils menent a quelle valeur, et quand une
circonstance a ete confirmee assez de fois, pose la valeur lui-meme, en
fondu, avec une pastille qui dit « Habitude · 5 fois » -- puis continue
d'apprendre. C'est un petit modele ([`lib/Habitudes.ahk`](lib/Habitudes.ahk)),
et chaque piece a une raison :

- **La decantation.** Un geste n'est pas une observation. Montrer l'outil a
  un ami et faire monter et descendre le filtre comme un fou pendant cinq
  minutes, c'est cinquante gestes et zero choix. Seule compte la valeur ou
  la main *s'arrete* : deux minutes sans nouveau geste, et c'est celle-la,
  une seule fois.
- **La mediane, pas la moyenne.** Le soir de la demonstration, le filtre est
  reste a 100 % : une moyenne en serait tiree de vingt points pendant des
  semaines ; une mediane ne bouge pas tant qu'une minorite dit autre chose.
- **Le temps solaire.** Une habitude du soir est « une heure apres le
  coucher », pas « 21 h » : en decembre le soleil se couche a 17 h et
  l'habitude horaire arriverait quatre heures trop tard, et le changement
  d'heure decalerait tout d'un coup. Autour du coucher et du lever, les
  gestes se comparent en minutes par rapport au soleil (le lieu des
  reglages, ou celui du fuseau horaire) ; au milieu du jour et de la nuit, a
  l'horloge.
- **Le noyau.** Pas de grille : deux gestes se ressemblent d'autant plus
  qu'ils sont proches, une gaussienne de vingt-cinq minutes d'ecart-type.
  21 h 29 et 21 h 31 sont le meme geste ; 21 h et 22 h n'ont presque rien a
  se dire.
- **L'oubli, a deux vitesses.** Une observation perd la moitie de son poids
  tous les trente jours et disparait a soixante : l'hiver ne dicte pas
  l'ete. Mais une memoire lente est lente a admettre un changement : les
  quatre observations les plus recentes forment une memoire courte, et si
  elles sont d'accord entre elles et en desaccord avec la longue, c'est
  qu'une habitude a change -- la courte l'emporte, en trois soirs, sans que
  la longue perde sa robustesse contre les aberrants.
- **La confiance, et la proposition.** On n'agit que si le poids des
  observations atteint 2,5 -- trois gestes recents au bon moment -- ET si
  elles sont d'accord : six dixiemes du poids a dix points ou moins de la
  mediane. Tantot 30, tantot 80, ce n'est pas une habitude, c'est une
  hesitation, et l'on se tait. En dessous de la confiance mais des deux
  soirs concordants, Ocre *propose* : une pastille « 80 comme hier ? »
  qu'un clic accepte, et qui compte alors pour un geste ; l'ignorer ne
  coute rien.
- **La correction, et l'approbation.** Un geste dans les dix minutes qui
  suivent une pose automatique est un desaveu : l'observation pese double.
  Trente minutes sans geste, *avec quelqu'un devant l'ecran* -- une pose
  que personne n'a vue ne dit rien --, c'est une approbation : la valeur
  posee devient une observation implicite a demi-poids. Sans cela, le
  modele tuait les habitudes qu'il reussissait a automatiser : plus de
  geste, plus d'observation, et l'oubli faisait le reste.
- **Les residus.** Quand un automate tient la voie -- le planificateur pour
  l'intensite, le suivi du contenu pour la luminosite --, on n'apprend pas
  la valeur mais l'*ecart* a ce que l'automate donnait : « a cette heure,
  toujours quinze de plus que le soleil ». L'ecart appris devient un
  decalage que l'automate applique lui-meme : il reste maitre, l'habitude
  le corrige. L'assombrissement d'inactivite et la baisse sur batterie,
  eux, sont des etats passagers : on n'y apprend rien et l'on n'y pose rien.
- **La retenue.** Rien dans le quart d'heure qui suit un geste, rien tant
  qu'un geste decante, rien tant que la cible n'a pas bouge depuis le
  dernier geste -- une correction suspend l'habitude, comme un reglage a la
  main suspend le planificateur, et pas au-dela du jour.
- **Le contexte.** Chaque observation retient l'application au premier plan
  (le nom de son processus, dans `habitudes.ini`, en local) et si elle est
  en plein ecran : « quand le lecteur video est en plein ecran, luminosite
  40 » vaut a toute heure. Un contexte qui a ses propres observations,
  assez nombreuses et d'accord, l'emporte sur l'heure tant qu'il est
  devant, et la pastille le nomme. Le week-end aussi est un contexte : quand
  un moment a assez d'observations du meme genre de jour, il n'ecoute
  qu'elles.
- **La rampe.** Entre deux moments surs a des valeurs differentes -- 80 a
  21 h, 60 a 23 h --, la valeur glisse de l'un a l'autre au lieu de tomber
  par marches, comme le fait le planificateur solaire ; les pas d'une rampe
  passent sans pastille.

La fenetre montre les deux courbes de la journee, un baton par demi-heure :
la valeur attendue en hauteur, l'ocre quand le modele est sur de lui, le
gris quand il a des observations mais pas assez, un trait a l'heure qu'il
est, et le compte des observations et des creneaux surs ; un clic sur un
baton liste les observations de la demi-heure -- date, valeur, application,
ecart, correction ou approbation -- et *Oublier...* efface tout. Les
observations vivent dans `habitudes.ini` a cote d'`ocre.ini`, une ligne
par observation, lisibles et effacables a la main ; chaque observation,
pose, proposition, approbation et ecart est note dans `habitudes.log`, pour
comprendre apres coup. L'horloge, le soleil, la presence et l'application au
premier plan du modele sont injectables : les tests lui font vivre deux mois
-- demonstration, correction, hesitation, approbation sans temoin,
changement d'heure du lever, film en plein ecran, planificateur a corriger
-- en quelques millisecondes. Coupe par defaut.

### La regle des 20-20-20

Toutes les vingt minutes, regarder a six metres pendant vingt secondes :
c'est la seule chose qu'un filtre ne fait pas pour les yeux. Une bascule
dans la fenetre du planificateur -- c'est une affaire d'heure, et la fenetre
principale est pleine -- l'active, coupee par defaut comme tout ce qui
interrompt.

Le rappel n'affiche rien : **l'icone de la zone de notification respire**,
la tache retrecit et regrossit doucement, un cycle toutes les trois
secondes, pendant vingt secondes. Qui sait ce que c'est le voit ; qui ne le
sait pas ne voit rien. Une pastille au milieu de l'ecran se voyait de tout
le monde -- y compris de la personne a qui l'on montre justement quelque
chose. Et pour la meme raison, **filtre coupe, pas de rappel** : `Ctrl+F7`
est le geste qu'on fait pour montrer son ecran, ce n'est pas le moment. Si
le clavier et la souris dorment depuis plus de cinq minutes, il se tait
aussi : les yeux se reposent deja. La periode se change dans `ocre.ini`
(`rappel_minutes`).

### Adoucir les changements

Le planificateur a son fondu de trois heures, dont tout l'interet est de ne pas
se voir. Un appui sur un raccourci, lui, sautait d'un cran a l'autre : cinq
points d'intensite d'un coup, c'est un clignement. Le meme argument vaut aux
deux echelles, et il ne coute ici qu'un sixieme de seconde.

La bascule (Ctrl+F7) et les prereglages ne font pas un pas de cinq points :
ils vont de zero a cent d'un coup, et le meme sixieme de seconde en fait un
flash. Ils ont donc leur propre duree, une seconde par defaut, reglable par la cle
`fondu_bascule` de `ocre.ini` (en millisecondes). Qui prefere le coup sec
d'origine y remet `160`. Le gris, quand il est couple au filtre, suit le meme
fondu : il s'installe et se retire avec la teinte au lieu de tomber d'un coup.

Ce qui **ne** passe **pas** par ce fondu, et a dessein : la molette et les
curseurs, qui sont deja continus -- le geste EST le fondu, et y ajouter une
interpolation ferait trainer l'image derriere la main ; et la pose au
demarrage, une session qui s'ouvre en s'eclaircissant pendant une seconde ayant
l'air d'un defaut.

## La ligne de commande

Pour ce qui n'est pas un clavier : un boitier a boutons, une macro, un script
de mise en veille.

```
Ocre.exe /set 40        pose l'intensite            /set +5, /set -5 : relatif
Ocre.exe /kelvin 3400   pose la temperature (1200 a 6500 K)
Ocre.exe /lum 60        pose la luminosite          /lum +5, /lum -5 : relatif
Ocre.exe /plus          un pas plus chaud
Ocre.exe /moins         un pas moins chaud
Ocre.exe /toggle        coupe ou retablit
Ocre.exe /preset nuit   un prereglage : lecture, film, nuit
Ocre.exe /gris          niveaux de gris, active ou coupe
Ocre.exe /chambre       chambre noire, entre ou sort
Ocre.exe /horaire on    planificateur : on, off, ou rien pour basculer
Ocre.exe /rappel        fait respirer l'icone, comme le rappel des 20-20-20
Ocre.exe /get           l'etat sur la sortie standard ; code de retour = intensite
Ocre.exe /export f.ini  copie les reglages dans un fichier
Ocre.exe /import f.ini  prend les reglages d'un fichier, et les applique
Ocre.exe /reset         rampe neutre et arret
Ocre.exe /quit          arret propre
Ocre.exe /help          la liste
```

`-set` vaut `/set` : les deux conventions ont cours sur Windows, et refuser
l'une pour l'autre n'apprend rien a personne. Les mots anglais sont acceptes
aussi : `warmer`, `cooler`, `brightness`, `schedule`, `darkroom`.

`/get` ecrit une ligne `cle=valeur` par ligne -- intensite, kelvin,
luminosite, coupe, horaire, gris, noir, unite, portable, fichier, separes, et une
ligne par ecran quand ils sont separes -- ce qu'un script lit sans effort,
et rend l'intensite en code de retour pour qui ne veut que cela. Ocre.exe
est une application a fenetre, pas une application console : `cmd` et
PowerShell ne l'attendent pas, la sortie arrive apres l'invite et le code de
retour n'est pas dans `%ERRORLEVEL%` ni `$LASTEXITCODE`. Pour les lire,
attendez-le : `start /wait Ocre.exe /get` dans `cmd`, et en PowerShell
`$p = Start-Process .\Ocre.exe /get -Wait -PassThru -NoNewWindow; $p.ExitCode`.

`/export` et `/import` sont les boutons de la fenetre des reglages, pris en
ligne de commande -- pour deployer les memes reglages sur plusieurs
machines. Un chemin ne passe pas dans un message : les deux travaillent sur
le fichier eux-memes, et `/import` previent ensuite l'instance en place que
tout a change, langue comprise. Un chemin relatif l'est au dossier d'ou l'on
lance la commande. Un fichier sans section `[ocre]` est refuse, code 2.

Une commande qui attend un nombre et n'en recoit pas -- `/set` tout court,
`/set abc` -- **ne fait rien et le dit**, code de retour 2. Elle valait zero
auparavant, et zero coupe le filtre : une macro mal ecrite eteignait l'ecran
en silence.

Une commande adressee a une instance vivante lui est **postee**, pas appliquee
sur place : deux processus qui poseraient chacun leur rampe se battraient. La
diffusion evite d'avoir a retrouver la fenetre, qui est cachee. C'est aussi
pourquoi `#SingleInstance Force` a disparu -- il aurait tue l'application pour
la relancer a chaque commande, ce qui donne le bon resultat par le plus mauvais
chemin. La question « suis-je le premier ? » est posee a un mutex nomme.

Sans instance en cours, `/set` et ses voisins demarrent l'application puis
s'appliquent ; `/reset` remet simplement l'ecran a plat, ce qui est justement
le cas ou l'on s'en sert.

### Pourquoi on ne peut pas se brancher sur la touche de luminosite

L'idee vient naturellement : puisque F5 baisse la luminosite, pourquoi ne pas
associer le filtre a `Ctrl` + cette touche ? Parce qu'en mode multimedia le
clavier n'emet aucun code de touche : il declenche une commande qui part
directement au pilote d'affichage, sans traverser la file du clavier.

Mesure faite avec [`tools/sonde-luminosite.ahk`](tools/sonde-luminosite.ahk),
qui ecoute le crochet clavier, `WM_APPCOMMAND` et les raccourcis systeme :
**vingt appuis sur F5 seul, zero evenement**. Il n'y a rien a intercepter, avec
ou sans modificateur.

### Verifier que les touches de fonction vous parviennent

Appuyez sur **`F5` seul** dans un navigateur. Si la page se rafraichit, les
touches de fonction atteignent Windows et le jeu principal fonctionne. Si la
luminosite change a la place, le Fn-lock est en mode multimedia : le firmware
avale la touche avant Windows, et seul le jeu de secours repond. Beaucoup de
portables remettent ce mode au redemarrage.

Les reglages vivent dans `%APPDATA%\Ocre\ocre.ini`, a cote de deux journaux.
`demarrage.log` note a quelle seconde apres l'allumage Ocre a pris la main, ce
qui distingue une application lente d'une application lancee tard par Windows.
`erreurs.log` recoit toute erreur avant qu'elle ne s'affiche : Ocre demarre avec
la session, et une boite ouverte a ce moment-la se retrouve derriere les autres
fenetres ou se ferme d'un reflexe. Les deux sont tronques au-dela de quarante
lignes.

### Mode portable

Un `ocre.ini` pose **a cote de `Ocre.exe`** prend le pas sur celui de
`%APPDATA%`, et les journaux le rejoignent : l'application s'emporte alors
sur une cle USB ou dans un dossier synchronise avec ses reglages. Le fichier
doit exister -- meme vide -- pour que le mode s'active ; c'est un choix qu'on
fait en le creant, pas un comportement qui se declenche tout seul. `Ocre.exe
/get` dit quel fichier est en service.

## Si les raccourcis ne repondent pas

Sur beaucoup de portables (Acer notamment), le **Fn-lock** est en mode
multimedia : `F5` et `F6` declenchent la luminosite au niveau du firmware et
n'atteignent jamais Windows. Aucun script ne peut les intercepter dans cet
etat.

- **`Fn` + `Esc`** sur la plupart des Acer, ou
- BIOS (`F2` au demarrage) > **Main** > **Function key behavior** > **Function key**

La luminosite passe alors sur `Fn+F5` / `Fn+F6`.

Attention en reaffectant une touche : sur ces memes machines, `Ctrl+F7`
declenche la projection d'ecran au niveau firmware, ce que la capture
enregistre comme `Win+P`. Le bouton *Reinitialiser* remet les six raccourcis
d'origine.

### Si l'ecran vire au gris quand Ocre se coupe

Ce n'est pas Ocre : c'est le **filtre de couleur** de Windows (Accessibilite >
Filtres de couleur), en mode niveaux de gris. Tant qu'Ocre est actif, l'ocre le
masque ; des qu'il se coupe, le gris apparait.

Il s'allume parce que Windows lui donne un raccourci, `Win+Ctrl+C`, actif par
defaut. Le firmware de ces memes portables injectant une touche Win dans les
combinaisons `Fn+F7`, la bascule d'Ocre declenche les deux a la fois.
`install.ps1` desactive ce raccourci -- le filtre lui-meme reste disponible
dans les Parametres pour qui s'en sert. A la main :

```
HKCU\Software\Microsoft\ColorFiltering
  HotkeyEnabled  (REG_DWORD)  =  0
```

### Le noir profond, pour les dalles OLED

Sur un ecran OLED, un pixel noir est eteint, et un pixel gris tres sombre
est allume. Or presque aucune application n'ecrit du noir : le mode sombre
de Notion et de Discord est `#191919` (niveau 25 sur 255), celui de VS Code
`#1E1E1E` (30), Spotify `#121212` (18). Sur une dalle qui sait faire un vrai
noir, tout cela est une lueur grise uniforme -- et le contraste infini de
l'ecran ne sert a rien.

La bascule **Noir profond (OLED)** des reglages envoie au noir pur tout
niveau inferieur ou egal a un seuil, et etire ce qui est au-dessus pour que
le blanc reste le blanc. C'est la meme rampe gamma que le filtre, donc le
meme mecanisme, sans rien changer aux applications, et il **suit le filtre**
comme le gris : `Ctrl+F7` l'emporte avec la teinte, en fondu -- le seuil
descend cran par cran avec l'intensite --, et le retablit avec elle. Notion, Discord, VS
Code, le terminal et l'explorateur deviennent noirs d'un coup, partout. Le
seuil se regle de 4 en 4, de 4 a 64 ; 28 par defaut, qui prend Notion et
Discord (25) et epargne VS Code (30) -- 32 les prend tous. Chaque cran de
plus bouche un peu plus les ombres des photos et des films : c'est le prix,
et il est visible des 40. En HDR, ou la rampe est ignoree, la meme
operation passe par la matrice du compositeur, avec le seuil converti en
lumiere lineaire.

Dans `ocre.ini`, `noir` est le seuil en service (0 = coupe) et `noir_seuil`
celui qu'on retrouve en rallumant ; `/get` rend `noir=`. Le chien de garde
le surveille comme le reste de la rampe : il relit l'entree du seuil, qui
doit valoir zero.

### Le gris, couple au filtre

Certains lisent le soir en gris **et** en chaud : le gris ote la couleur qui
accroche l'oeil, le chaud ote le bleu qui tient eveille. Une bascule *Passer
l'ecran en niveaux de gris avec le filtre* fait suivre le gris au filtre :
allume des qu'Ocre l'est, coupe avec lui. Une seule commande pose les deux
etats, et c'est ce qui les empeche de se desynchroniser -- le probleme
d'origine.

Piloter le filtre de Windows a ete essaye et ecarte, mesures a l'appui. Sa cle
`Active` n'est pas relue a chaud : ecrite, elle ne change rien avant la
prochaine bascule dans les Parametres. Son raccourci passe par `atbroker.exe`,
qui refuse des que le raccourci est desactive -- et il faut le desactiver,
c'est le paragraphe precedent.

Ocre pose donc **son** gris, par l'API Magnification
(`MagSetFullscreenColorEffect`), qui est le mecanisme que Windows emploie
lui-meme en dessous : une matrice de couleur appliquee a tout le bureau par le
compositeur. C'est instantane, sans registre, et **l'effet appartient au
processus** : un « Fin de tache » rend l'ecran a la couleur, la ou le filtre de
Windows serait reste.

Un piege, qui a coute une heure et merite d'etre ecrit. `DllCall` charge une
DLL, appelle, puis la **decharge** si rien d'autre ne la retient -- c'est
documente. `MagInitialize` s'executait, la bibliotheque etait liberee avec son
etat, et l'appel suivant tombait sur une bibliotheque vierge :
`ERROR_INVALID_FUNCTION`, sans autre explication, alors que le meme appel
depuis Python reussissait. Un `LoadLibrary` explicite, garde le temps du
processus, regle tout ([`lib/Compositeur.ahk`](lib/Compositeur.ahk)).

## Arborescence

| | |
|---|---|
| [`Ocre.ahk`](Ocre.ahk) | le programme : raccourcis, icone, chien de garde, ligne de commande |
| [`lib/Gamma.ahk`](lib/Gamma.ahk) | la courbe d'intensite et la rampe qui la porte |
| [`lib/Ecrans.ahk`](lib/Ecrans.ahk) | qui sont les ecrans, et lequel on regarde |
| [`lib/Retro.ahk`](lib/Retro.ahk) | le retroeclairage materiel, DDC/CI et WMI |
| [`lib/Filtre.ahk`](lib/Filtre.ahk) | l'etat du filtre et sa pose sur les ecrans |
| [`lib/Fondu.ahk`](lib/Fondu.ahk) | adoucir un changement fait a la main |
| [`lib/Compositeur.ahk`](lib/Compositeur.ahk) | une matrice de couleur sur tout le bureau : le gris, et la teinte en HDR |
| [`lib/Hdr.ahk`](lib/Hdr.ahk) | l'ecran est-il en HDR |
| [`lib/Horaire.ahk`](lib/Horaire.ahk) | le planificateur et son fondu |
| [`lib/Unite.ahk`](lib/Unite.ahk) | pour cent ou Kelvin, a l'affichage |
| [`lib/Concurrents.ahk`](lib/Concurrents.ahk) | le Night Light et le filtre de couleur de Windows sont-ils actifs |
| [`lib/Soleil.ahk`](lib/Soleil.ahk) | lever et coucher du soleil, calcules sur place |
| [`lib/Villes.ahk`](lib/Villes.ahk) | la recherche d'une ville, et les exonymes |
| [`lib/villes.txt`](lib/villes.txt) | 26 700 villes, lues a la premiere recherche |
| [`lib/Pays.ahk`](lib/Pays.ahk) | noms de pays, et la mise a plat des accents |
| [`lib/Lieu.ahk`](lib/Lieu.ahk) | la fenetre du lieu |
| [`lib/Planificateur.ahk`](lib/Planificateur.ahk) | la fenetre du planificateur |
| [`lib/Prereglages.ahk`](lib/Prereglages.ahk) | la fenetre des trois prereglages |
| [`lib/Raccourcis.ahk`](lib/Raccourcis.ahk) | la fenetre des raccourcis, et leur test |
| [`lib/Rappel.ahk`](lib/Rappel.ahk) | la regle des 20-20-20, par l'icone qui respire |
| [`lib/Inactif.ahk`](lib/Inactif.ahk) | assombrir l'ecran qu'on ne regarde plus |
| [`lib/Batterie.ahk`](lib/Batterie.ahk) | baisser la luminosite quand le chargeur est debranche |
| [`lib/Adaptatif.ahk`](lib/Adaptatif.ahk) | la luminosite qui suit le contenu de l'ecran |
| [`lib/Capture.ahk`](lib/Capture.ahk) | la luminance moyenne d'un ecran, par duplication DXGI |
| [`lib/Habitudes.ahk`](lib/Habitudes.ahk) | apprendre ce qu'on regle a la main, et le faire soi-meme |
| [`lib/Apprentissage.ahk`](lib/Apprentissage.ahk) | la fenetre des habitudes |
| [`lib/Fuseau.ahk`](lib/Fuseau.ahk) | un lieu approximatif, deduit du fuseau horaire |
| [`lib/Blob.ahk`](lib/Blob.ahk) | le logo dessine a chaud |
| [`lib/Police.ahk`](lib/Police.ahk) | la police Inter de la pastille, chargee depuis la ressource de l'exe |
| [`lib/Inter-Medium.ttf`](lib/Inter-Medium.ttf), [`lib/Inter-LICENSE.txt`](lib/Inter-LICENSE.txt) | la police et sa licence (SIL OFL 1.1) |
| [`lib/Ui.ahk`](lib/Ui.ahk) | surface de dessin GDI+ et suivi du survol |
| [`lib/Cadre.ahk`](lib/Cadre.ahk) | une fenetre redimensionnable autour d'un contenu fixe : centrage, ascenseur |
| [`lib/Widgets.ahk`](lib/Widgets.ahk) | bouton, bascule, curseur, compteur, champ, drapeau, clavier, alerte |
| [`lib/Osd.ahk`](lib/Osd.ahk) | la pastille d'intensite |
| [`lib/Panneau.ahk`](lib/Panneau.ahk) | le panneau du clic droit |
| [`lib/Reglages.ahk`](lib/Reglages.ahk) | la fenetre de configuration |
| [`lib/Theme.ahk`](lib/Theme.ahk) | palette et mise au sombre des elements systeme |
| [`lib/I18n.ahk`](lib/I18n.ahk) | textes francais et anglais |
| [`lib/Config.ahk`](lib/Config.ahk) | reglages persistes, mode portable et demarrage automatique |
| [`tools/make-icon.ps1`](tools/make-icon.ps1) | genere `Ocre.ico` |
| [`tools/make-villes.ps1`](tools/make-villes.ps1) | regenere la table des villes depuis GeoNames |
| [`tools/test.ps1`](tools/test.ps1) | lance les tests et compte les echecs |
| [`tools/test-cli.ahk`](tools/test-cli.ahk) | Kelvin, unite, respiration, raccourcis, export, ligne de commande |
| [`tools/test-ui.ahk`](tools/test-ui.ahk) | chaque fenetre, ouverte, cliquee, photographiee |
| [`tools/test-fuites.ahk`](tools/test-fuites.ahk) | ce qui se dessine mille fois ne laisse-t-il rien ? |
| [`tools/test-perf.ahk`](tools/test-perf.ahk) | le demarrage est-il rapide, le repos silencieux ? |
| [`tools/release.ps1`](tools/release.ps1) | construit, teste, verifie les ressources, range le tout dans `dist\Ocre-<version>.zip` et construit l'installateur |
| [`tools/installer.ps1`](tools/installer.ps1) | construit `dist\Ocre-<version>-setup.exe` avec Inno Setup (recupere par winget au besoin) |
| [`tools/test-installateur.ps1`](tools/test-installateur.ps1) | joue l'installateur d'essai -- installation, mise a jour, retour arriere -- sans elevation, sur des cles factices |
| [`installer/`](installer/) | le script Inno Setup de l'installateur, et `utilisateur.ps1`, ce qu'il pose dans le compte de l'utilisateur (tache de demarrage, `Win+Ctrl+C`) |
| [`tools/sign.ps1`](tools/sign.ps1) | signe `Ocre.exe`, quand il y a un certificat |
| [`tools/test-soleil.ahk`](tools/test-soleil.ahk) | verifie le calcul solaire contre une autre implementation |
| [`tools/sonde-ecrans.ahk`](tools/sonde-ecrans.ahk) | ce qu'Ocre voit de vos ecrans, sans rien modifier |
| [`tools/test-clamp.ahk`](tools/test-clamp.ahk) | verifie que la rampe n'est pas rognee |
| [`tools/test-courbe.ahk`](tools/test-courbe.ahk) | verifie la courbe et le planificateur, sans materiel |
| [`tools/sonde-touches.ahk`](tools/sonde-touches.ahk) | quelles touches parviennent reellement a Windows |
| [`tools/sonde-luminosite.ahk`](tools/sonde-luminosite.ahk) | la touche de luminosite est-elle visible du logiciel |
| [`recherche/`](recherche/) | le Night Light natif : codec, CLI, sauvegardes du registre |

## Credits

Le format binaire du Night Light a ete documente par deux depots, sans lesquels
le diagnostic ci-dessus aurait ete impossible :

- [**kvnxiao/win-nightlight-cli**](https://github.com/kvnxiao/win-nightlight-cli) —
  [structure du registre](https://github.com/kvnxiao/win-nightlight-cli/blob/main/docs/nightlight-registry-format.md)
  et [wire format Bond CompactBinary v1](https://github.com/kvnxiao/win-nightlight-cli/blob/main/docs/bond-compact-binary-v1.md)
- [**Enyium/sem-reg-rs**](https://github.com/Enyium/sem-reg-rs) —
  [documentation complementaire](https://github.com/Enyium/sem-reg-rs/blob/master/src/cloud_store/night_light/docs.md),
  seule a documenter le drapeau « reglage en cours » et la regle d'horodatage
  croissant

Voir aussi [elModo7/WindowsNightLight_CLI](https://github.com/elModo7/WindowsNightLight_CLI)
et [Fleex's Lab sur CloudStore](https://fleexlab.blogspot.com/2017/05/the-windows-cloudstore.html).

Deux ressources embarquees dans l'executable viennent d'ailleurs :

- la table des villes (`lib/villes.txt`) est extraite de
  [**GeoNames**](https://www.geonames.org/), sous licence
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) ;
- la police de la pastille est [**Inter**](https://rsms.me/inter/) de Rasmus
  Andersson, sous [SIL Open Font License 1.1](lib/Inter-LICENSE.txt).

## Licence

MIT — voir [LICENSE](LICENSE).
