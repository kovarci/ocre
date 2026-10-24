# Réglages

[← Ocre](../../README.fr.md#documentation) · [English](../en/settings.md)

<p><img src="../img/fr/reglages.png" height="420" alt="La fenêtre des réglages"> <img src="../img/fr/raccourcis.png" height="260" alt="La fenêtre des raccourcis"> <img src="../img/fr/prereglages.png" height="170" alt="La fenêtre des préréglages"> <img src="../img/fr/habitudes.png" height="300" alt="La fenêtre des habitudes"></p>

Clic gauche sur l'icône. On y trouve l'intensité et la luminosité avec aperçu
en direct, le pas par appui, le démarrage automatique, le rétroéclairage
matériel, le gris couplé au filtre, le choix de la langue, et des boutons
*Configurer…* vers les fenêtres des raccourcis, des préréglages, des
habitudes et du planificateur.

**Pas de bouton Enregistrer, pas de bouton Fermer** — ni ici ni dans les
fenêtres secondaires. Comme dans les réglages de Windows, chaque commande
s'applique à l'instant où on la touche : une bascule, un compteur, un
raccourci capturé, une ville choisie, c'est fait, et `ocre.ini` est écrit
deux cents millisecondes plus tard. La fenêtre se ferme par sa croix ou par
Échap. On y perd le « fermer sans garder » ; on y gagne de ne jamais perdre
un réglage, et deux boutons par fenêtre. Ce qui touche au fichier entier —
*Réinitialiser…*, *Exporter…*, *Importer…*, *Oublier…* — garde un
bouton : ce sont des gestes qu'on veut explicites. Au premier lancement, la langue est celle de Windows :
français si l'interface est en français, anglais pour tout le reste ; le
drapeau fait le choix suivant. En anglais, les heures se lisent « 9:00 PM »
partout où elles s'affichent — l'infobulle, le planificateur, le lieu —,
et `ocre.ini` accepte aussi cette écriture (`h_debut=9:00 PM`) ; ce qu'Ocre
y écrit reste en 24 h. La section des écrans n'apparaît que sur une machine qui en a
plusieurs. En bas à gauche, *Réinitialiser…* remet `ocre.ini` à ses
valeurs d'origine, après confirmation ; le démarrage automatique, qui est un
état de Windows, n'est pas touché. À côté, *Exporter…* et *Importer…*
copient `ocre.ini` dans les deux sens, par les boîtes de dialogue de Windows :
tout tient dans ce fichier — raccourcis, lieu, préréglages, langue — et une
copie l'emporte sur une autre machine. Un fichier importé fait foi, même sur
ce qui n'était pas encore écrit ; un fichier sans section `[ocre]` est
refusé.

Au premier lancement, deux pastilles disent le geste de base et où sont les
réglages — Ocre démarre à 0 % et rien ne se passerait sinon. Une fois, et
plus jamais. Le numéro de version ne s'affiche qu'à deux endroits, là où l'on
va le chercher : l'infobulle de l'icône, et la fenêtre **À propos** (voir plus bas).

## À propos

Le bouton *À propos…*, en bas à droite des réglages, ouvre une petite fenêtre : la
version, les liens du projet et de ses versions, les licences de ce qui est
embarqué dans l'exécutable, et **Copier le diagnostic**. Ce bouton met dans le
presse-papiers ce qu'écrit `Ocre.exe /diag` — les versions d'Ocre et de Windows,
les écrans, si le garde-fou gamma est levé, si un autre outil de couleur tourne,
l'état des réglages qui comptent. Ni nom d'utilisateur ni donnée personnelle :
c'est ce que demande un [signalement de bogue](https://github.com/kovarci/ocre/issues/new/choose).
*Dossier des réglages* ouvre `%APPDATA%\Ocre`, où vivent `ocre.ini` et
`erreurs.log`. Ocre lui-même n'ouvre aucune connexion : les deux liens ouvrent
votre navigateur, à votre clic.

## Les raccourcis

Ils ont leur fenêtre : six champs pour le filtre, un pour le gris seul, et
les deux **molettes**, dont on choisit les modificateurs parmi huit
combinaisons — une capture de modificateurs seuls ne se fait pas proprement.
Deux cents points de hauteur que la fenêtre principale n'avait plus : avec le
bandeau d'alerte et deux écrans, elle débordait sous la barre des tâches à
150 %.

Un raccourci que Windows refuse — certaines combinaisons sont prises par le
pilote graphique ou réservées — est nommé sous les champs, *Refusé par
Windows : Ctrl + F7*, et noté dans `erreurs.log` ; la fenêtre principale en
donne le nombre sans qu'on ait à ouvrir. Un raccourci qu'on croit en place et
qui ne répond pas passerait pour un programme cassé.

Le bouton **Tester** répond à l'autre question, celle que Windows ne peut pas
poser : les touches arrivent-elles seulement ? Cinq secondes d'écoute par
crochet clavier, les raccourcis du programme suspendus le temps de l'essai,
et la ligne dit lesquels ont été reçus et lesquels ne sont jamais arrivés —
c'est le cas de `F5` à `F7` sur un portable dont le Fn-lock est en mode
multimédia, et jusqu'ici seul `tools/sonde-touches.ahk` savait le dire.

## Quand un filtre de Windows se cumule

Un **bandeau rouge** sous l'en-tête prévient si l'éclairage nocturne de
Windows est programmé ou si son filtre de couleur est actif : le premier
réchaufferait l'écran une seconde fois le soir venu, le second le laisserait
gris dès qu'Ocre se coupe. Les deux sont lus dans le registre
([`lib/Concurrents.ahk`](../../lib/Concurrents.ahk)), sans rien modifier. Il
prévient aussi si **f.lux, Iris, LightBulb ou Twinkle Tray** tournent : deux
programmes qui écrivent la même rampe se battent, et c'est le conflit le plus
probable chez quelqu'un qui essaie Ocre en gardant l'ancien.

Pourquoi « programmé » et non « actif » : sur 25H2, la clé d'état du Night
Light n'est plus réécrite (voir le tableau plus haut) ; seule celle des
réglages, et son drapeau d'horaire, est tenue à jour par les Paramètres. Un
Night Light allumé à la main sans horaire passe donc sous le radar — c'est
le prix de ne pas crier faux.

Le planificateur a **sa propre fenêtre**, ouverte par *Configurer…*. Ce n'est
pas un caprice de rangement : avec le mode solaire, le lieu et les deux
décalages, la fenêtre principale atteignait 1244 pixels sur un écran de 1200 à
150 % de mise à l'échelle, et ne tenait plus. C'était le bon candidat au
départ — un horaire se règle une fois et ne se retouche plus, alors que
l'intensité et les raccourcis se reprennent. La bascule *Suivre un horaire*,
elle, reste dans la fenêtre principale, où elle se voit d'un coup d'œil.

Pour un simple changement d'intensité, le clic droit suffit : le panneau porte
les deux curseurs et **trois préréglages** — Lecture, Film, Nuit. Une rangée
de trois boutons plutôt que trois rangées pleines : le panneau doit tenir
au-dessus de la zone de notification. Leurs valeurs se règlent dans une
fenêtre à part, *Préréglages du panneau > Configurer…*, sur le modèle du
planificateur : trois rangées de compteurs n'auraient pas tenu dans la
fenêtre principale, qui n'a plus de hauteur à donner. Chaque clic sur un
compteur pose le couple de sa rangée sur l'écran, sans pastille : 3 400 K ne
se choisit pas à l'aveugle. Et ce qu'on voit en fermant reste, comme pour
tout le reste des réglages — pas de Valider, pas de retour en arrière : le
dernier couple essayé est celui qu'on garde, et il compte comme un réglage à
la main (l'horaire se suspend, les habitudes le notent).

Le panneau porte aussi la ligne *Pastille à l'écran*, cochée par défaut : la
décocher fait taire la vignette qui accompagne chaque geste — raccourci,
molette, préréglage. Elle n'est que là, et dans `ocre.ini` (`pastille=0`) :
comme l'unité, c'est un goût qu'on choisit une fois. Les deux pastilles
d'accueil du premier lancement passent quand même : elles ne répondent pas à
un geste, elles disent où est la porte.

## L'écran qu'on ne regarde plus

*Assombrir l'écran inactif après N minutes* : sans clavier ni souris pendant
ce temps, la luminosité descend au plancher — en trois secondes de fondu,
plus lentement encore que la bascule de `Ctrl+F7`, pour que l'écran ne
« tombe » jamais sous les yeux de qui vient de lever la tête — et remonte de
la même façon au premier geste, à la valeur d'avant. Un film en plein écran
ne bouge ni clavier ni souris pendant deux heures : quand la fenêtre active
couvre tout son écran, on ne s'assombrit pas. Coupé par défaut, comme tout ce
qui bouge tout seul ([`lib/Inactif.ahk`](../../lib/Inactif.ahk)).

## Sur batterie

*Sur batterie, baisser la luminosité de N %* : au débranchement du chargeur,
la luminosité d'Ocre — rétroéclairage puis rampe, comme le curseur —
descend de N points en trois secondes, et remonte au rebranchement. Un
réglage fait à la main entre-temps est adopté : on ne remonte que ce qu'on a
baissé soi-même. Windows a son propre réglage pour le rétroéclairage dans
les options d'alimentation ; celui-ci porte sur la luminosité d'Ocre, et se
combine avec le reste. Le changement d'alimentation arrive par
`WM_POWERBROADCAST`, déjà écouté pour la veille ; une session ouverte sur
batterie part déjà baissée. La rangée n'existe que sur une machine qui a une
batterie, et le réglage est coupé par défaut
([`lib/Batterie.ahk`](../../lib/Batterie.ahk)).

## Suivre le contenu de l'écran

*Suivre le contenu de l'écran, de 30 à 100 %* : c'est l'idée de Gammy. Une
page blanche à 100 % de rétroéclairage éblouit, un film sombre à 40 % ne se
voit plus ; plutôt que de régler la luminosité à chaque changement de
fenêtre, Ocre regarde ce que l'écran affiche et descend la luminosité quand
le contenu est clair, la remonte quand il est sombre, entre les deux bornes.
Contenu noir : la borne haute ; page blanche : la borne basse ; gris moyen :
le milieu.

La mesure vient de la **duplication de bureau DXGI**
([`lib/Capture.ahk`](../../lib/Capture.ahk)), celle de Gammy et des logiciels de
capture : la carte graphique donne une texture du bureau, on la copie dans
une texture à nous munie d'une chaîne de mipmaps, la carte génère la chaîne
— chaque niveau est la moyenne du précédent — et l'on ne relit que le
niveau de trente points de large, dont on moyenne la luminance (Rec. 601).
C'est une vraie moyenne de tout l'écran, pas un échantillon, pour deux
millisecondes de processeur quand l'image a changé, et rien du tout quand
elle n'a pas changé : `AcquireNextFrame` le dit sans rien rendre. Sept
mesures par seconde. Si la duplication manque — session distante, machine
sans Direct3D —, une copie GDI prend le relais, plus chère, une fois sur
trois. La rampe et le rétroéclairage ne sont dans aucune des deux : on
mesure le contenu, pas ce qu'on en fait, et rien ne boucle.

Entre la mesure et l'écran, deux amortisseurs : une moyenne glissante courte
(six dixièmes de la mesure neuve — une page qui change est suivie en trois
mesures, une demi-seconde) et un pas minimal de deux points. Le mouvement
est un fondu de six dixièmes de seconde, relancé depuis la valeur du moment
à chaque nouvelle cible : quand le contenu bouge encore, la luminosité le
suit sans jamais sauter. Une page blanche qui s'ouvre est suivie en deux
dixièmes de seconde et rejointe en moins d'une. Un écran tout noir — un jeu
en plein écran exclusif, que la duplication ne voit pas — ne dit rien, et
l'on garde la valeur d'avant. Trois clés d'`ocre.ini` sans commande dans
les réglages, pour qui veut régler la nervosité : `adapt_periode` (ms entre
deux mesures, 150), `adapt_fondu` (ms du mouvement, 600), `adapt_lissage`
(part de la mesure neuve, 0,6).

La duplication DXGI par les tables de fonctions COM, à la main, a tendu
quatre pièges, tous commentés dans le module : `DllCall` décharge
`d3d11.dll` après l'appel si on ne la tient pas, et les objets Direct3D
pointent alors dans le vide ; la toute première image d'une duplication
n'en est pas une — une surface restreinte, en demi-flottants, sans
contenu, dont il ne faut surtout pas faire le modèle de sa texture de
lecture ; `CopyResource` veut le même nombre de niveaux des deux côtés ; un
`HRESULT` revient signé sur 32 bits et se compare non signé.

Quand ce suivi est actif, c'est lui qui tient le curseur de luminosité : les
bornes sont le réglage. Il se tait tant qu'une fenêtre à curseur est ouverte
— on ne dispute pas le curseur à la main qui le tient —, quand l'écran est
assombri pour inactivité, et retire ce que la batterie a retiré. Écrans
séparés, chaque écran suit son propre contenu ; ensemble, c'est l'écran
qu'on regarde qui décide pour tous. Coupé par défaut
([`lib/Adaptatif.ahk`](../../lib/Adaptatif.ahk)).

## Apprendre les habitudes

*Habitudes > Configurer… > Apprendre mes habitudes* : quelqu'un qui
remonte la luminosité tous les soirs après le coucher du soleil, ou qui
baisse le filtre dès qu'un film passe en plein écran, le fait à la main des
dizaines de fois avant de penser à un horaire. Ocre regarde ces gestes,
retient dans quelles circonstances ils mènent à quelle valeur, et quand une
circonstance a été confirmée assez de fois, pose la valeur lui-même, en
fondu, avec une pastille qui dit « Habitude · 5 fois » — puis continue
d'apprendre. C'est un petit modèle ([`lib/Habitudes.ahk`](../../lib/Habitudes.ahk)),
et chaque pièce a une raison :

- **La décantation.** Un geste n'est pas une observation. Montrer l'outil à
  un ami et faire monter et descendre le filtre comme un fou pendant cinq
  minutes, c'est cinquante gestes et zéro choix. Seule compte la valeur où
  la main *s'arrête* : deux minutes sans nouveau geste, et c'est celle-là,
  une seule fois.
- **La médiane, pas la moyenne.** Le soir de la démonstration, le filtre est
  resté à 100 % : une moyenne en serait tirée de vingt points pendant des
  semaines ; une médiane ne bouge pas tant qu'une minorité dit autre chose.
- **Le temps solaire.** Une habitude du soir est « une heure après le
  coucher », pas « 21 h » : en décembre le soleil se couche à 17 h et
  l'habitude horaire arriverait quatre heures trop tard, et le changement
  d'heure décalerait tout d'un coup. Autour du coucher et du lever, les
  gestes se comparent en minutes par rapport au soleil (le lieu des
  réglages, ou celui du fuseau horaire) ; au milieu du jour et de la nuit, à
  l'horloge.
- **Le noyau.** Pas de grille : deux gestes se ressemblent d'autant plus
  qu'ils sont proches, une gaussienne de vingt-cinq minutes d'écart-type.
  21 h 29 et 21 h 31 sont le même geste ; 21 h et 22 h n'ont presque rien à
  se dire.
- **L'oubli, à deux vitesses.** Une observation perd la moitié de son poids
  tous les trente jours et disparaît à soixante : l'hiver ne dicte pas
  l'été. Mais une mémoire lente est lente à admettre un changement : les
  quatre observations les plus récentes forment une mémoire courte, et si
  elles sont d'accord entre elles et en désaccord avec la longue, c'est
  qu'une habitude a changé — la courte l'emporte, en trois soirs, sans que
  la longue perde sa robustesse contre les aberrants.
- **La confiance, et la proposition.** On n'agit que si le poids des
  observations atteint 2,5 — trois gestes récents au bon moment — ET si
  elles sont d'accord : six dixièmes du poids à dix points ou moins de la
  médiane. Tantôt 30, tantôt 80, ce n'est pas une habitude, c'est une
  hésitation, et l'on se tait. En dessous de la confiance mais des deux
  soirs concordants, Ocre *propose* : une pastille « 80 comme hier ? »
  qu'un clic accepte, et qui compte alors pour un geste ; l'ignorer ne
  coûte rien.
- **La correction, et l'approbation.** Un geste dans les dix minutes qui
  suivent une pose automatique est un désaveu : l'observation pèse double.
  Trente minutes sans geste, *avec quelqu'un devant l'écran* — une pose
  que personne n'a vue ne dit rien —, c'est une approbation : la valeur
  posée devient une observation implicite à demi-poids. Sans cela, le
  modèle tuait les habitudes qu'il réussissait à automatiser : plus de
  geste, plus d'observation, et l'oubli faisait le reste.
- **Les résidus.** Quand un automate tient la voie — le planificateur pour
  l'intensité, le suivi du contenu pour la luminosité —, on n'apprend pas
  la valeur mais l'*écart* à ce que l'automate donnait : « à cette heure,
  toujours quinze de plus que le soleil ». L'écart appris devient un
  décalage que l'automate applique lui-même : il reste maître, l'habitude
  le corrige. L'assombrissement d'inactivité et la baisse sur batterie,
  eux, sont des états passagers : on n'y apprend rien et l'on n'y pose rien.
- **La retenue.** Rien dans le quart d'heure qui suit un geste, rien tant
  qu'un geste décante, rien tant que la cible n'a pas bougé depuis le
  dernier geste — une correction suspend l'habitude, comme un réglage à la
  main suspend le planificateur, et pas au-delà du jour.
- **Le contexte.** Chaque observation retient l'application au premier plan
  (le nom de son processus, dans `habitudes.ini`, en local) et si elle est
  en plein écran : « quand le lecteur vidéo est en plein écran, luminosité
  40 » vaut à toute heure. Un contexte qui a ses propres observations,
  assez nombreuses et d'accord, l'emporte sur l'heure tant qu'il est
  devant, et la pastille le nomme. Le week-end aussi est un contexte : quand
  un moment a assez d'observations du même genre de jour, il n'écoute
  qu'elles.
- **La rampe.** Entre deux moments sûrs à des valeurs différentes — 80 à
  21 h, 60 à 23 h —, la valeur glisse de l'un à l'autre au lieu de tomber
  par marches, comme le fait le planificateur solaire ; les pas d'une rampe
  passent sans pastille.

La fenêtre montre les deux courbes de la journée, un bâton par demi-heure :
la valeur attendue en hauteur, l'ocre quand le modèle est sûr de lui, le
gris quand il a des observations mais pas assez, un trait à l'heure qu'il
est, et le compte des observations et des créneaux sûrs ; un clic sur un
bâton liste les observations de la demi-heure — date, valeur, application,
écart, correction ou approbation — et *Oublier…* efface tout. Les
observations vivent dans `habitudes.ini` à côté d'`ocre.ini`, une ligne
par observation, lisibles et effaçables à la main ; chaque observation,
pose, proposition, approbation et écart est noté dans `habitudes.log`, pour
comprendre après coup. L'horloge, le soleil, la présence et l'application au
premier plan du modèle sont injectables : les tests lui font vivre deux mois
— démonstration, correction, hésitation, approbation sans témoin,
changement d'heure du lever, film en plein écran, planificateur à corriger
— en quelques millisecondes. Coupé par défaut.

## La règle des 20-20-20

Toutes les vingt minutes, regarder à six mètres pendant vingt secondes :
c'est la seule chose qu'un filtre ne fait pas pour les yeux. Une bascule
dans la fenêtre du planificateur — c'est une affaire d'heure, et la fenêtre
principale est pleine — l'active, coupée par défaut comme tout ce qui
interrompt.

Le rappel n'affiche rien : **l'icône de la zone de notification respire**,
la tache rétrécit et regrossit doucement, un cycle toutes les trois
secondes, pendant vingt secondes. Qui sait ce que c'est le voit ; qui ne le
sait pas ne voit rien. Une pastille au milieu de l'écran se voyait de tout
le monde — y compris de la personne à qui l'on montre justement quelque
chose. Et pour la même raison, **filtre coupé, pas de rappel** : `Ctrl+F7`
est le geste qu'on fait pour montrer son écran, ce n'est pas le moment. Si
le clavier et la souris dorment depuis plus de cinq minutes, il se tait
aussi : les yeux se reposent déjà. La période se change dans `ocre.ini`
(`rappel_minutes`).

## Adoucir les changements

Le planificateur a son fondu de trois heures, dont tout l'intérêt est de ne pas
se voir. Un appui sur un raccourci, lui, sautait d'un cran à l'autre : cinq
points d'intensité d'un coup, c'est un clignement. Le même argument vaut aux
deux échelles, et il ne coûte ici qu'un sixième de seconde.

La bascule (Ctrl+F7) et les préréglages ne font pas un pas de cinq points :
ils vont de zéro à cent d'un coup, et le même sixième de seconde en fait un
flash. Ils ont donc leur propre durée, une seconde par défaut, réglable par la clé
`fondu_bascule` de `ocre.ini` (en millisecondes). Qui préfère le coup sec
d'origine y remet `160`. Le gris, quand il est couplé au filtre, suit le même
fondu : il s'installe et se retire avec la teinte au lieu de tomber d'un coup.

Ce qui **ne** passe **pas** par ce fondu, et à dessein : la molette et les
curseurs, qui sont déjà continus — le geste EST le fondu, et y ajouter une
interpolation ferait traîner l'image derrière la main ; et la pose au
démarrage, une session qui s'ouvre en s'éclaircissant pendant une seconde ayant
l'air d'un défaut.
