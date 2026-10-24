# Installation

[← Ocre](../../README.fr.md#documentation) · [English](../en/installation.md)

## L'installateur

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

### Retour arriere

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


## Sans installateur

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


## Pourquoi une tache planifiee plutot qu'un raccourci

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


## SmartScreen

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
