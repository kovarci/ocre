;==============================================================================
;  Villes.ahk -- ou l'on est sur le globe, sans rien demander au reseau.
;
;  Le calcul solaire (voir Soleil.ahk) veut une latitude et une longitude.
;  Personne ne les connait par coeur : il faut donc pouvoir dire "Annecy" et
;  obtenir 45,91 / 6,13. C'est le seul role de ce fichier.
;
;  La table vient de GeoNames, filtree aux villes de plus de 20 000 habitants
;  et triee par population decroissante -- ce tri EST le classement des
;  resultats : taper "par" doit donner Paris avant Paranagua.
;
;  Elle est en ASCII pur, noms compris : ce fichier n'a pas de BOM et des
;  accents y seraient relus en ANSI. C'est la saisie qui est rabattue sur
;  l'ASCII avant comparaison, par Pays.Simplifier -- qui vit la-bas parce que
;  Pays.ahk, lui, a un BOM et peut ecrire ses accents en clair.
;
;  La table vit dans lib/villes.txt, un enregistrement par ligne, et n'est
;  lue qu'a la premiere recherche. Elle a d'abord ete un litteral dans ce
;  fichier ; les 700 Ko etaient alors analyses a chaque demarrage -- 33 ms
;  une fois les sequences d'echappement desactivees, 1,1 s avant -- pour une
;  fenetre qu'on ouvre une fois. Un fichier a cote du script quand on
;  l'interprete, une ressource de l'exe une fois compile (AddResource dans
;  Ocre.ahk) : le demarrage ne la voit plus passer.
;
;  Regeneration : tools/make-villes.ps1
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Pays.ahk

class Villes {

    static RESSOURCE := "VILLES"
    static chargee := ""

    ;  La table, lue a la premiere demande et gardee. Compile, c'est une
    ;  ressource RCDATA de l'exe (comme la police, voir Police.ahk) ; sinon
    ;  le fichier a cote de ce script. Une table introuvable vaut une table
    ;  vide : la recherche ne trouve rien, le reste marche.
    static TABLE {
        get {
            if (Villes.chargee != "")
                return Villes.chargee
            t := ""
            try {
                if (A_IsCompiled) {
                    h := DllCall("FindResource", "ptr", 0, "str", Villes.RESSOURCE, "ptr", 10, "ptr")
                    taille := h ? DllCall("SizeofResource", "ptr", 0, "ptr", h, "uint") : 0
                    g := h ? DllCall("LoadResource", "ptr", 0, "ptr", h, "ptr") : 0
                    p := g ? DllCall("LockResource", "ptr", g, "ptr") : 0
                    if (p && taille)
                        t := StrGet(p, taille, "CP0")
                } else {
                    t := FileRead(A_LineFile . "\..\villes.txt")
                }
            }
            Villes.chargee := t
            return t
        }
    }

    ;--------------------------------------------------------------------------
    ;  Exonymes.
    ;
    ;  GeoNames nomme les villes dans une langue qui n'est ni tout a fait la
    ;  locale ni tout a fait l'anglais : Geneve y est "Geneva", Seville
    ;  "Sevilla", Cologne "Koeln". Quelqu'un qui cherche sa ville tape le nom
    ;  qu'il emploie, pas celui de la base.
    ;
    ;  Le champ alternatenames de GeoNames a ete essaye pour automatiser cette
    ;  table : il est trie alphabetiquement et melange codes d'aeroport et
    ;  translitterations de toutes les langues -- pour Geneve il donne "GVA",
    ;  "Cenevre" et "Genava", jamais le nom francais. La liste ci-dessous est
    ;  donc ecrite a la main, et chaque entree verifiee contre la table.
    ;
    ;  Les cles sont sans accent et en minuscules : elles sont comparees a une
    ;  saisie deja mise a plat.
    ;--------------------------------------------------------------------------
    static ALIAS := Map(
        "geneve", "Geneva",
        "bale", "Basel",
        "berne", "Bern",
        "anvers", "Antwerp",
        "antwerpen", "Antwerp",
        "gand", "Gent",
        "bruxelles", "Brussels",
        "brussel", "Brussels",
        "la haye", "The Hague",
        "den haag", "The Hague",
        "londres", "London",
        "edimbourg", "Edinburgh",
        "copenhague", "Copenhagen",
        "kobenhavn", "Copenhagen",
        "goteborg", "Gothenburg",
        "varsovie", "Warsaw",
        "warszawa", "Warsaw",
        "cracovie", "Krakow",
        "praha", "Prague",
        "moscou", "Moscow",
        "moskva", "Moscow",
        "saint-petersbourg", "Saint Petersburg",
        "bucarest", "Bucharest",
        "bucuresti", "Bucharest",
        "athenes", "Athens",
        "athina", "Athens",
        "salonique", "Thessaloniki",
        "lisbonne", "Lisbon",
        "lisboa", "Lisbon",
        "saragosse", "Zaragoza",
        "cordoue", "Cordoba",
        "grenade", "Granada",
        "barcelone", "Barcelona",
        "venise", "Venice",
        "venezia", "Venice",
        "genes", "Genoa",
        "genova", "Genoa",
        "roma", "Rome",
        "milano", "Milan",
        "firenze", "Florence",
        "napoli", "Naples",
        "torino", "Turin",
        "munchen", "Munich",
        "muenchen", "Munich",
        "francfort", "Frankfurt am Main",
        "hambourg", "Hamburg",
        "aix-la-chapelle", "Aachen",
        "vienne", "Vienna",
        "wien", "Vienna",
        "beograd", "Belgrade",
        "le caire", "Cairo",
        "alger", "Algiers",
        "pekin", "Beijing",
        "canton", "Guangzhou",
        "nankin", "Nanjing",
        "bombay", "Mumbai",
        "calcutta", "Kolkata",
        "madras", "Chennai",
        "singapour", "Singapore",
        "damas", "Damascus",
        "bagdad", "Baghdad",
        "teheran", "Tehran",
        "la havane", "Havana",
        "mexico", "Mexico City",
        "nouvelle-orleans", "New Orleans",
        "seville", "Sevilla",
        "la mecque", "Makkah",
        "cologne", "Koeln",
        "koln", "Koeln",
        "dusseldorf", "Duesseldorf"
)

