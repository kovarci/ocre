# Depannage

[← Ocre](../../README.fr.md#documentation) · [English](../en/troubleshooting.md)

## Si l'ecran reste chaud

La rampe n'appartient pas a l'application : c'est un etat global du pilote
graphique. Ocre la rend en sortant, mais un « Fin de tache » dans le
gestionnaire des taches ne laisse rien s'executer, et l'ecran garde sa teinte
sans qu'aucune commande visible ne permette d'y revenir.

```
Ocre.exe /reset
```

remet l'ecran a plat et arrete Ocre.


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
processus, regle tout ([`lib/Compositeur.ahk`](../../lib/Compositeur.ahk)).

## Signaler un probleme

Ouvrez **Reglages > A propos... > Copier le diagnostic** (ou lancez `Ocre.exe /diag` et
copiez ce qu'il ecrit) et collez-le dans un
[nouveau ticket](https://github.com/kovarci/ocre/issues/new/choose). Il contient les
versions d'Ocre et de Windows, les ecrans, si le garde-fou gamma est leve, si un autre
outil de couleur tourne, et l'etat des reglages qui comptent -- ni nom d'utilisateur, rien
de personnel. Avec lui, la plupart des signalements se traitent sans aller-retour de
questions. Si Ocre a affiche une boite d'erreur, `erreurs.log`, dans `%APPDATA%\Ocre` (le
bouton *Dossier des reglages* de la fenetre A propos l'ouvre), en a la pile d'appels.