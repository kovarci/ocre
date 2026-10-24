# Installation

[← Ocre](../../README.fr.md#documentation) · [English](../en/installation.md)

## L'installateur

Le plus simple : `Ocre-<version>-setup.exe`, dans les Releases GitHub. Un
double-clic, un assistant, et Ocre s'installe comme n'importe quelle
application — dans Program Files, avec un raccourci du menu Démarrer, une
entrée dans Paramètres > Applications pour le retirer, et, au choix, le
lancement à l'ouverture de session. Il pose `GdiIcmGammaRange` (c'est pour
cette clé HKLM qu'il demande l'élévation) et désactive `Win+Ctrl+C` (voir plus
bas) ; la désinstallation arrête Ocre proprement, retire la tâche de démarrage
et rétablit `Win+Ctrl+C`. Pour mettre à jour, on lance la version suivante par
dessus : Ocre est arrêté puis remplacé, les réglages restent.

En silence, pour un déploiement :

```
Ocre-<version>-setup.exe /VERYSILENT /TASKS="demarrage,filtres"
```

Tant que l'installateur n'est pas signé, Windows affiche « Windows a protégé
votre ordinateur » : voir « SmartScreen » plus bas.

### Retour arrière

Avant de toucher à Windows, l'installateur note ce qu'il va changer, dans
`C:\Program Files\Ocre\sauvegarde\` :

- `avant-installation.reg` : les valeurs de registre d'origine
  (`GdiIcmGammaRange`, `HotkeyEnabled`). Un double-clic — ou le raccourci
  « Ocre - restaurer les réglages Windows d'origine » du menu Démarrer — et
  Windows retrouve son état d'avant, Ocre installé ou non. Une valeur qui
  n'existait pas s'y lit `"nom"=-` : elle est supprimée.
- `avant-installation.ini` : la même chose, pour la désinstallation.

C'est valeur par valeur, jamais une clé entière : l'export d'une clé
écraserait aussi ce que vous avez changé depuis. L'état noté est celui
**d'avant la première installation** ; une mise à jour ne le réécrit pas.

La désinstallation ne rend que ce que l'installation a vraiment changé — si
`GdiIcmGammaRange` valait déjà 256, elle n'y touche pas — et seulement si la
valeur est encore celle que l'installation a posée : ce qu'un autre outil a
réglé depuis n'est pas à elle. Le dossier `sauvegarde\` part avec le reste.
`tools/test-installateur.ps1` joue tout cela (installation, mise à jour,
retrait, quatre états de départ) sans élévation, sur des clés factices.

## Sans installateur

Deux façons : l'archive `Ocre-<version>.zip` des Releases GitHub — l'exécutable,
`install.ps1` et les licences, rien à construire —, ou le dépôt entier, où
`install.ps1` construit l'exécutable s'il manque (AutoHotkey v2 et son
compilateur sont récupérés au besoin). Dans les deux cas, depuis le dossier
décompressé ou cloné :

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**À lancer en administrateur la première fois**, pour poser `GdiIcmGammaRange`
s'il manque (une clé HKLM). La tâche planifiée de démarrage, elle, se crée
sans élévation ; seul le remplacement d'une tâche posée par une version
précédente la demande, et le script le dit le cas échéant.

Le script désactive aussi `Win+Ctrl+C`, le raccourci des filtres de couleur
de Windows, qui entre en collision avec `Ctrl+F7` sur certains portables
(voir plus bas) ; `install.ps1 -Uninstall` le rétablit.

## Pourquoi une tâche planifiée plutôt qu'un raccourci

Un raccourci déposé dans le dossier Démarrage n'est lancé par l'explorateur
qu'une fois le shell prêt, derrière toute la file des autres éléments de
démarrage. Mesure faite sur un portable chargé en services constructeur :

| | |
|---|---|
| Windows démarre à | 06:34:59 |
| Ocre lancé à | 06:35:45 |
| écart | **46 secondes** |

Alors que l'application s'initialise en 0,35 s. Le retard ne vient donc pas
d'elle. `StartupDelayInMSec` valait déjà 0 : ce n'est pas non plus le délai
configurable de Windows, mais la sérialisation des éléments de démarrage.

Une tâche déclenchée à l'ouverture de session échappe à cette file. Sa création
exige l'élévation ; sans elle, `install.ps1` se replie automatiquement sur le
raccourci, qui fonctionne mais reste soumis au même retard.

`Ocre.exe` est autonome : une fois construit, ni AutoHotkey ni le compilateur
ne sont nécessaires pour s'en servir. `-Build` force la régénération de
l'icône et la recompilation ; `-Uninstall` retire le raccourci de démarrage et
arrête l'application ; `-Test` lance les tests.

## SmartScreen

Au premier lancement chez quelqu'un d'autre, Windows affiche « Windows a
protégé votre ordinateur ». Ce n'est pas Ocre : c'est le sort de tout
exécutable **non signé** dont SmartScreen n'a jamais entendu parler, et un
exe AutoHotkey compilé y a droit plus qu'un autre — certains antivirus le
mettent même en quarantaine, l'interpréteur ayant servi à assez de
mauvaises choses. *Informations complémentaires > Exécuter quand même* passe
outre.

La réponse propre est une **signature de code**. `tools/sign.ps1` signe
`Ocre.exe` (SHA-256, horodaté) avec un certificat de signature de code trouvé
dans le magasin de l'utilisateur ou dans un PFX, et `install.ps1 -Build`
l'appelle de lui-même s'il en trouve un. Le certificat, lui, ne se fabrique
pas ici : [SignPath Foundation](https://signpath.org) signe gratuitement les
projets open source depuis leur dépôt GitHub — pourvu que le projet ait la
réputation vérifiable qu'ils demandent et construise depuis GitHub Actions (voir la
*Politique de signature* du README) ; Artifact Signing de Microsoft (ex-Trusted
Signing) coûte quelques euros par mois après vérification d'identité, mais n'est,
à notre connaissance, ouvert qu'aux organisations des États-Unis, du Canada, de
l'UE et du Royaume-Uni et aux particuliers des États-Unis et du Canada —
vérifiez sur la page de Microsoft ; un certificat OV classique, environ deux
cents euros par an. `-SelfSigned` en fabrique un de
test qui ne convainc personne, mais vérifie la chaîne.
