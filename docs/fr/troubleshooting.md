# Dépannage

[← Ocre](../../README.fr.md#documentation) · [English](../en/troubleshooting.md)

## Si l'écran reste chaud

La rampe n'appartient pas à l'application : c'est un état global du pilote
graphique. Ocre la rend en sortant, mais un « Fin de tâche » dans le
gestionnaire des tâches ne laisse rien s'exécuter, et l'écran garde sa teinte
sans qu'aucune commande visible ne permette d'y revenir.

```
Ocre.exe /reset
```

remet l'écran à plat et arrête Ocre.

## Si les raccourcis ne répondent pas

Sur beaucoup de portables (Acer notamment), le **Fn-lock** est en mode
multimédia : `F5` et `F6` déclenchent la luminosité au niveau du firmware et
n'atteignent jamais Windows. Aucun script ne peut les intercepter dans cet
état.

- **`Fn` + `Esc`** sur la plupart des Acer, ou
- BIOS (`F2` au démarrage) > **Main** > **Function key behavior** > **Function key**

La luminosité passe alors sur `Fn+F5` / `Fn+F6`.

Attention en réaffectant une touche : sur ces mêmes machines, `Ctrl+F7`
déclenche la projection d'écran au niveau firmware, ce que la capture
enregistre comme `Win+P`. Le bouton *Réinitialiser* remet les six raccourcis
d'origine.

### Si l'écran vire au gris quand Ocre se coupe

Ce n'est pas Ocre : c'est le **filtre de couleur** de Windows (Accessibilité >
Filtres de couleur), en mode niveaux de gris. Tant qu'Ocre est actif, l'ocre le
masque ; dès qu'il se coupe, le gris apparaît.

Il s'allume parce que Windows lui donne un raccourci, `Win+Ctrl+C`, actif par
défaut. Le firmware de ces mêmes portables injectant une touche Win dans les
combinaisons `Fn+F7`, la bascule d'Ocre déclenche les deux à la fois.
`install.ps1` désactive ce raccourci — le filtre lui-même reste disponible
dans les Paramètres pour qui s'en sert. À la main :

```
HKCU\Software\Microsoft\ColorFiltering
  HotkeyEnabled  (REG_DWORD)  =  0
```

### Le noir profond, pour les dalles OLED

Sur un écran OLED, un pixel noir est éteint, et un pixel gris très sombre
est allumé. Or presque aucune application n'écrit du noir : le mode sombre
de Notion et de Discord est `#191919` (niveau 25 sur 255), celui de VS Code
`#1E1E1E` (30), Spotify `#121212` (18). Sur une dalle qui sait faire un vrai
noir, tout cela est une lueur grise uniforme — et le contraste infini de
l'écran ne sert à rien.

La bascule **Noir profond (OLED)** des réglages envoie au noir pur tout
niveau inférieur ou égal à un seuil, et étire ce qui est au-dessus pour que
le blanc reste le blanc. C'est la même rampe gamma que le filtre, donc le
même mécanisme, sans rien changer aux applications, et il **suit le filtre**
comme le gris : `Ctrl+F7` l'emporte avec la teinte, en fondu — le seuil
descend cran par cran avec l'intensité —, et le rétablit avec elle. Notion, Discord, VS
Code, le terminal et l'explorateur deviennent noirs d'un coup, partout. Le
seuil se règle de 4 en 4, de 4 à 64 ; 28 par défaut, qui prend Notion et
Discord (25) et épargne VS Code (30) — 32 les prend tous. Chaque cran de
plus bouche un peu plus les ombres des photos et des films : c'est le prix,
et il est visible dès 40. En HDR, où la rampe est ignorée, la même
opération passe par la matrice du compositeur, avec le seuil converti en
lumière linéaire.

Dans `ocre.ini`, `noir` est le seuil en service (0 = coupé) et `noir_seuil`
celui qu'on retrouve en rallumant ; `/get` rend `noir=`. Le chien de garde
le surveille comme le reste de la rampe : il relit l'entrée du seuil, qui
doit valoir zéro.

### Le gris, couplé au filtre

Certains lisent le soir en gris **et** en chaud : le gris ôte la couleur qui
accroche l'œil, le chaud ôte le bleu qui tient éveillé. Une bascule *Passer
l'écran en niveaux de gris avec le filtre* fait suivre le gris au filtre :
allumé dès qu'Ocre l'est, coupé avec lui. Une seule commande pose les deux
états, et c'est ce qui les empêche de se désynchroniser — le problème
d'origine.

Piloter le filtre de Windows a été essayé et écarté, mesures à l'appui. Sa clé
`Active` n'est pas relue à chaud : écrite, elle ne change rien avant la
prochaine bascule dans les Paramètres. Son raccourci passe par `atbroker.exe`,
qui refuse dès que le raccourci est désactivé — et il faut le désactiver,
c'est le paragraphe précédent.

Ocre pose donc **son** gris, par l'API Magnification
(`MagSetFullscreenColorEffect`), qui est le mécanisme que Windows emploie
lui-même en dessous : une matrice de couleur appliquée à tout le bureau par le
compositeur. C'est instantané, sans registre, et **l'effet appartient au
processus** : un « Fin de tâche » rend l'écran à la couleur, là où le filtre de
Windows serait resté.

Un piège, qui a coûté une heure et mérite d'être écrit. `DllCall` charge une
DLL, appelle, puis la **décharge** si rien d'autre ne la retient — c'est
documenté. `MagInitialize` s'exécutait, la bibliothèque était libérée avec son
état, et l'appel suivant tombait sur une bibliothèque vierge :
`ERROR_INVALID_FUNCTION`, sans autre explication, alors que le même appel
depuis Python réussissait. Un `LoadLibrary` explicite, gardé le temps du
processus, règle tout ([`lib/Compositeur.ahk`](../../lib/Compositeur.ahk)).

## Signaler un problème

Ouvrez **Réglages > À propos… > Copier le diagnostic** (ou lancez `Ocre.exe /diag` et
copiez ce qu'il écrit) et collez-le dans un
[nouveau ticket](https://github.com/kovarci/ocre/issues/new/choose). Il contient les
versions d'Ocre et de Windows, les écrans, si le garde-fou gamma est levé, si un autre
outil de couleur tourne, et l'état des réglages qui comptent — ni nom d'utilisateur, rien
de personnel. Avec lui, la plupart des signalements se traitent sans aller-retour de
questions. Si Ocre a affiché une boîte d'erreur, `erreurs.log`, dans `%APPDATA%\Ocre` (le
bouton *Dossier des réglages* de la fenêtre À propos l'ouvre), en a la pile d'appels.
