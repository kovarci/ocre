;==============================================================================
;  Inactif.ahk -- assombrir l'ecran qu'on ne regarde plus.
;
;  Dix minutes sans clavier ni souris, et la luminosite descend au plancher
;  -- lentement, plus lentement encore que la bascule de Ctrl+F7 : trois
;  secondes de fondu, pour que l'ecran ne "tombe" jamais sous les yeux de
;  qui vient de lever la tete. Au premier geste, elle remonte de la meme
;  facon, a la valeur d'avant. C'est ce que fait Twinkle Tray ; ici c'est
;  Fondu et Retro qui le font, rien de neuf.
;
;  Un film en plein ecran ne bouge ni clavier ni souris pendant deux heures :
;  quand la fenetre active couvre tout son ecran, on ne s'assombrit pas.
;
;  Coupe par defaut, comme tout ce qui bouge tout seul.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Config.ahk

class Inactif {

    static FONDU := 3000           ; le fondu, aller comme retour, en ms
    static PERIODE := 1000         ; on regarde l'inactivite chaque seconde

    static actif := false
    static minutes := 10
    static tic := 0
    static assombri := false
    static assombrir := 0          ; (duree) => ... releve et descend
    static eclaircir := 0          ; (duree) => ... remonte a ce qui etait releve
    static tenir := 0              ; () => ... remet l'assombrissement s'il a ete defait

    static Init(assombrir, eclaircir, tenir := 0) {
        Inactif.assombrir := assombrir
        Inactif.eclaircir := eclaircir
        Inactif.tenir := tenir
        Inactif.Relire()
    }

    static Relire() {
        Inactif.Rendre(0)
        if (Inactif.tic)
            SetTimer(Inactif.tic, 0)
        Inactif.tic := 0
        Inactif.actif := (Config.Lire("inactif") = "1")
        Inactif.minutes := Max(1, Config.LireNombre("inactif_minutes"))
        if (!Inactif.actif)
            return
        Inactif.tic := () => Inactif._Battre()
        SetTimer(Inactif.tic, Inactif.PERIODE)
    }

    static _Battre() {
        if (!Inactif.assombri) {
            if (A_TimeIdlePhysical < Inactif.minutes * 60000 || Inactif._PleinEcran())
                return
            Inactif.assombri := true
            if (Inactif.assombrir)
                try (Inactif.assombrir)(Inactif.FONDU)
        } else if (A_TimeIdlePhysical < Inactif.PERIODE) {
            Inactif.Rendre(Inactif.FONDU)
        } else if (Inactif.tenir) {
            ;  L'assombrissement n'est pas ecrit dans ocre.ini : une relecture
            ;  des reglages ou une reprise le defait. Tant qu'on est inactif,
            ;  on le remet.
            try (Inactif.tenir)()
        }
    }

    ;  Remonte a la valeur d'avant, en fondu ou d'un coup (a la sortie).
    static Rendre(duree) {
        if (!Inactif.assombri)
            return
        Inactif.assombri := false
        if (Inactif.eclaircir)
            try (Inactif.eclaircir)(duree)
    }

    ;  La fenetre active couvre-t-elle son ecran ? Un film, un jeu : on
    ;  regarde sans toucher a rien, ce n'est pas de l'inactivite.
    static _PleinEcran() {
        try {
            hwnd := WinGetID("A")
            WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
            hmon := DllCall("MonitorFromWindow", "ptr", hwnd, "uint", 2, "ptr")
            mi := Buffer(40, 0)
            NumPut("UInt", 40, mi, 0)
            DllCall("GetMonitorInfoW", "ptr", hmon, "ptr", mi)
            mw := NumGet(mi, 12, "Int") - NumGet(mi, 4, "Int")
            mh := NumGet(mi, 16, "Int") - NumGet(mi, 8, "Int")
            if (w < mw || h < mh)
                return false
            ;  Une fenetre agrandie deborde le moniteur de son cadre
            ;  invisible et le couvre aussi quand la barre des taches se
            ;  masque : ce n'est pas un plein ecran. Un vrai plein ecran n'a
            ;  ni barre de titre (WS_CAPTION 0x00C00000) ni cadre epais
            ;  (WS_THICKFRAME 0x40000).
            style := WinGetStyle("ahk_id " . hwnd)
            return (style & 0x00C00000) != 0x00C00000 && !(style & 0x40000)
        }
        return false
    }
}
