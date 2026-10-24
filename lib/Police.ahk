;==============================================================================
;  Police.ahk -- une police embarquee, chargee sans l'installer.
;
;  Windows ne livre rien qui ressemble aux polices d'interface d'aujourd'hui :
;  Segoe UI est correcte mais carree, et tout ce que la machine propose d'autre
;  est classique. La pastille, elle, montre un mot pendant une seconde, et ce
;  mot merite une police qui ne fasse pas "boite de dialogue".
;
;  Inter (SIL Open Font License, lib\Inter-LICENSE.txt) est celle de Notion et
;  de la plupart des interfaces recentes. Elle est EMBARQUEE dans Ocre.exe
;  comme ressource et chargee dans une collection privee de GDI+ : rien n'est
;  installe dans Windows, rien ne reste apres la fermeture, et l'exe reste
;  autonome. En script non compile, elle est lue depuis lib\.
;
;  Une seule graisse -- Medium -- pour ne pas embarquer 400 Ko par graisse.
;  Si la police manque (ressource absente, GDI+ qui refuse), Famille() renvoie
;  0 et Dessin.Texte retombe sur Segoe UI : la pastille reste lisible.
;==============================================================================

#Requires AutoHotkey v2.0

;  La directive Ahk2Exe-AddResource qui embarque le fichier est dans Ocre.ahk,
;  avec les autres : le compilateur resout les chemins depuis le script
;  principal.

class Police {

    static FICHIER := "Inter-Medium.ttf"
    static RESSOURCE := "INTER"

    static coll := 0
    static fam := ""            ; "" = pas encore cherchee, 0 = introuvable
                                ; (pas "famille" : AutoHotkey ne distingue pas
                                ; la casse, et Famille() est la methode)

    ;--------------------------------------------------------------------------
    ;  La famille GDI+ de la police embarquee, ou 0. Le handle appartient a la
    ;  collection : ne pas le detruire.
    ;--------------------------------------------------------------------------
    static Famille() {
        if (Police.fam != "")
            return Police.fam
        Police.fam := 0
        try {
            DllCall("gdiplus\GdipNewPrivateFontCollection", "ptr*", &coll := 0)
            if (!coll)
                return 0
            Police.coll := coll

            if (!Police._DepuisRessource(coll) && !Police._DepuisFichier(coll))
                return 0

            DllCall("gdiplus\GdipGetFontCollectionFamilyCount", "ptr", coll, "int*", &n := 0)
            if (n < 1)
                return 0
            fams := Buffer(A_PtrSize * n, 0)
            DllCall("gdiplus\GdipGetFontCollectionFamilyList", "ptr", coll
                  , "int", n, "ptr", fams, "int*", &trouve := 0)
            if (trouve < 1)
                return 0
            Police.fam := NumGet(fams, 0, "ptr")
        }
        return Police.fam
    }

    ;  Compile : la police est une ressource RCDATA (type 10) de l'exe.
    static _DepuisRessource(coll) {
        if (!A_IsCompiled)
            return false
        h := DllCall("FindResource", "ptr", 0, "str", Police.RESSOURCE, "ptr", 10, "ptr")
        if (!h)
            return false
        taille := DllCall("SizeofResource", "ptr", 0, "ptr", h, "uint")
        g := DllCall("LoadResource", "ptr", 0, "ptr", h, "ptr")
        p := g ? DllCall("LockResource", "ptr", g, "ptr") : 0
        if (!p || !taille)
            return false
        return DllCall("gdiplus\GdipPrivateAddMemoryFont", "ptr", coll
                     , "ptr", p, "int", taille) = 0
    }

    ;  Script : le fichier est a cote de ce module.
    static _DepuisFichier(coll) {
        f := A_LineFile . "\..\" . Police.FICHIER
        if (!FileExist(f))
            return false
        return DllCall("gdiplus\GdipPrivateAddFontFile", "ptr", coll, "wstr", f) = 0
    }
}
