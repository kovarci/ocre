# Construire, tester, arborescence

[← Ocre](../../README.fr.md#documentation) · [English](../en/development.md)

## Les tests

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


## Arborescence

| | |
|---|---|
| [`Ocre.ahk`](../../Ocre.ahk) | le programme : raccourcis, icone, chien de garde, ligne de commande |
| [`lib/Gamma.ahk`](../../lib/Gamma.ahk) | la courbe d'intensite et la rampe qui la porte |
| [`lib/Ecrans.ahk`](../../lib/Ecrans.ahk) | qui sont les ecrans, et lequel on regarde |
| [`lib/Retro.ahk`](../../lib/Retro.ahk) | le retroeclairage materiel, DDC/CI et WMI |
| [`lib/Filtre.ahk`](../../lib/Filtre.ahk) | l'etat du filtre et sa pose sur les ecrans |
| [`lib/Fondu.ahk`](../../lib/Fondu.ahk) | adoucir un changement fait a la main |
| [`lib/Compositeur.ahk`](../../lib/Compositeur.ahk) | une matrice de couleur sur tout le bureau : le gris, et la teinte en HDR |
| [`lib/Hdr.ahk`](../../lib/Hdr.ahk) | l'ecran est-il en HDR |
| [`lib/Horaire.ahk`](../../lib/Horaire.ahk) | le planificateur et son fondu |
| [`lib/Unite.ahk`](../../lib/Unite.ahk) | pour cent ou Kelvin, a l'affichage |
| [`lib/Concurrents.ahk`](../../lib/Concurrents.ahk) | le Night Light et le filtre de couleur de Windows sont-ils actifs |
| [`lib/Soleil.ahk`](../../lib/Soleil.ahk) | lever et coucher du soleil, calcules sur place |
| [`lib/Villes.ahk`](../../lib/Villes.ahk) | la recherche d'une ville, et les exonymes |
| [`lib/villes.txt`](../../lib/villes.txt) | 26 700 villes, lues a la premiere recherche |
| [`lib/Pays.ahk`](../../lib/Pays.ahk) | noms de pays, et la mise a plat des accents |
| [`lib/Lieu.ahk`](../../lib/Lieu.ahk) | la fenetre du lieu |
| [`lib/Planificateur.ahk`](../../lib/Planificateur.ahk) | la fenetre du planificateur |
| [`lib/Prereglages.ahk`](../../lib/Prereglages.ahk) | la fenetre des trois prereglages |
| [`lib/Raccourcis.ahk`](../../lib/Raccourcis.ahk) | la fenetre des raccourcis, et leur test |
| [`lib/Rappel.ahk`](../../lib/Rappel.ahk) | la regle des 20-20-20, par l'icone qui respire |
| [`lib/Inactif.ahk`](../../lib/Inactif.ahk) | assombrir l'ecran qu'on ne regarde plus |
| [`lib/Batterie.ahk`](../../lib/Batterie.ahk) | baisser la luminosite quand le chargeur est debranche |
| [`lib/Adaptatif.ahk`](../../lib/Adaptatif.ahk) | la luminosite qui suit le contenu de l'ecran |
| [`lib/Capture.ahk`](../../lib/Capture.ahk) | la luminance moyenne d'un ecran, par duplication DXGI |
| [`lib/Habitudes.ahk`](../../lib/Habitudes.ahk) | apprendre ce qu'on regle a la main, et le faire soi-meme |
| [`lib/Apprentissage.ahk`](../../lib/Apprentissage.ahk) | la fenetre des habitudes |
| [`lib/Fuseau.ahk`](../../lib/Fuseau.ahk) | un lieu approximatif, deduit du fuseau horaire |
| [`lib/Blob.ahk`](../../lib/Blob.ahk) | le logo dessine a chaud |
| [`lib/Police.ahk`](../../lib/Police.ahk) | la police Inter de la pastille, chargee depuis la ressource de l'exe |
| [`lib/Inter-Medium.ttf`](../../lib/Inter-Medium.ttf), [`lib/Inter-LICENSE.txt`](../../lib/Inter-LICENSE.txt) | la police et sa licence (SIL OFL 1.1) |
| [`lib/AutoHotkey-LICENSE.txt`](../../lib/AutoHotkey-LICENSE.txt) | la licence (GPL v2) de l'interpreteur embarque dans `Ocre.exe` |
| [`lib/Ui.ahk`](../../lib/Ui.ahk) | surface de dessin GDI+ et suivi du survol |
| [`lib/Cadre.ahk`](../../lib/Cadre.ahk) | une fenetre redimensionnable autour d'un contenu fixe : centrage, ascenseur |
| [`lib/Widgets.ahk`](../../lib/Widgets.ahk) | bouton, bascule, curseur, compteur, champ, drapeau, clavier, alerte |
| [`lib/Osd.ahk`](../../lib/Osd.ahk) | la pastille d'intensite |
| [`lib/Panneau.ahk`](../../lib/Panneau.ahk) | le panneau du clic droit |
| [`lib/Reglages.ahk`](../../lib/Reglages.ahk) | la fenetre de configuration |
| [`lib/Apropos.ahk`](../../lib/Apropos.ahk) | la fenetre A propos : version, liens, diagnostic a copier, licences |
| [`lib/Theme.ahk`](../../lib/Theme.ahk) | palette et mise au sombre des elements systeme |
| [`lib/I18n.ahk`](../../lib/I18n.ahk) | textes francais et anglais |
| [`lib/Config.ahk`](../../lib/Config.ahk) | reglages persistes, mode portable et demarrage automatique |
| [`tools/make-icon.ps1`](../../tools/make-icon.ps1) | genere `Ocre.ico` |
| [`tools/make-villes.ps1`](../../tools/make-villes.ps1) | regenere la table des villes depuis GeoNames |
| [`tools/test.ps1`](../../tools/test.ps1) | lance les tests et compte les echecs |
| [`tools/test-cli.ahk`](../../tools/test-cli.ahk) | Kelvin, unite, respiration, raccourcis, export, ligne de commande |
| [`tools/test-ui.ahk`](../../tools/test-ui.ahk) | chaque fenetre, ouverte, cliquee, photographiee |
| [`tools/test-fuites.ahk`](../../tools/test-fuites.ahk) | ce qui se dessine mille fois ne laisse-t-il rien ? |
| [`tools/test-perf.ahk`](../../tools/test-perf.ahk) | le demarrage est-il rapide, le repos silencieux ? |
| [`tools/release.ps1`](../../tools/release.ps1) | construit, teste, verifie les ressources, range le tout dans `dist\Ocre-<version>.zip` et construit l'installateur |
| [`tools/installer.ps1`](../../tools/installer.ps1) | construit `dist\Ocre-<version>-setup.exe` avec Inno Setup (recupere par winget au besoin) |
| [`.github/workflows/release.yml`](../../.github/workflows/release.yml) | sur un tag : construit, fait signer (SignPath), publie la release ; [`.signpath/`](../../.signpath/) en decrit les artefacts |
| [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) | a chaque changement : les tests, la construction, le parcours installation / mise a jour / retour arriere de l'installateur, les liens de la doc |
| [`tools/outils-ci.ps1`](../../tools/outils-ci.ps1), [`tools/archive.ps1`](../../tools/archive.ps1) | la chaine de construction epinglee (versions et empreintes) ; l'archive `.zip`, partagee avec `release.ps1` |
| [`tools/test-installateur.ps1`](../../tools/test-installateur.ps1) | joue l'installateur d'essai -- installation, mise a jour, retour arriere -- sans elevation, sur des cles factices |
| [`tools/liens.ps1`](../../tools/liens.ps1) | les liens des fichiers Markdown menent-ils quelque part ? |
| [`tools/captures.ps1`](../../tools/captures.ps1) | regenere les captures de `docs/img`, dans les deux langues |
| [`docs/`](../../docs/) | cette documentation (`en`, `fr`) et ses captures (`img`) |
| [`installer/`](../../installer/) | le script Inno Setup de l'installateur, et `utilisateur.ps1`, ce qu'il pose dans le compte de l'utilisateur (tache de demarrage, `Win+Ctrl+C`) |
| [`tools/sign.ps1`](../../tools/sign.ps1) | signe `Ocre.exe` et l'installateur, quand on a un certificat |
| [`tools/test-soleil.ahk`](../../tools/test-soleil.ahk) | verifie le calcul solaire contre une autre implementation |
| [`tools/sonde-ecrans.ahk`](../../tools/sonde-ecrans.ahk) | ce qu'Ocre voit de vos ecrans, sans rien modifier |
| [`tools/test-clamp.ahk`](../../tools/test-clamp.ahk) | verifie que la rampe n'est pas rognee |
| [`tools/test-courbe.ahk`](../../tools/test-courbe.ahk) | verifie la courbe et le planificateur, sans materiel |
| [`tools/sonde-touches.ahk`](../../tools/sonde-touches.ahk) | quelles touches parviennent reellement a Windows |
| [`tools/sonde-luminosite.ahk`](../../tools/sonde-luminosite.ahk) | la touche de luminosite est-elle visible du logiciel |
| [`recherche/`](../../recherche/) | le Night Light natif : codec, CLI, sauvegardes du registre |
