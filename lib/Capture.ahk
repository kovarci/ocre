;==============================================================================
;  Capture.ahk -- la luminance moyenne d'un ecran, par duplication DXGI.
;
;  Copier l'ecran par GDI (StretchBlt) coute quatre a sept millisecondes de
;  processeur a chaque fois, la decimation se faisant en logiciel sur la
;  source entiere : a sept mesures par seconde, c'est trois pour cent d'un
;  coeur en permanence -- trop pour un utilitaire de barre des taches.
;
;  La duplication de bureau de DXGI, celle de Gammy et des logiciels de
;  capture, fait le travail du cote de la carte graphique : elle donne une
;  texture du bureau, qu'on copie dans une texture a nous munie d'une chaine
;  de mipmaps ; la carte genere la chaine -- chaque niveau est la moyenne du
;  precedent -- et l'on ne relit que le niveau de trente points de large.
;  Deux millisecondes quand l'image a change, rien quand elle n'a pas
;  change : AcquireNextFrame le dit sans rien rendre.
;
;  Tout passe par les tables de fonctions COM, a la main -- AutoHotkey n'a
;  pas de liaison Direct3D, et ComCall veut un objet, pas un pointeur nu.
;  Les indices sont ceux de d3d11.h et dxgi1_2.h ; chaque appel est
;  verifie, et tout echec rend la duplication a zero, pour qu'elle soit
;  refaite a la mesure suivante. Si Direct3D 11 manque -- une session
;  distante, une machine virtuelle sans pilote --, Luma rend -3 et
;  l'appelant retombe sur GDI.
;
;  Quatre pieges, tous rencontres, tous commentes a l'endroit ou ils
;  mordent : DllCall decharge d3d11.dll apres l'appel si on ne la tient
;  pas ; la premiere image d'une duplication est une surface restreinte
;  sans contenu ; CopyResource veut le meme nombre de niveaux des deux
;  cotes ; un HRESULT revient signe et se compare non signe.
;
;  Une duplication par ecran, faite a la premiere demande et gardee. Un
;  changement de mode, un plein ecran exclusif la font tomber
;  (DXGI_ERROR_ACCESS_LOST) : on la refait.
;==============================================================================

#Requires AutoHotkey v2.0

class Capture {

    static GRILLE_L := 64          ; les points echantillonnes, en largeur (chemin sans mipmaps)
    static GRILLE_H := 40          ; ... et en hauteur

    static device := 0             ; ID3D11Device
    static contexte := 0           ; ID3D11DeviceContext
    static dups := Map()           ; hmon -> { dup, copie, srv, niveau, staging, w, h, ... }
    static impossible := false     ; Direct3D 11 a manque une fois : on n'insiste pas

    ;  DXGI_ERROR_WAIT_TIMEOUT et DXGI_ERROR_ACCESS_LOST
    static TIMEOUT := 0x887A0027
    static PERDU := 0x887A0026

