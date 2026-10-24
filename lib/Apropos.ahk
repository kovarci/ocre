;==============================================================================
;  Apropos.ahk -- la fenetre "A propos".
;
;  La version, le projet, de quoi signaler un probleme, et les licences de ce
;  qui est embarque dans l'executable. Version() disait deja "1.3.0" dans
;  l'infobulle de l'icone ; ici, c'est la ou l'on va la chercher quand on
;  ecrit un ticket.
;
;  "Copier le diagnostic" met dans le presse-papiers ce que /diag affiche : la
;  version, la build de Windows, les ecrans, l'etat des reglages qui comptent.
;  Pas de nom d'utilisateur, rien de personnel (voir Diagnostic(), dans
;  Ocre.ahk). Le ticket type le demande : c'est le moyen de ne pas faire un
;  aller-retour de questions.
;
;  Ocre lui-meme n'ouvre aucune connexion : les deux liens ouvrent le
;  navigateur de l'utilisateur, a son clic.
;
;  Les trois effets de bord -- ouvrir une adresse, ecrire dans le presse-papiers,
;  ouvrir le dossier des reglages -- sont des rappels remplacables : les tests
;  n'ont ni a lancer un navigateur ni a ecraser le presse-papiers de qui les
;  lance.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Blob.ahk
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\I18n.ahk
#Include %A_LineFile%\..\Widgets.ahk
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\Cadre.ahk

class Apropos {

    static L := 464
    static DEPOT := "https://github.com/kovarci/ocre"
    static VERSIONS := "https://github.com/kovarci/ocre/releases"

    static porteur := 0        ; le cadre redimensionnable (voir Cadre.ahk)
    static gui := 0
    static c := 0

    ;  Ce que la fenetre ne sait pas elle-meme : la version et le diagnostic
    ;  vivent dans Ocre.ahk. Sans Init, elle dit "?" et ne copie rien.
    static version := () => "?"
    static diagnostic := () => ""

    ;  Pas "ouvrir" : AutoHotkey ne distingue pas les majuscules, et la propriete
    ;  voulait prendre la place de la methode Ouvrir() -- "Property is
    ;  read-only", au chargement, avant meme que l'application ne soit la.
    static lancer := (cible) => Run(cible)
    static copier := (texte) => (A_Clipboard := texte)
    static dossier := () => Run('explorer.exe "' . Config.DOSSIER . '"')

    static Init(version, diagnostic) {
        Apropos.version := version
        Apropos.diagnostic := diagnostic
    }

    static Ouvrir() {
        if (Apropos.gui) {
            try WinActivate("ahk_id " . Apropos.gui.Hwnd)
            return
        }
        Apropos._Construire()
    }

    static _Construire() {
        c := Map()
        S := (k) => I18n.S(k)

        porteur := Cadre.Creer("Ocre", Apropos.L)
        g := porteur.contenu

        ;--- en-tete : le meme que celui des reglages ------------------------
        c["logo"] := g.Add("Picture", "x24 y22 w40 h40")
        Blob.Poser(c["logo"], 70, 40)

        g.SetFont("s14 w600 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x78 y24 w200 h26", "Ocre")
        g.SetFont("s9 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        c["version"] := g.Add("Text", "x78 y50 w240 h18"
                            , Format(S("version_n"), (Apropos.version)()))

        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y84 w416 h64", S("apropos_texte"))

        ;--- liens ------------------------------------------------------------
        Apropos._Intitule(g, 24, 156, S("liens_titre"))
        c["depot"] := Bouton.Creer(g, 24, 176, 204, 26, S("lien_depot"), false
                                 , () => Apropos._Ouvrir(Apropos.DEPOT))
        c["versions"] := Bouton.Creer(g, 236, 176, 204, 26, S("lien_versions"), false
                                    , () => Apropos._Ouvrir(Apropos.VERSIONS))

        ;--- assistance -------------------------------------------------------
        Apropos._Intitule(g, 24, 218, S("assistance_titre"))
        c["diag"] := Bouton.Creer(g, 24, 238, 204, 26, S("copier_diag"), true
                                , () => Apropos._Copier())
        c["dossier"] := Bouton.Creer(g, 236, 238, 204, 26, S("dossier_reglages"), false
                                   , () => Apropos._Dossier())

        ;  Le retour de la copie : sans lui, un clic qui ne montre rien passe
        ;  pour un bouton casse.
        g.SetFont("s8 w400 c" . Theme.ACCENT, "Segoe UI")
        c["etat"] := g.Add("Text", "x24 y272 w416 h16", "")

        ;--- licences ---------------------------------------------------------
        Apropos._Intitule(g, 24, 302, S("licences_titre"))
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x24 y320 w416 h48", S("licences_texte"))

        Apropos.gui := porteur.fenetre
        Apropos.porteur := porteur
        Apropos.c := c

        Cadre.Presenter(porteur, 392, "apropos", () => Apropos.Fermer())
    }

    static _Intitule(g, x, y, texte) {
        g.SetFont("s7 w600 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x" . x . " y" . y . " w260 h14", texte)
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
    }

    static _Ouvrir(cible) {
        try (Apropos.lancer)(cible)
    }

    static _Copier() {
        try (Apropos.copier)((Apropos.diagnostic)())
        catch
            return
        if (!Apropos.c)
            return
        Apropos.c["etat"].Text := I18n.S("diag_copie")
        SetTimer(() => Apropos._Effacer(), -4000)
    }

    ;  La fenetre a pu se fermer entre-temps.
    static _Effacer() {
        if (Apropos.c)
            try Apropos.c["etat"].Text := ""
    }

    ;  Le dossier n'existe qu'une fois un reglage ecrit : l'ouvrir avant
    ;  ouvrirait "Documents", ce qui ne dit rien.
    static _Dossier() {
        try DirCreate(Config.DOSSIER)
        try (Apropos.dossier)()
    }

    static Fermer() {
        if (Apropos.porteur) {
            Cadre.Detruire(Apropos.porteur)
            Apropos.porteur := 0
            Apropos.gui := 0
            Apropos.c := 0
        }
    }
}
