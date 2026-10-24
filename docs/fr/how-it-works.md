# Comment ça marche

[← Ocre](../../README.fr.md#documentation) · [English](../en/how-it-works.md)

Une rampe gamma, via `SetDeviceGammaRamp`. Elle s'applique instantanément et
ne dépend d'aucun service.

L'objection habituelle est que Windows bride l'amplitude des rampes. C'est
vrai par défaut, et c'est **désactivable** :

```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM
  GdiIcmGammaRange  (REG_DWORD)  =  256
```

Une réouverture de session est nécessaire ensuite. `install.ps1` s'en charge.
[`tools/test-clamp.ahk`](../../tools/test-clamp.ahk) vérifie que la rampe demandée
est bien appliquée telle quelle, en la relisant après écriture.

## La courbe

[`lib/Gamma.ahk`](../../lib/Gamma.ahk) part de l'approximation de Tanner Helland
(température de couleur vers RVB) avec deux corrections :

- **Normalisation.** À 6500 K le modèle brut renvoie (255, 254, 250), soit un
  résidu chaud à intensité nulle. On divise par cette référence pour que 0 %
  soit exactement l'identité.
- **Prolongement.** Le modèle plafonne : à 1200 K il laisse encore le vert à
  0,34, en deçà du Night Light natif à fond. Au-delà de 60 % d'intensité, le
  vert est écrasé davantage, jusqu'à 0,15. En dessous, le rendu reste celui
  d'une vraie température de couleur.

Le filtre ne peut que retrancher de la lumière : plus l'intensité monte, plus
l'écran s'assombrit. C'est inhérent au procédé.

## Tous les écrans

`GetDC(0)` donne le contexte du bureau entier, mais une rampe posée dessus ne
touche que l'écran principal : sur une machine à deux écrans, le moniteur
externe resterait bleu pendant que le portable vire à l'ocre. Ocre énumère donc
les affichages attachés au bureau avec `EnumDisplayDevices`, ouvre un contexte
par écran et pose la même rampe sur chacun. Un écran qui la refuse — certains
moniteurs externes n'ont pas de table gamma — ne prive pas les autres du
filtre.

Les contextes restent ouverts d'une pose à l'autre : les rouvrir à chaque cran
coûterait plus cher que la rampe elle-même, et la molette en demande plusieurs
dizaines par seconde. Le chien de garde les referme quand le nombre d'écrans
change.

**La même rampe partout n'est pourtant pas toujours ce qu'on veut.** Une dalle
de portable et un IPS externe n'ont pas la même température native : à 60 %
l'un vire à l'orange quand l'autre reste jaune, et il n'existe pas de réglage
unique qui aille aux deux. Une bascule *Régler chaque écran séparément* donne
alors à chacun son intensité et sa luminosité.

Elle **n'apparaît que s'il y a de quoi choisir**. Sur une machine à un seul
écran, la question n'a pas d'objet, et une bascule sans objet vole de la
hauteur à une fenêtre qui n'en a plus. Branchez un second écran, rouvrez les
réglages : la section est là, avec un sélecteur nommant chaque moniteur.
Débranchez-le, elle repart — le réglage, lui, reste écrit et redeviendra actif
au rebranchement suivant.

Séparés, un raccourci doit bien s'appliquer quelque part, et les deux gestes ne
désignent pas la même chose : **au clavier** on règle l'écran de la fenêtre
active, celui qu'on regarde ; **à la molette** celui qu'elle survole, puisque
la main y est déjà. La pastille suit, et s'affiche sur l'écran concerné plutôt
que toujours sur le principal — une réponse qui apparaît derrière soi ne
répond pas.

Reconnaître un écran d'une session à l'autre demande un identifiant stable.
C'est le `DeviceID` du moniteur, du genre `MONITOR\ACR0429\{4d36e96e-...}\0001`,
qui porte le code constructeur et le modèle lus dans l'EDID ; le suffixe
numérique sépare deux exemplaires identiques. Ni le `HMONITOR` ni le nom
`\.\DISPLAY1` ne conviennent : tous deux changent au gré des branchements.

## La luminosité

La rampe sait aussi assombrir : un facteur appliqué aux trois canaux à
l'identique, donc sans déplacer la teinte. Sur un portable c'est un bon
procédé, parce qu'il descend l'écran **sous le minimum du rétroéclairage**, ce
que le matériel ne sait pas faire — utile la nuit, quand la luminosité au plus
bas reste encore trop forte.

Sur un moniteur de bureau, c'est le mauvais. Le rétroéclairage y reste à fond
et l'on ne fait qu'écraser les niveaux : le noir cesse d'être noir, le
contraste s'effondre. C'est le problème que Twinkle Tray et Monitorian
résolvent, et le seul reproche sérieux qu'on pouvait faire au curseur d'Ocre.

Les deux se complètent au lieu de se concurrencer :

```
    100 %  ......  le materiel a fond
      |            on descend le retroeclairage
     25 %  ......  le materiel a son plancher
      |            la rampe gamma prend le relais
      0 %  ......  aussi sombre que cette machine sait l'etre
```

Deux mécanismes selon l'écran, et ils n'ont rien en commun. **DDC/CI**
(`dxva2.dll`) parle au moniteur par le câble vidéo : c'est le seul moyen pour
un écran externe, et c'est lent — une cinquantaine de millisecondes par
écriture, là où la molette en demanderait plusieurs dizaines par seconde. Les
écritures sont donc regroupées sur 120 ms, comme le sont déjà celles du
fichier de configuration. **WMI** (`WmiMonitorBrightnessMethods`) pilote la
dalle intégrée d'un portable ; c'est le même chemin que le curseur de Windows,
donc le même réglage : la valeur trouvée au démarrage est relevée et rendue en
sortant, exactement comme la rampe.

Le plancher matériel n'est pas le minimum annoncé mais un dixième de la course
au-dessus. Sur beaucoup de dalles, zéro éteint franchement le rétroéclairage —
et un écran noir emporte avec lui la commande qui permettrait de remonter. Le
dixième restant est rendu par la rampe, qui elle ne descend pas sous 0,30 pour
la même raison.

Les touches Fn du portable et le curseur de Windows écrivent la même valeur
qu'Ocre. Il la relit donc, toutes les dix secondes et avant de quitter, et la
compare à ce qu'il a posé en dernier. Si elle a bougé, c'est quelqu'un
d'autre : Ocre **adopte** le changement — son curseur de luminosité se
recale dessus au lieu de l'écraser au geste suivant — et, en quittant, ne
rend la valeur du matin que si c'est encore la sienne qui est en place.
Rendre la valeur du matin par-dessus un réglage fait à la main dans la
journée était une surprise. Deux unités de tolérance absorbent les moniteurs
qui arrondissent ce qu'on leur écrit, sans quoi 58 relu pour 57 écrit
passerait pour un réglage extérieur, adopté, réécrit, relu, sans fin.
La relecture n'a lieu que si quelqu'un a touché au clavier ou à la souris
depuis le tour précédent : une touche Fn est une touche, le curseur de
Windows se prend à la souris, et une lecture DDC coûte trente à cent
millisecondes de bus I2C que certains moniteurs n'aiment pas subir sans
arrêt.

Un moniteur qui n'a pas de table de luminosité, un pilote qui refuse, une
stratégie d'entreprise qui ferme WMI : le curseur retombe alors sur la rampe
seule, et couvre toute sa course avec elle. Le bas du curseur veut toujours
dire *aussi sombre que possible*, quelle que soit la machine.
[`tools/sonde-ecrans.ahk`](../../tools/sonde-ecrans.ahk) dit ce que la vôtre sait
faire, sans rien modifier.

## Et en HDR

Deux modes de Windows ignorent la table gamma, et pour la même raison. En **HDR**, Windows compose en virgule flottante 10 ou 16 bits et **ne consulte
plus la table gamma** : `SetDeviceGammaRamp` réussit, et ne fait rien. Ocre
poserait sa rampe, l'icône se teinterait, la pastille dirait « 60 % » — et
l'écran resterait bleu. Le pire cas pour une application de ce genre : un échec
muet.

La rampe multiplie chaque canal par un coefficient. **Une matrice de couleur
du compositeur fait exactement la même chose** — c'est l'API Magnification,
celle que Windows emploie pour ses filtres d'accessibilité — et le
compositeur, lui, tourne aussi en HDR. Quand un écran est en HDR, la teinte
passe donc par cette matrice ([`lib/Compositeur.ahk`](../../lib/Compositeur.ahk))
au lieu de la rampe. Mesuré en SDR, les deux voies donnent le même résultat
au chiffre près : un blanc sous 60 % vaut (255, 188, 133) par l'une comme par
l'autre. Le gris s'y compose par produit de matrices.

Deux choses à savoir. L'effet est **plein écran** : en HDR, les réglages par
écran s'appliquent à tous, sous la valeur de l'écran regardé. Et en HDR le
compositeur travaille en lumière linéaire là où la rampe multipliait des
valeurs encodées : le coefficient y est élevé à la puissance 2,2 pour que
60 % en HDR ressemble à 60 % en SDR. Cet exposant est la valeur théorique de
la courbe sRGB ; il n'a pas encore été mesuré sur un écran HDR allumé.

La détection ([`lib/Hdr.ahk`](../../lib/Hdr.ahk)) mérite un mot, parce que la
première API essayée **ment**. `GET_ADVANCED_COLOR_INFO` (Windows 10) lève
« couleur avancée active » aussi bien pour le HDR que pour la gestion
automatique des couleurs (ACM), que Windows 11 active tout seul sur les dalles
à gamme étendue — et qui, elle, laisse la rampe intacte. Sur la machine de
développement : drapeau à 1, HDR éteint, Ocre fonctionne. S'y fier aurait fait
basculer sur le compositeur des gens pour qui la rampe marche très bien.
`GET_ADVANCED_COLOR_INFO_2` (Windows 11 24H2) distingue SDR, WCG et HDR ;
c'est elle qu'on lit. Sur un Windows plus ancien, on conclut « pas HDR », et
la clé `voie = compositeur` de `ocre.ini` force la voie à la main.

Et le WCG, la *gestion automatique des couleurs* que Windows 11 active tout
seul sur les dalles à gamme étendue ? La rampe y marche. On a cru un temps le
contraire, et fait basculer Ocre sur le compositeur dès le mode WCG : le
curseur de la souris, que la matrice du compositeur ne touche pas, restait
blanc, et la teinte était plus faible qu'à la rampe — le compositeur compose
en linéaire sous WCG sans que l'exposant 2,2 ne soit appliqué. Mesuré à l'œil
depuis : en WCG, une rampe (1 ; 0,3 ; 0) posée par `SetDeviceGammaRamp` teinte
l'écran très visiblement. `Hdr.RampeIgnoree` ne bascule donc qu'en vrai HDR ;
en cas de doute, la clé `voie` de `ocre.ini` tranche à la main.

## La chambre noire

Cousine du mode *Darkroom* de f.lux : l'image rendue sur le seul canal
rouge. Ce qui est sombre reste noir, ce qui est clair devient rouge, et
l'écran n'émet que la lumière qui dérange le moins une vision adaptée à
l'obscurité. Avec des applications en mode sombre, c'est du texte rouge sur
fond noir — l'effet cherché, sans rien d'autre.

f.lux, lui, inverse l'image en plus. C'était pensé pour des fonds blancs, qui
devenaient noirs ; sur des applications déjà sombres, l'inversion fait
l'inverse du but, chaque fond noir devenant rouge vif — et les photos
passent en négatif. Ocre n'inverse pas.

C'est une matrice de plus posée par le compositeur (`Compositeur.CHAMBRE`),
et un état de session : ni raccourci, ni case dans les réglages, ni clé dans
`ocre.ini`, et une session s'ouvre toujours en couleur. Seule une ligne du
panneau du clic droit y mène et en sort. La luminosité continue d'assombrir ;
le gris, lui, n'a plus rien à faire et n'est pas composé.

## Reposer le filtre de force

Un jeu plein écran, une sortie de veille ou un changement de mode couleur peut
effacer l'effet du compositeur, que le chien de garde ne surveille pas comme il
surveille la rampe. Trois choses le remettent : les messages `WM_DISPLAYCHANGE`
et compagnie appellent `Filtre.Forcer`, qui vide la détection HDR/WCG et le
cache du compositeur avant de reposer ; un bouton **Réappliquer**, à côté de la
case du gris, fait la même chose à la main ; et `Ocre.exe /gris` bascule le gris
seul, utile pour vérifier d'un coup.

## Chien de garde

Windows réinitialise la rampe de lui-même après une sortie de veille, un
changement de résolution, une invite UAC ou la sortie d'un jeu plein écran.

Trois de ces quatre cas s'annoncent, et Ocre les écoute plutôt que de les
attendre : `WM_DISPLAYCHANGE` pour la résolution et les branchements d'écran,
`WM_POWERBROADCAST` pour la veille, `WM_WTSSESSION_CHANGE` pour le verrouillage
et le changement de session. La rampe revient alors dans la milliseconde. Comme
le pilote n'a pas toujours fini de reconfigurer l'affichage quand le message
arrive, elle est reposée une seconde fois 1,2 s plus tard : une pose de trop ne
coûte rien, une pose trop tôt est perdue.

Reste l'invite UAC, qui n'annonce rien. Un sondage toutes les 10 secondes la
couvre, et ne sert plus qu'à cela.