    ;--------------------------------------------------------------------------
    ;  La luminance moyenne de l'ecran e (un enregistrement d'Ecrans, avec
    ;  hmon et x, y, w, h), de 0 a 1. Ou :
    ;    -1  image toute noire (rien a en dire)
    ;    -2  rien n'a change depuis la derniere mesure
    ;    -3  la duplication est impossible ici : voir GDI
    ;--------------------------------------------------------------------------
    static Luma(e) {
        if (Capture.impossible || !e || !e.hmon)
            return -3
        d := Capture._Duplication(e)
        if (!d)
            return -3

        ;  DXGI_OUTDUPL_FRAME_INFO : 48 octets. Le delai a zero : on ne veut
        ;  pas attendre une image, seulement savoir s'il y en a une.
        info := Buffer(48, 0)
        hr := Capture._Appel(d.dup, 8, "uint", 0, "ptr", info, "ptr*", &res := 0, "int")
        ;  Le HRESULT revient signe sur 32 bits : on le compare non signe.
        if ((hr & 0xFFFFFFFF) = Capture.TIMEOUT)
            return -2
        if (hr < 0 || !res) {
            Capture._Lacher(e.hmon)
            return -3
        }

        ;  IDXGIResource -> ID3D11Texture2D, copie dans la texture lisible
        ;  -- faite a la premiere image, aux dimensions exactes de celle-ci
        ;  --, puis lecture. La lecture (Map) attend que la copie soit faite
        ;  sur la carte, et tout cela AVANT de rendre l'image : rendue plus
        ;  tot, elle pouvait etre reprise par le compositeur avant que la
        ;  copie s'execute, et l'on lisait du noir.
        luma := -3
        tex := Capture._QI(res, "{6f15aaf2-d208-4e89-9ab4-489535d34f9c}")
        if (tex) {
            try {
                ;  La toute premiere image d'une duplication n'est pas une
                ;  image : une surface partagee, restreinte (MiscFlags
                ;  0x2000), en demi-flottants, sans contenu. Les suivantes
                ;  sont en B8G8R8A8, sans indicateur. Une texture de lecture
                ;  faite a l'image de la premiere ne recevait jamais rien --
                ;  CopyResource se tait quand les formats different -- et l'on
                ;  lisait du noir pour toujours. On regarde donc chaque
                ;  image, on passe celles qui n'en sont pas, et l'on refait la
                ;  texture de lecture quand le format change.
                td := Buffer(44, 0)
                Capture._Appel(tex, 10, "ptr", td, "int")                        ; GetDesc
                if (NumGet(td, 40, "UInt") & 0x2000) {
                    luma := -2
                } else if (NumGet(td, 16, "UInt") = 87) {
                    luma := Capture._ParMips(d, tex, td)
                } else {
                    Capture._Staging(d, td)
                    if (d.staging) {
                        Capture._Appel(Capture.contexte, 47, "ptr", d.staging, "ptr", tex, "int")  ; CopyResource
                        luma := Capture._Lire(d)
                    }
                }
            }
            ObjRelease(tex)
        }
        ObjRelease(res)
        Capture._Appel(d.dup, 14, "int")                                             ; ReleaseFrame
        if (luma = -3)
            Capture._Lacher(e.hmon)
        return luma
    }

    ;--------------------------------------------------------------------------
    ;  Le chemin ordinaire, B8G8R8A8 : la moyenne est faite par la carte.
    ;
    ;  Relire les neuf megaoctets d'un bureau entier coutait cinq
    ;  millisecondes de processeur par image -- autant que GDI, et c'est le
    ;  transfert, pas le calcul. On copie donc l'image dans une texture a
    ;  nous qui a une chaine de mipmaps, on demande a la carte de la
    ;  generer (GenerateMips : chaque niveau est la moyenne du precedent,
    ;  deux points sur deux), et l'on ne relit que le niveau qui fait
    ;  trente points de large : deux kilooctets, et une vraie moyenne de
    ;  tous les points de l'ecran, pas un echantillon.
    ;--------------------------------------------------------------------------
    static _ParMips(d, tex, td) {
        w := NumGet(td, 0, "UInt"), h := NumGet(td, 4, "UInt")
        if (!d.copie || d.w != w || d.h != h)
            Capture._Chaine(d, td)
        if (!d.copie)
            return -3
        ctx := Capture.contexte
        ;  Le niveau 0 seulement : CopyResource veut le meme nombre de
        ;  niveaux des deux cotes, et le notre en a toute une chaine.
        Capture._Appel(ctx, 46, "ptr", d.copie, "uint", 0, "uint", 0, "uint", 0, "uint", 0
                     , "ptr", tex, "uint", 0, "ptr", 0, "int")                       ; CopySubresourceRegion
        Capture._Appel(ctx, 54, "ptr", d.srv, "int")                                 ; GenerateMips
        Capture._Appel(ctx, 46, "ptr", d.staging, "uint", 0, "uint", 0, "uint", 0, "uint", 0
                     , "ptr", d.copie, "uint", d.niveau, "ptr", 0, "int")            ; CopySubresourceRegion
        return Capture._Lire(d)
    }

    ;  La texture a mipmaps, sa vue, le niveau qu'on lit et la petite
    ;  texture de lecture a sa taille. Refaits si l'ecran change de taille.
    static _Chaine(d, td) {
        Capture._Rendre(d)
        w := NumGet(td, 0, "UInt"), h := NumGet(td, 4, "UInt")
        ;  Le niveau : le premier dont la largeur tombe sous 40 points --
        ;  30 x 18 pour un ecran 1920 x 1200, cinq cents points a relire,
        ;  et la moyenne est la meme, la carte l'ayant faite.
        niveau := 0, lw := w, lh := h
        while (lw > 40 && lh > 1) {
            lw := Max(1, lw // 2), lh := Max(1, lh // 2), niveau += 1
        }
        ;  DEFAULT (0), RENDER_TARGET | SHADER_RESOURCE (0x28), GENERATE_MIPS
        ;  (0x1), MipLevels 0 : toute la chaine.
        tc := Buffer(44, 0)
        NumPut("UInt", w, tc, 0), NumPut("UInt", h, tc, 4), NumPut("UInt", 0, tc, 8), NumPut("UInt", 1, tc, 12)
        NumPut("UInt", 87, tc, 16), NumPut("UInt", 1, tc, 20), NumPut("UInt", 0, tc, 28)
        NumPut("UInt", 0x28, tc, 32), NumPut("UInt", 0, tc, 36), NumPut("UInt", 0x1, tc, 40)
        copie := 0, srv := 0, staging := 0
        if (Capture._Appel(Capture.device, 5, "ptr", tc, "ptr", 0, "ptr*", &copie, "int") < 0 || !copie)
            return
        if (Capture._Appel(Capture.device, 7, "ptr", copie, "ptr", 0, "ptr*", &srv, "int") < 0 || !srv) {
            ObjRelease(copie)
            return
        }
        ts := Buffer(44, 0)
        NumPut("UInt", lw, ts, 0), NumPut("UInt", lh, ts, 4), NumPut("UInt", 1, ts, 8), NumPut("UInt", 1, ts, 12)
        NumPut("UInt", 87, ts, 16), NumPut("UInt", 1, ts, 20), NumPut("UInt", 3, ts, 28)
        NumPut("UInt", 0, ts, 32), NumPut("UInt", 0x20000, ts, 36), NumPut("UInt", 0, ts, 40)
        if (Capture._Appel(Capture.device, 5, "ptr", ts, "ptr", 0, "ptr*", &staging, "int") < 0 || !staging) {
            ObjRelease(srv), ObjRelease(copie)
            return
        }
        d.copie := copie, d.srv := srv, d.niveau := niveau
        d.staging := staging, d.w := w, d.h := h, d.fmt := 87
        d.lw := lw, d.lh := lh
    }

    ;  Rend ce qu'une duplication tient en textures.
    static _Rendre(d) {
        for k in ["staging", "srv", "copie"] {
            if (d.%k%)
                try ObjRelease(d.%k%)
            d.%k% := 0
        }
    }

    ;  La texture lisible, mappee le temps d'une moyenne. D3D11_MAPPED_SUBRESOURCE :
    ;  pData, RowPitch, DepthPitch. D3D11_MAP_READ = 1.
    static _Lire(d) {
        mapped := Buffer(16, 0)
        if (Capture._Appel(Capture.contexte, 14, "ptr", d.staging, "uint", 0, "uint", 1
                         , "uint", 0, "ptr", mapped, "int") < 0)
            return -3
        ;  Ce que la duplication donne est en lumiere LINEAIRE -- un gris
        ;  128 se lit 0,215, pas 0,502 -- que le bureau soit compose en HDR
        ;  ou non ; la moyenne des mipmaps l'est donc aussi. On la ramene en
        ;  sRGB, l'echelle de GDI et de l'oeil : mesure sur dix gris, l'ecart
        ;  avec GDI est alors de moins d'un centieme.
        luma := d.copie
            ? Capture._MoyenneEntiere(NumGet(mapped, 0, "ptr"), NumGet(mapped, 8, "uint"), d.lw, d.lh)
            : Capture._Moyenne(NumGet(mapped, 0, "ptr"), NumGet(mapped, 8, "uint"), d.w, d.h, d.fmt)
        if (luma > 0 && (d.copie || d.fmt = 10))
            luma := Capture._Srgb(luma)
        Capture._Appel(Capture.contexte, 15, "ptr", d.staging, "uint", 0, "int")    ; Unmap
        return luma
    }

    ;  La texture de lecture, a l'image de celle du bureau (td, sa
    ;  description) : meme taille, meme format, mais STAGING (3), lisible par
    ;  le processeur (0x20000), sans liaison. Gardee tant que l'image ne
    ;  change pas de format ni de taille. D3D11_TEXTURE2D_DESC : Width,
    ;  Height, MipLevels, ArraySize, Format, SampleDesc{Count, Quality},
    ;  Usage, BindFlags, CPUAccessFlags, MiscFlags -- 44 octets.
    static _Staging(d, td) {
        w := NumGet(td, 0, "UInt"), h := NumGet(td, 4, "UInt"), fmt := NumGet(td, 16, "UInt")
        if (d.staging && !d.copie && d.w = w && d.h = h && d.fmt = fmt)
            return
        Capture._Rendre(d)
        NumPut("UInt", 1, td, 8), NumPut("UInt", 1, td, 12)
        NumPut("UInt", 3, td, 28), NumPut("UInt", 0, td, 32)
        NumPut("UInt", 0x20000, td, 36), NumPut("UInt", 0, td, 40)
        if (Capture._Appel(Capture.device, 5, "ptr", td, "ptr", 0, "ptr*", &staging := 0, "int") < 0)
            return
        d.staging := staging
        d.w := w, d.h := h, d.fmt := fmt
    }

    ;  Rec. 601 sur une grille de points de l'image. Le bureau est en
    ;  B8G8R8A8 (87, 88, 91) d'ordinaire, en R16G16B16A16_FLOAT (10) quand
    ;  Windows compose en HDR ou en couleur avancee : un demi-flottant par
    ;  composante, lineaire, dont on prend la valeur telle quelle -- une
    ;  moyenne, pas un etalonnage.
    static _Moyenne(pData, pitch, w, h, fmt := 87) {
        gl := Capture.GRILLE_L, gh := Capture.GRILLE_H
        somme := 0.0
        if (fmt = 10) {
            Loop gh {
                ligne := pData + ((A_Index - 1) * h // gh) * pitch
                Loop gl {
                    p := ligne + ((A_Index - 1) * w // gl) * 8
                    somme += 0.299 * Capture._Demi(NumGet(p, 0, "UShort"))
                           + 0.587 * Capture._Demi(NumGet(p, 2, "UShort"))
                           + 0.114 * Capture._Demi(NumGet(p, 4, "UShort"))
                }
            }
            return somme = 0 ? -1 : Min(1.0, somme / (gl * gh))
        }
        Loop gh {
            ligne := pData + ((A_Index - 1) * h // gh) * pitch
            Loop gl {
                p := NumGet(ligne + ((A_Index - 1) * w // gl) * 4, "UInt")
                somme += 299 * ((p >> 16) & 0xFF) + 587 * ((p >> 8) & 0xFF) + 114 * (p & 0xFF)
            }
        }
        return somme = 0 ? -1 : somme / (gl * gh * 255000.0)
    }

    ;  Rec. 601 sur tous les points d'une petite image B8G8R8A8.
    static _MoyenneEntiere(pData, pitch, w, h) {
        somme := 0
        Loop h {
            ligne := pData + (A_Index - 1) * pitch
            Loop w {
                p := NumGet(ligne + (A_Index - 1) * 4, "UInt")
                somme += 299 * ((p >> 16) & 0xFF) + 587 * ((p >> 8) & 0xFF) + 114 * (p & 0xFF)
            }
        }
        return somme = 0 ? -1 : somme / (w * h * 255000.0)
    }

    ;  Lineaire -> sRGB (IEC 61966-2-1).
    static _Srgb(l) {
        l := Max(0.0, Min(1.0, l))
        return l <= 0.0031308 ? l * 12.92 : 1.055 * (l ** (1 / 2.4)) - 0.055
    }

    ;  Un demi-flottant IEEE 754 (binary16) vers un nombre, sans les cas
    ;  infinis, qu'un bureau ne montre pas.
    static _Demi(h) {
        signe := (h >> 15) ? -1 : 1
        exp := (h >> 10) & 0x1F
        mant := h & 0x3FF
        if (exp = 0)
            return signe * mant * (2.0 ** -24)
        if (exp = 31)
            return signe * 65504.0
        return signe * (1 + mant / 1024.0) * (2.0 ** (exp - 15))
    }

    ;  Le peripherique Direct3D, une fois. D3D_DRIVER_TYPE_HARDWARE = 1,
    ;  D3D11_SDK_VERSION = 7.
    static _Device() {
        if (Capture.device)
            return true
        ;  DllCall charge une bibliotheque le temps d'un appel et la decharge
        ;  ensuite si personne ne la tenait : les objets Direct3D pointeraient
        ;  alors vers des tables de fonctions disparues, et le premier appel
        ;  ferait tomber le programme. On les tient donc explicitement, pour
        ;  toute la vie du processus.
        DllCall("LoadLibrary", "str", "d3d11.dll", "ptr")
        DllCall("LoadLibrary", "str", "dxgi.dll", "ptr")

        ;  Le peripherique est cree sur l'adaptateur qui porte l'ecran (le
        ;  premier de la fabrique DXGI), nomme explicitement, avec les
        ;  niveaux 11.0 puis 10.x -- exactement comme les outils de capture.
        ;  Laisser le runtime choisir (adaptateur nul, type HARDWARE) donnait
        ;  ici un peripherique sur le meme adaptateur, mais une duplication
        ;  d'une autre nature : des images partagees, en demi-flottants, et
        ;  vides a la lecture.
        adapt := Capture._Adaptateur()
        niveaux := Buffer(12, 0)
        NumPut("UInt", 0xB000, niveaux, 0), NumPut("UInt", 0xA100, niveaux, 4), NumPut("UInt", 0xA000, niveaux, 8)
        hr := DllCall("d3d11\D3D11CreateDevice", "ptr", adapt, "int", adapt ? 0 : 1, "ptr", 0, "uint", 0
                    , "ptr", niveaux, "uint", 3, "uint", 7
                    , "ptr*", &dev := 0, "uint*", &niveau := 0, "ptr*", &ctx := 0, "int")
        if (adapt)
            ObjRelease(adapt)
        if (hr < 0 || !dev) {
            Capture.impossible := true
            return false
        }
        Capture.device := dev
        Capture.contexte := ctx
        return true
    }

    ;  Le premier adaptateur de la fabrique DXGI, ou 0.
    static _Adaptateur() {
        guid := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "wstr", "{770aae78-f26f-4dba-a829-253c83d1b387}", "ptr", guid)
        fab := 0, adapt := 0
        if (DllCall("dxgi\CreateDXGIFactory1", "ptr", guid, "ptr*", &fab, "int") < 0 || !fab)
            return 0
        try Capture._Appel(fab, 7, "uint", 0, "ptr*", &adapt, "int")                ; EnumAdapters
        ObjRelease(fab)
        return adapt
    }

    ;  La duplication de l'ecran e, et sa texture de lecture, gardees.
    static _Duplication(e) {
        if (Capture.dups.Has(e.hmon))
            return Capture.dups[e.hmon]
        if (!Capture._Device())
            return 0

        dup := 0
        ;  ID3D11Device -> IDXGIDevice -> IDXGIAdapter, puis chaque
        ;  IDXGIOutput jusqu'a celui dont le moniteur est le notre.
        dxgi := Capture._QI(Capture.device, "{54ec77fa-1377-44e6-8c32-88fd5f44c84c}")
        if (!dxgi)
            return 0
        adapt := 0
        try Capture._Appel(dxgi, 7, "ptr*", &adapt, "int")                                  ; GetAdapter
        ObjRelease(dxgi)
        if (!adapt)
            return 0
        Loop {
            out := 0
            if (Capture._Appel(adapt, 7, "uint", A_Index - 1, "ptr*", &out, "int") < 0 || !out)
                break                                                         ; EnumOutputs
            ;  DXGI_OUTPUT_DESC : DeviceName[32] wchar, RECT, BOOL, Rotation,
            ;  HMONITOR a 88.
            desc := Buffer(96, 0)
            Capture._Appel(out, 7, "ptr", desc, "int")                               ; GetDesc
            if (NumGet(desc, 88, "ptr") = e.hmon) {
                ;  IDXGIOutput5::DuplicateOutput1, en demandant du B8G8R8A8 :
                ;  un bureau compose en HDR ou en couleur avancee (Windows 11)
                ;  est alors converti pour nous, et lisible en octets. Sans
                ;  cela, l'ancien DuplicateOutput rend des images en demi-
                ;  flottants qui, sur un tel bureau, arrivent vides.
                ;
                ;  DuplicateOutput1 exige un processus conscient du DPI par
                ;  moniteur, et rend DXGI_ERROR_UNSUPPORTED sinon. AutoHotkey
                ;  ne l'est que pour le systeme : on passe le fil dans ce
                ;  contexte le temps de l'appel (PER_MONITOR_AWARE_V2 = -4),
                ;  et on le rend aussitot.
                out5 := Capture._QI(out, "{80a07424-ab52-42eb-833c-0c42fd282d98}")
                if (out5) {
                    formats := Buffer(4, 0)
                    NumPut("UInt", 87, formats, 0)
                    avant := 0
                    try avant := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
                    if (Capture._Appel(out5, 26, "ptr", Capture.device, "uint", 0, "uint", 1
                                     , "ptr", formats, "ptr*", &dup, "int") < 0)
                        dup := 0                                              ; DuplicateOutput1
                    if (avant)
                        try DllCall("SetThreadDpiAwarenessContext", "ptr", avant, "ptr")
                    ObjRelease(out5)
                }
                if (!dup) {
                    out1 := Capture._QI(out, "{00cddea8-939b-4b83-a340-a685226666cc}")
                    if (out1) {
                        if (Capture._Appel(out1, 22, "ptr", Capture.device, "ptr*", &dup, "int") < 0)
                            dup := 0                                          ; DuplicateOutput
                        ObjRelease(out1)
                    }
                }
            }
            ObjRelease(out)
            if (dup)
                break
        }
        ObjRelease(adapt)
        if (!dup)
            return 0
        d := { dup: dup, staging: 0, copie: 0, srv: 0, niveau: 0, lw: 0, lh: 0, w: e.w, h: e.h, fmt: 87 }
        Capture.dups[e.hmon] := d
        return d
    }

    ;  Un appel par la table des fonctions : ComCall et ComObjQuery veulent
    ;  un objet, pas un pointeur nu, et tout ce qu'on tient ici est nu. Le
    ;  dernier parametre est le type de retour, "int" pour un HRESULT.
    static _Appel(ptr, index, params*) {
        fn := NumGet(NumGet(ptr, 0, "ptr"), index * A_PtrSize, "ptr")
        return DllCall(fn, "ptr", ptr, params*)
    }

    ;  QueryInterface : un pointeur brut en entree, un pointeur brut en
    ;  sortie (a rendre par ObjRelease), ou 0.
    static _QI(ptr, iid) {
        guid := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "wstr", iid, "ptr", guid)
        out := 0
        try Capture._Appel(ptr, 0, "ptr", guid, "ptr*", &out, "int")
        return out
    }

    ;  Une duplication tombee : on la rend, elle sera refaite.
    static _Lacher(hmon) {
        if (!Capture.dups.Has(hmon))
            return
        d := Capture.dups[hmon]
        Capture._Rendre(d)
        try ObjRelease(d.dup)
        Capture.dups.Delete(hmon)
    }

    ;  Tout rendre : a la sortie, ou quand les ecrans changent.
    static Oublier() {
        for hmon in Capture.dups.Clone()
            Capture._Lacher(hmon)
    }
}