    ;--------------------------------------------------------------------------
    ;  Cherche une ville. Accepte "Lyon", "Lyon, France" et "Lyon, FR".
    ;
    ;  Renvoie une liste d'objets { nom, pays, lat, lon }, les correspondances
    ;  par le debut d'abord : taper "nan" cherche Nantes, pas Yinchuan.
    ;--------------------------------------------------------------------------
    static Chercher(requete, maxi := 8) {
        requete := Trim(requete)

        ;  Une virgule restreint a un pays. Si ce qui la suit ne designe aucun
        ;  pays connu, on ne jette pas la recherche pour autant : la requete
        ;  entiere redevient un nom de ville.
        cc := ""
        if (RegExMatch(requete, "^(.+?)\s*,\s*(.+)$", &m)) {
            trouve := Pays.Code(m[2])
            if (trouve != "") {
                cc := trouve
                requete := Trim(m[1])
            }
        }

        ;  Deux facons de rabattre une saisie accentuee, et il faut les deux :
        ;  GeoNames translittere les villes allemandes a l'allemande --
        ;  "Koeln", "Duesseldorf" -- la ou la mise a plat ordinaire donne
        ;  "Koln" et "Dusseldorf".
        formes := []
        Villes._Ajouter(formes, Pays.Simplifier(requete))
        Villes._Ajouter(formes, Pays.Allemand(requete))
        for f in formes.Clone()
            Villes._Ajouter(formes, Villes._Exonyme(f))

        if (!formes.Length)
            return []

        debuts := []
        dedans := []

        ;  Un InStr sur l'enregistrement entier avant de le decouper : le
        ;  decoupage coute bien plus cher que le test, et il ne concerne
        ;  qu'une poignee des 26 000 lignes.
        Loop Parse Villes.TABLE, "`n", "`r" {
            vu := false
            for f in formes {
                if (InStr(A_LoopField, f)) {
                    vu := true
                    break
                }
            }
            if (!vu)
                continue

            e := StrSplit(A_LoopField, "|")
            if (e.Length < 4)
                continue
            if (cc != "" && e[2] != cc)
                continue

            ;  Le test precedent portait sur la ligne entiere, code pays et
            ;  coordonnees compris : il faut le refaire sur le seul nom.
            debut := false
            milieu := false
            for f in formes {
                if (SubStr(e[1], 1, StrLen(f)) = f)
                    debut := true
                else if (InStr(e[1], f))
                    milieu := true
            }
            if (!debut && !milieu)
                continue

            v := { nom: e[1], pays: e[2], lat: e[3] + 0, lon: e[4] + 0 }

            ;  La table etant triee par population, les premieres trouvailles
            ;  sont deja les bonnes : on s'arrete des qu'il y en a assez.
            if (debut) {
                debuts.Push(v)
                if (debuts.Length >= maxi)
                    break
            } else if (dedans.Length < maxi) {
                dedans.Push(v)
            }
        }

        ;  Les correspondances en milieu de mot completent la liste, jamais ne
        ;  la precedent.
        for v in dedans {
            if (debuts.Length >= maxi)
                break
            debuts.Push(v)
        }
        return debuts
    }

    ;  Une forme trop courte ferait remonter la moitie de la table.
    static _Ajouter(formes, f) {
        if (StrLen(f) < 2)
            return
        for deja in formes {
            if (deja = f)
                return
        }
        formes.Push(f)
    }

    ;  L'exonyme correspondant, par le nom entier ou par son debut : "genev"
    ;  doit deja mener a Geneva, sans quoi la liste reste vide pendant qu'on
    ;  finit de taper.
    static _Exonyme(f) {
        bas := StrLower(f)
        if (Villes.ALIAS.Has(bas))
            return Villes.ALIAS[bas]
        if (StrLen(bas) < 3)
            return ""
        n := StrLen(bas)
        for cle, nom in Villes.ALIAS {
            if (SubStr(cle, 1, n) = bas)
                return nom
        }
        return ""
    }
}
