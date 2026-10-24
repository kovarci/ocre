;==============================================================================
;  Batterie.ahk -- baisser la luminosite quand le chargeur est debranche.
;
;  Le retroeclairage est ce qui coute le plus a un portable, et Windows a
;  deja son propre reglage pour ca dans les options d'alimentation. Celui-ci
;  fait autre chose : il baisse la luminosite d'Ocre -- retroeclairage puis
;  rampe, comme le curseur -- d'un nombre de points choisi, en fondu, et la
;  remonte au rebranchement. Un reglage a la main entre-temps est adopte :
;  on ne remonte que ce qu'on a baisse soi-meme.
;
;  Le changement d'alimentation s'annonce par WM_POWERBROADCAST, que le
;  programme ecoute deja pour la veille ; l'etat courant se lit dans
;  GetSystemPowerStatus. Une machine sans batterie ne voit ni la rangee des
;  reglages ni rien de tout ceci.
;
;  Coupe par defaut, comme tout ce qui bouge tout seul.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Config.ahk

class Batterie {

    static FONDU := 3000           ; le fondu, descente comme remontee, en ms
    static PBT_APMPOWERSTATUSCHANGE := 0x0A

    static actif := false
    static pourcent := 20
    static applique := false       ; la baisse est en place
    static baisser := 0            ; (pourcent, duree) => ... releve et descend
    static remonter := 0           ; (duree) => ... rend ce qui a ete releve

    static Init(baisser, remonter) {
        Batterie.baisser := baisser
        Batterie.remonter := remonter
        Batterie.Relire()
    }

    ;  Relit le reglage et se met dans l'etat qui va avec l'alimentation du
    ;  moment : une session ouverte sur batterie part deja baissee.
    static Relire() {
        Batterie.actif := (Config.Lire("batterie") = "1") && Batterie.Presente()
        Batterie.pourcent := Max(1, Min(100, Config.LireNombre("batterie_pourcent")))
        if (!Batterie.actif) {
            Batterie.Rendre(Batterie.FONDU)
            return
        }
        Batterie._Verifier()
    }

    ;  A brancher sur WM_POWERBROADCAST : seul le changement d'etat nous
    ;  regarde, pas la veille.
    static Message(wParam) {
        if (wParam = Batterie.PBT_APMPOWERSTATUSCHANGE && Batterie.actif)
            Batterie._Verifier()
    }

    static _Verifier() {
        sur := Batterie.SurBatterie()
        if (sur && !Batterie.applique) {
            Batterie.applique := true
            if (Batterie.baisser)
                try (Batterie.baisser)(Batterie.pourcent, Batterie.FONDU)
        } else if (!sur && Batterie.applique) {
            Batterie.Rendre(Batterie.FONDU)
        }
    }

    ;  Remonte ce qui a ete baisse, en fondu ou d'un coup (a la sortie).
    static Rendre(duree) {
        if (!Batterie.applique)
            return
        Batterie.applique := false
        if (Batterie.remonter)
            try (Batterie.remonter)(duree)
    }

    ;  SYSTEM_POWER_STATUS : ACLineStatus en premier octet -- 0 sur batterie,
    ;  1 sur secteur, 255 inconnu -- puis BatteryFlag, dont le bit 128 dit
    ;  qu'il n'y a pas de batterie du tout.
    static _Etat() {
        s := Buffer(12, 0)
        if (!DllCall("GetSystemPowerStatus", "ptr", s))
            return { secteur: 255, drapeau: 255 }
        return { secteur: NumGet(s, 0, "UChar"), drapeau: NumGet(s, 1, "UChar") }
    }

    static Presente() {
        e := Batterie._Etat()
        return e.drapeau != 255 && !(e.drapeau & 128)
    }

    static SurBatterie() {
        return Batterie._Etat().secteur = 0
    }
}
