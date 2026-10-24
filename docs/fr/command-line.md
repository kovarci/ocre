# La ligne de commande

[← Ocre](../../README.fr.md#documentation) · [English](../en/command-line.md)

Pour ce qui n'est pas un clavier : un boîtier à boutons, une macro, un script
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
l'une pour l'autre n'apprend rien à personne. Les mots anglais sont acceptés
aussi : `warmer`, `cooler`, `brightness`, `schedule`, `darkroom`.

`/get` écrit une ligne `cle=valeur` par ligne — intensite, kelvin,
luminosite, coupe, horaire, gris, noir, unite, portable, fichier, separes, et une
ligne par écran quand ils sont séparés — ce qu'un script lit sans effort,
et rend l'intensité en code de retour pour qui ne veut que cela. Ocre.exe
est une application à fenêtre, pas une application console : `cmd` et
PowerShell ne l'attendent pas, la sortie arrive après l'invite et le code de
retour n'est pas dans `%ERRORLEVEL%` ni `$LASTEXITCODE`. Pour les lire,
attendez-le : `start /wait Ocre.exe /get` dans `cmd`, et en PowerShell
`$p = Start-Process .\Ocre.exe /get -Wait -PassThru -NoNewWindow; $p.ExitCode`.

`/export` et `/import` sont les boutons de la fenêtre des réglages, pris en
ligne de commande — pour déployer les mêmes réglages sur plusieurs
machines. Un chemin ne passe pas dans un message : les deux travaillent sur
le fichier eux-mêmes, et `/import` prévient ensuite l'instance en place que
tout a changé, langue comprise. Un chemin relatif l'est au dossier d'où l'on
lance la commande. Un fichier sans section `[ocre]` est refusé, code 2.

Une commande qui attend un nombre et n'en reçoit pas — `/set` tout court,
`/set abc` — **ne fait rien et le dit**, code de retour 2. Elle valait zéro
auparavant, et zéro coupe le filtre : une macro mal écrite éteignait l'écran
en silence.

Une commande adressée à une instance vivante lui est **postée**, pas appliquée
sur place : deux processus qui poseraient chacun leur rampe se battraient. La
diffusion évite d'avoir à retrouver la fenêtre, qui est cachée. C'est aussi
pourquoi `#SingleInstance Force` a disparu — il aurait tué l'application pour
la relancer à chaque commande, ce qui donne le bon résultat par le plus mauvais
chemin. La question « suis-je le premier ? » est posée à un mutex nommé.

Sans instance en cours, `/set` et ses voisins démarrent l'application puis
s'appliquent ; `/reset` remet simplement l'écran à plat, ce qui est justement
le cas où l'on s'en sert.

## Pourquoi on ne peut pas se brancher sur la touche de luminosité

L'idée vient naturellement : puisque F5 baisse la luminosité, pourquoi ne pas
associer le filtre à `Ctrl` + cette touche ? Parce qu'en mode multimédia le
clavier n'émet aucun code de touche : il déclenche une commande qui part
directement au pilote d'affichage, sans traverser la file du clavier.

Mesure faite avec [`tools/sonde-luminosite.ahk`](../../tools/sonde-luminosite.ahk),
qui écoute le crochet clavier, `WM_APPCOMMAND` et les raccourcis système :
**vingt appuis sur F5 seul, zéro événement**. Il n'y a rien à intercepter, avec
ou sans modificateur.

## Vérifier que les touches de fonction vous parviennent

Appuyez sur **`F5` seul** dans un navigateur. Si la page se rafraîchit, les
touches de fonction atteignent Windows et le jeu principal fonctionne. Si la
luminosité change à la place, le Fn-lock est en mode multimédia : le firmware
avale la touche avant Windows, et seul le jeu de secours répond. Beaucoup de
portables remettent ce mode au redémarrage.

Les réglages vivent dans `%APPDATA%\Ocre\ocre.ini`, à côté de deux journaux.
`demarrage.log` note à quelle seconde après l'allumage Ocre a pris la main, ce
qui distingue une application lente d'une application lancée tard par Windows.
`erreurs.log` reçoit toute erreur avant qu'elle ne s'affiche : Ocre démarre avec
la session, et une boîte ouverte à ce moment-là se retrouve derrière les autres
fenêtres ou se ferme d'un réflexe. Les deux sont tronqués au-delà de quarante
lignes.

## Mode portable

Un `ocre.ini` posé **à côté de `Ocre.exe`** prend le pas sur celui de
`%APPDATA%`, et les journaux le rejoignent : l'application s'emporte alors
sur une clé USB ou dans un dossier synchronisé avec ses réglages. Le fichier
doit exister — même vide — pour que le mode s'active ; c'est un choix qu'on
fait en le créant, pas un comportement qui se déclenche tout seul. `Ocre.exe
/get` dit quel fichier est en service.
