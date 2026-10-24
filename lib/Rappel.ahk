;==============================================================================
;  Rappel.ahk -- la regle des 20-20-20.
;
;  Toutes les vingt minutes, regarder a six metres pendant vingt secondes :
;  c'est la seule chose qu'un filtre de lumiere ne fait pas pour les yeux, et
;  Iris la rappelle. Ocre le fait sans rien afficher : l'icone de la zone de
;  notification RESPIRE -- la tache grossit et retrecit doucement, un cycle
;  toutes les trois secondes, pendant vingt secondes. Qui sait ce que c'est
;  le voit ; qui ne le sait pas ne voit rien. Une pastille au milieu de
;  l'ecran, elle, se voyait de tout le monde, y compris de la personne a qui
;  l'on montre justement quelque chose.
;
;  Et pour la meme raison, filtre coupe, pas de rappel : couper le filtre
;  (Ctrl+F7) est le geste qu'on fait pour montrer son ecran a quelqu'un, et
;  ce n'est pas le moment. Personne devant l'ecran non plus : si le clavier
;  et la souris dorment depuis plus de cinq minutes, les yeux se reposent
;  deja.
;
;  Coupe par defaut, comme le planificateur : un programme qui interrompt
;  sans qu'on le lui ait demande se fait desinstaller.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Config.ahk

class Rappel {

    static CYCLE := 3000           ; une inspiration et une expiration
    static CYCLES := 7             ; sept respirations : vingt et une secondes
    static PAS := 60               ; entre deux images
    static MINI := 0.65            ; la tache descend a 65 % de sa taille...
    static MAXI := 1.12            ; ...et monte jusqu'a toucher les bords
    static REPOS := 5 * 60000      ; inactivite au-dela de laquelle on se tait

    static actif := false
    static tic := 0                ; la periode
    static tac := 0                ; l'image, pendant la respiration
    static debut := 0
    static respirer := 0           ; (echelle) => ..., -1 pour rendre l'icone
    static permis := 0             ; () => le rappel a-t-il lieu d'etre ?

    static Init(respirer, permis := 0) {
        Rappel.respirer := respirer
        Rappel.permis := permis
        Rappel.signature := ""
        Rappel.Relire()
    }

    ;  Relit la configuration et (re)arme la periode. Appelee au demarrage et
    ;  a chaque enregistrement des reglages. La periode est dans ocre.ini,
    ;  cle "rappel_minutes" : vingt par defaut, c'est le nom de la regle.
    ;  Le compte a rebours ne repart que si le reglage a change : n'importe
    ;  quelle bascule des reglages passe par ici, et elle remettait les
    ;  vingt minutes a zero.
    static signature := ""

    static Relire() {
        actif := (Config.Lire("rappel") = "1")
        minutes := Max(1, Config.LireNombre("rappel_minutes"))
        signature := actif . "|" . minutes
        if (signature = Rappel.signature && Rappel.tic)
            return
        Rappel.signature := signature
        Rappel.Arreter()
        Rappel.actif := actif
        if (!Rappel.actif)
            return
        Rappel.tic := () => Rappel._Sonner()
        SetTimer(Rappel.tic, minutes * 60000)
    }

    static Arreter() {
        if (Rappel.tic)
            SetTimer(Rappel.tic, 0)
        Rappel.tic := 0
        Rappel._Finir()
    }

    static EnCours() {
        return Rappel.tac ? true : false
    }

    ;  La periode echoit. Personne devant l'ecran, ou filtre coupe : rien, et
    ;  pas de rattrapage -- le prochain rappel est dans vingt minutes, comme
    ;  si de rien n'etait.
    static _Sonner() {
        if (A_TimeIdlePhysical > Rappel.REPOS)
            return
        if (Rappel.permis && !(Rappel.permis)())
            return
        Rappel.Lancer()
    }

    ;  Une respiration tout de suite, sans condition : c'est "Ocre.exe
    ;  /rappel", pour voir a quoi cela ressemble avant de l'activer.
    ;  (Pas "Respirer" : AutoHotkey ne distingue pas la casse, et la
    ;  propriete "respirer" existe deja -- "Property is read-only".)
    static Lancer() {
        Rappel._Finir()
        Rappel.debut := A_TickCount
        Rappel.tac := () => Rappel._Image()
        SetTimer(Rappel.tac, Rappel.PAS)
    }

    ;  Une sinusoide entre MINI et MAXI, qui part de la taille normale en
    ;  montant -- l'inspiration d'abord -- et y revient apres un nombre
    ;  entier de cycles : la premiere et la derniere image sont l'icone
    ;  normale, rien ne saute.
    static _Image() {
        t := A_TickCount - Rappel.debut
        if (t >= Rappel.CYCLES * Rappel.CYCLE) {
            Rappel._Finir()
            return
        }
        ;  Le filtre vient d'etre coupe (Ctrl+F7) : on montre son ecran, la
        ;  respiration s'arrete sur-le-champ. La periode, elle, court
        ;  toujours ; si elle echoit filtre coupe, _Sonner se tait.
        if (Rappel.permis && !(Rappel.permis)()) {
            Rappel._Finir()
            return
        }
        centre := (Rappel.MAXI + Rappel.MINI) / 2
        demi := (Rappel.MAXI - Rappel.MINI) / 2
        depart := ASin((1 - centre) / demi)          ; la phase ou l'echelle vaut 1
        phase := depart + 2 * 3.14159265358979 * t / Rappel.CYCLE
        echelle := centre + demi * Sin(phase)
        if (Rappel.respirer)
            try (Rappel.respirer)(echelle)
    }

    ;  Rend l'icone normale -- seulement si une respiration etait en cours :
    ;  Relire() passe ici a chaque enregistrement, et il n'y a alors rien a
    ;  rendre.
    static _Finir() {
        if (!Rappel.tac)
            return
        SetTimer(Rappel.tac, 0)
        Rappel.tac := 0
        if (Rappel.respirer)
            try (Rappel.respirer)(-1)
    }
}
