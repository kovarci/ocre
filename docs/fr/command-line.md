# La ligne de commande

[← Ocre](../../README.fr.md#documentation) · [English](../en/command-line.md)

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
Ocre.exe /version       la version
Ocre.exe /diag          de quoi signaler un bogue : versions, ecrans, etat
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

## Pourquoi on ne peut pas se brancher sur la touche de luminosite

L'idee vient naturellement : puisque F5 baisse la luminosite, pourquoi ne pas
associer le filtre a `Ctrl` + cette touche ? Parce qu'en mode multimedia le
clavier n'emet aucun code de touche : il declenche une commande qui part
directement au pilote d'affichage, sans traverser la file du clavier.

Mesure faite avec [`tools/sonde-luminosite.ahk`](../../tools/sonde-luminosite.ahk),
qui ecoute le crochet clavier, `WM_APPCOMMAND` et les raccourcis systeme :
**vingt appuis sur F5 seul, zero evenement**. Il n'y a rien a intercepter, avec
ou sans modificateur.

## Verifier que les touches de fonction vous parviennent

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

## Mode portable

Un `ocre.ini` pose **a cote de `Ocre.exe`** prend le pas sur celui de
`%APPDATA%`, et les journaux le rejoignent : l'application s'emporte alors
sur une cle USB ou dans un dossier synchronise avec ses reglages. Le fichier
doit exister -- meme vide -- pour que le mode s'active ; c'est un choix qu'on
fait en le creant, pas un comportement qui se declenche tout seul. `Ocre.exe
/get` dit quel fichier est en service.
