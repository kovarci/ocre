# Construire, tester, arborescence

[← Ocre](../../README.fr.md#documentation) · [English](../en/development.md)

Il faut [AutoHotkey v2](https://www.autohotkey.com/) et PowerShell, rien d'autre pour
lancer depuis les sources. Le code est en français (noms, commentaires), par choix ;
l'interface et la documentation existent dans les deux langues. Les conventions sont
dans [CONTRIBUTING.md](../../CONTRIBUTING.md) (en anglais).

## Les commandes

| Pour faire ceci | Lancer |
|---|---|
| Lancer depuis les sources | `AutoHotkey64.exe .\Ocre.ahk` |
| Construire `Ocre.exe`, sans installer ni toucher au registre | `.\install.ps1 -Build -NoStart -NoStartup -NoRegistry` |
| Installer depuis un clone : lever le garde-fou gamma, construire s'il manque, tâche de démarrage, lancer | `.\install.ps1` (en administrateur la première fois) |
| Construire l'installateur | `.\tools\installer.ps1` |
| Tout : construire, tester, archiver, installateur → `dist\` | `.\tools\release.ps1` |
| La suite de tests | `.\tools\test.ps1` |
| Installation / mise à jour / retour arrière de l'installateur | `.\tools\test-installateur.ps1` |
| Les liens de la documentation | `.\tools\liens.ps1` |
| Les captures de `docs/img` | `.\tools\captures.ps1` |

C'est la compilation en exécutable qui donne une entrée propre au gestionnaire des
tâches : sans elle, Windows affiche `AutoHotkey64.exe` avec son icône verte, puisque c'est
l'interpréteur qui démarre.

**Laissez l'éclairage nocturne de Windows désactivé** pendant que vous travaillez dessus :
les deux filtres se cumuleraient. La fenêtre des réglages le signale en rouge s'il est
programmé.

## Les tests

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test.ps1
```

rend le nombre de tests en échec. L'interpréteur AutoHotkey est nécessaire : les tests ne
sont pas compilés. Dans l'ordre :

| Test | Ce qu'il vérifie | Demande |
|---|---|---|
| `test-courbe` | la courbe, le planificateur, la configuration — du pur calcul | rien |
| `test-soleil` | le calcul solaire, contre des valeurs d'une implémentation indépendante | rien |
| `test-cli` | Kelvin, unité, respiration, raccourcis, export ; le français et l'anglais ont les mêmes clés ; la tâche de démarrage, créée pour de bon ; la ligne de commande elle-même, en sous-processus, jugée sur ses codes de retour et sa sortie | rien (une console, pour la ligne de commande) |
| `test-ui` | chaque fenêtre, ouverte avec une configuration jetable, cliquée, vérifiée et photographiée dans `%TEMP%\ocre-test-ui` | le bureau, une vingtaine de secondes ; ne pose aucune rampe |
| `test-fuites` | redessine huit cents fois tout ce qui se redessine, et compare les compteurs du gestionnaire des tâches avant et après | le bureau |
| `test-perf` | chronomètre le chargement de tout ce qu'Ocre charge (moins d'une seconde et demie, interpréteur compris ; 125 ms sur la machine de développement) et mesure le processeur au repos, minuteurs en marche, puis celui d'`Ocre.exe` lui-même s'il tourne (moins d'un pour cent d'un cœur ; un demi pour cent mesuré souris en mouvement, zéro sans — le hook souris de la molette sur l'icône est le seul coût) | |
| `test-clamp` (`-Clamp`) | pose une rampe extrême sur **vos écrans** pendant une demi-seconde pour vérifier que Windows ne la rogne pas | seulement sur demande |

Les rappels vers le programme sont remplacés par des fonctions qui notent ce qu'on leur
demande : aucun test ne touche à vos vrais réglages ni ne pose de rampe. `test-ui` attrape
ce que les tests de calcul ne voient pas : un bouton dont la fermeture a capturé la
mauvaise variable, deux noms qui ne diffèrent que par la casse. `test-fuites` a trouvé, le
jour de son écriture, que chaque redessin laissait trois objets GDI derrière lui — voir
[Le logo](interface.md#le-logo).

Deux détails de `test-ui` valent d'être connus si l'on en écrit d'autres : un clic envoyé
par `SendInput` se perd dès qu'un autre processus tient un hook souris — Ocre en tient un
pour la molette sur son icône —, on poste donc l'enfoncement et le relâchement au
contrôle lui-même ; et une flèche envoyée dans la foulée d'une tabulation arrive avant que
le curseur soit pris, d'où une touche à la fois. `OCRE_TEST_LANGUE=en` le rejoue en
anglais, ce qui sert à prendre les captures anglaises.

Hors de la suite, [`tools/test-installateur.ps1`](../../tools/test-installateur.ps1) joue
l'installateur sans élévation, sur des clés factices (voir
[Installation](installation.md#retour-arrière)), et
[`tools/liens.ps1`](../../tools/liens.ps1) vérifie les liens de la documentation. Sur
GitHub, [`ci.yml`](../../.github/workflows/ci.yml) lance les deux, avec les tests de calcul
et de ligne de commande et la construction, à chaque changement.

## Arborescence

### Le programme

| | |
|---|---|
| [`Ocre.ahk`](../../Ocre.ahk) | le programme : raccourcis, icône, chien de garde, ligne de commande |
| [`lib/Config.ahk`](../../lib/Config.ahk) | réglages persistés, mode portable et démarrage automatique |
| [`lib/I18n.ahk`](../../lib/I18n.ahk) | textes français et anglais |

### Le filtre

| | |
|---|---|
| [`lib/Gamma.ahk`](../../lib/Gamma.ahk) | la courbe d'intensité et la rampe qui la porte |
| [`lib/Ecrans.ahk`](../../lib/Ecrans.ahk) | quels sont les écrans, et lequel on regarde |
| [`lib/Retro.ahk`](../../lib/Retro.ahk) | le rétroéclairage matériel, DDC/CI et WMI |
| [`lib/Filtre.ahk`](../../lib/Filtre.ahk) | l'état du filtre et sa pose sur les écrans |
| [`lib/Fondu.ahk`](../../lib/Fondu.ahk) | adoucir un changement fait à la main |
| [`lib/Compositeur.ahk`](../../lib/Compositeur.ahk) | une matrice de couleur sur tout le bureau : le gris, et la teinte en HDR |
| [`lib/Hdr.ahk`](../../lib/Hdr.ahk) | l'écran est-il en HDR |
| [`lib/Concurrents.ahk`](../../lib/Concurrents.ahk) | le Night Light et le filtre de couleur de Windows sont-ils actifs |
| [`lib/Unite.ahk`](../../lib/Unite.ahk) | pour cent ou Kelvin, à l'affichage |

### Le planificateur et les lieux

| | |
|---|---|
| [`lib/Horaire.ahk`](../../lib/Horaire.ahk) | le planificateur et son fondu |
| [`lib/Soleil.ahk`](../../lib/Soleil.ahk) | lever et coucher du soleil, calculés sur place |
| [`lib/Villes.ahk`](../../lib/Villes.ahk) | la recherche d'une ville, et les exonymes |
| [`lib/villes.txt`](../../lib/villes.txt) | 26 700 villes, lues à la première recherche |
| [`lib/Pays.ahk`](../../lib/Pays.ahk) | noms de pays, et la mise à plat des accents |
| [`lib/Fuseau.ahk`](../../lib/Fuseau.ahk) | un lieu approximatif, déduit du fuseau horaire |

### Les conforts

| | |
|---|---|
| [`lib/Rappel.ahk`](../../lib/Rappel.ahk) | la règle des 20-20-20, par l'icône qui respire |
| [`lib/Inactif.ahk`](../../lib/Inactif.ahk) | assombrir l'écran qu'on ne regarde plus |
| [`lib/Batterie.ahk`](../../lib/Batterie.ahk) | baisser la luminosité quand le chargeur est débranché |
| [`lib/Adaptatif.ahk`](../../lib/Adaptatif.ahk) | la luminosité qui suit le contenu de l'écran |
| [`lib/Capture.ahk`](../../lib/Capture.ahk) | la luminance moyenne d'un écran, par duplication DXGI |
| [`lib/Habitudes.ahk`](../../lib/Habitudes.ahk) | apprendre ce qu'on règle à la main, et le faire soi-même |

### L'interface

| | |
|---|---|
| [`lib/Ui.ahk`](../../lib/Ui.ahk) | surface de dessin GDI+ et suivi du survol |
| [`lib/Cadre.ahk`](../../lib/Cadre.ahk) | une fenêtre redimensionnable autour d'un contenu fixe : centrage, ascenseur |
| [`lib/Widgets.ahk`](../../lib/Widgets.ahk) | bouton, bascule, curseur, compteur, champ, drapeau, clavier, alerte |
| [`lib/Theme.ahk`](../../lib/Theme.ahk) | palette et mise au sombre des éléments système |
| [`lib/Blob.ahk`](../../lib/Blob.ahk) | le logo dessiné à chaud |
| [`lib/Police.ahk`](../../lib/Police.ahk) | la police Inter de la pastille, chargée depuis la ressource de l'exe |
| [`lib/Osd.ahk`](../../lib/Osd.ahk) | la pastille d'intensité |
| [`lib/Panneau.ahk`](../../lib/Panneau.ahk) | le panneau du clic droit |
| [`lib/Reglages.ahk`](../../lib/Reglages.ahk) | la fenêtre de configuration |
| [`lib/Apropos.ahk`](../../lib/Apropos.ahk) | la fenêtre À propos : version, liens, diagnostic à copier, licences |
| [`lib/Planificateur.ahk`](../../lib/Planificateur.ahk) | la fenêtre du planificateur |
| [`lib/Lieu.ahk`](../../lib/Lieu.ahk) | la fenêtre du lieu |
| [`lib/Prereglages.ahk`](../../lib/Prereglages.ahk) | la fenêtre des trois préréglages |
| [`lib/Raccourcis.ahk`](../../lib/Raccourcis.ahk) | la fenêtre des raccourcis, et leur test |
| [`lib/Apprentissage.ahk`](../../lib/Apprentissage.ahk) | la fenêtre des habitudes |

### Embarqué, et ses licences

| | |
|---|---|
| [`lib/Inter-Medium.ttf`](../../lib/Inter-Medium.ttf), [`lib/Inter-LICENSE.txt`](../../lib/Inter-LICENSE.txt) | la police et sa licence (SIL OFL 1.1) |
| [`lib/AutoHotkey-LICENSE.txt`](../../lib/AutoHotkey-LICENSE.txt) | la licence (GPL v2) de l'interpréteur embarqué dans `Ocre.exe` |

### Construire, publier

| | |
|---|---|
| [`install.ps1`](../../install.ps1) | installe depuis un clone ou l'archive : garde-fou gamma, construction, tâche de démarrage, lancement |
| [`installer/`](../../installer/) | le script Inno Setup de l'installateur, et `utilisateur.ps1`, ce qu'il pose dans le compte de l'utilisateur (tâche de démarrage) |
| [`tools/installer.ps1`](../../tools/installer.ps1) | construit `dist\Ocre-<version>-setup.exe` avec Inno Setup (récupéré par winget au besoin) |
| [`tools/release.ps1`](../../tools/release.ps1) | construit, teste, vérifie les ressources, range le tout dans `dist\Ocre-<version>.zip` et construit l'installateur |
| [`tools/outils-ci.ps1`](../../tools/outils-ci.ps1), [`tools/archive.ps1`](../../tools/archive.ps1) | la chaîne de construction épinglée (versions et empreintes) ; l'archive `.zip`, partagée avec `release.ps1` |
| [`tools/sign.ps1`](../../tools/sign.ps1) | signe `Ocre.exe` et l'installateur, quand on a un certificat |
| [`tools/make-icon.ps1`](../../tools/make-icon.ps1) | génère `Ocre.ico` |
| [`tools/make-villes.ps1`](../../tools/make-villes.ps1) | régénère la table des villes depuis GeoNames |
| [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) | à chaque changement : les tests, la construction, le parcours installation / mise à jour / retour arrière de l'installateur, les liens de la doc |
| [`.github/workflows/release.yml`](../../.github/workflows/release.yml) | sur un tag : construit, fait signer (SignPath), publie la release ; [`.signpath/`](../../.signpath/) en décrit les artefacts |

### Tests et sondes

| | |
|---|---|
| [`tools/test.ps1`](../../tools/test.ps1) | lance les tests et compte les échecs |
| [`tools/test-courbe.ahk`](../../tools/test-courbe.ahk) | vérifie la courbe et le planificateur, sans matériel |
| [`tools/test-soleil.ahk`](../../tools/test-soleil.ahk) | vérifie le calcul solaire contre une autre implémentation |
| [`tools/test-cli.ahk`](../../tools/test-cli.ahk) | Kelvin, unité, respiration, raccourcis, export, traductions, ligne de commande |
| [`tools/test-ui.ahk`](../../tools/test-ui.ahk) | chaque fenêtre, ouverte, cliquée, photographiée |
| [`tools/test-fuites.ahk`](../../tools/test-fuites.ahk) | ce qui se dessine mille fois ne laisse-t-il rien ? |
| [`tools/test-perf.ahk`](../../tools/test-perf.ahk) | le démarrage est-il rapide, le repos silencieux ? |
| [`tools/test-clamp.ahk`](../../tools/test-clamp.ahk) | vérifie que la rampe n'est pas rognée |
| [`tools/test-installateur.ps1`](../../tools/test-installateur.ps1) | joue l'installateur d'essai — installation, mise à jour, retour arrière — sans élévation, sur des clés factices |
| [`tools/sonde-ecrans.ahk`](../../tools/sonde-ecrans.ahk) | ce qu'Ocre voit de vos écrans, sans rien modifier |
| [`tools/sonde-touches.ahk`](../../tools/sonde-touches.ahk) | quelles touches parviennent réellement à Windows |
| [`tools/sonde-luminosite.ahk`](../../tools/sonde-luminosite.ahk) | la touche de luminosité est-elle visible du logiciel |

### Documentation et recherche

| | |
|---|---|
| [`docs/`](../../docs/) | cette documentation (`en`, `fr`) et ses captures (`img`) |
| [`tools/liens.ps1`](../../tools/liens.ps1) | les liens des fichiers Markdown mènent-ils quelque part ? |
| [`tools/captures.ps1`](../../tools/captures.ps1) | régénère les captures de `docs/img`, dans les deux langues |
| [`tools/social-preview.ps1`](../../tools/social-preview.ps1) | dessine l'image 1280 × 640 qu'affichent les liens vers le dépôt (`docs/img/social-preview.png` ; à téléverser à la main dans les paramètres du dépôt) |
| [`recherche/`](../../recherche/) | le Night Light natif : codec, CLI, sauvegardes du registre |
