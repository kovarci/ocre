# Ce que fait Ocre a la place

[← Ocre](../../README.fr.md#documentation) · [English](../en/how-it-works.md)

Une rampe gamma, via `SetDeviceGammaRamp`. Elle s'applique instantanement et
ne depend d'aucun service.

L'objection habituelle est que Windows bride l'amplitude des rampes. C'est
vrai par defaut, et c'est **desactivable** :

```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM
  GdiIcmGammaRange  (REG_DWORD)  =  256
```

Une reouverture de session est necessaire ensuite. `install.ps1` s'en charge.
[`tools/test-clamp.ahk`](../../tools/test-clamp.ahk) verifie que la rampe demandee
est bien appliquee telle quelle, en la relisant apres ecriture.

## La courbe

[`lib/Gamma.ahk`](../../lib/Gamma.ahk) part de l'approximation de Tanner Helland
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

## Tous les ecrans

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

## La luminosite

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
[`tools/sonde-ecrans.ahk`](../../tools/sonde-ecrans.ahk) dit ce que la votre sait
faire, sans rien modifier.

## Et en HDR

Deux modes de Windows ignorent la table gamma, et pour la meme raison. En **HDR**, Windows compose en virgule flottante 10 ou 16 bits et **ne consulte
plus la table gamma** : `SetDeviceGammaRamp` reussit, et ne fait rien. Ocre
poserait sa rampe, l'icone se teinterait, la pastille dirait « 60 % » -- et
l'ecran resterait bleu. Le pire cas pour une application de ce genre : un echec
muet.

La rampe multiplie chaque canal par un coefficient. **Une matrice de couleur
du compositeur fait exactement la meme chose** -- c'est l'API Magnification,
celle que Windows emploie pour ses filtres d'accessibilite -- et le
compositeur, lui, tourne aussi en HDR. Quand un ecran est en HDR, la teinte
passe donc par cette matrice ([`lib/Compositeur.ahk`](../../lib/Compositeur.ahk))
au lieu de la rampe. Mesure en SDR, les deux voies donnent le meme resultat
au chiffre pres : un blanc sous 60 % vaut (255, 188, 133) par l'une comme par
l'autre. Le gris s'y compose par produit de matrices.

Deux choses a savoir. L'effet est **plein ecran** : en HDR, les reglages par
ecran s'appliquent a tous, sous la valeur de l'ecran regarde. Et en HDR le
compositeur travaille en lumiere lineaire la ou la rampe multipliait des
valeurs encodees : le coefficient y est eleve a la puissance 2,2 pour que
60 % en HDR ressemble a 60 % en SDR. Cet exposant est la valeur theorique de
la courbe sRGB ; il n'a pas encore ete mesure sur un ecran HDR allume.

La detection ([`lib/Hdr.ahk`](../../lib/Hdr.ahk)) merite un mot, parce que la
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

## La chambre noire

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

## Reposer le filtre de force

Un jeu plein ecran, une sortie de veille ou un changement de mode couleur peut
effacer l'effet du compositeur, que le chien de garde ne surveille pas comme il
surveille la rampe. Trois choses le remettent : les messages `WM_DISPLAYCHANGE`
et compagnie appellent `Filtre.Forcer`, qui vide la detection HDR/WCG et le
cache du compositeur avant de reposer ; un bouton **Reappliquer**, a cote de la
case du gris, fait la meme chose a la main ; et `Ocre.exe /gris` bascule le gris
seul, utile pour verifier d'un coup.

## Chien de garde

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
