;==============================================================================
;  Fuseau.ahk -- un lieu approximatif, deduit du fuseau horaire de Windows.
;
;  Le mode solaire veut une latitude et une longitude, et la fenetre du lieu
;  s'ouvre vide. Sans rien demander au reseau, une chose est deja connue :
;  le fuseau horaire choisi dans Windows -- "Romance Standard Time" pour la
;  France, "Eastern Standard Time" pour New York. Une ville par fuseau, et
;  le soleil est bon a quelques minutes pres pour toute une bande de
;  longitude, ce qu'un fondu de trois heures ne distingue pas.
;
;  C'est un defaut, pas un reglage : la fenetre du lieu le dit "(d'apres le
;  fuseau horaire)", et un lieu saisi le remplace. Un fuseau inconnu de la
;  table ne donne rien, et les heures fixes reprennent la main comme avant.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Villes.ahk

class Fuseau {

    ;  Le nom Windows du fuseau (cle TimeZoneKeyName) -> une ville de la
    ;  table. Les grands fuseaux d'abord ; ceux qui manquent donnent "".
    static VILLES := Map(
        "Romance Standard Time",          "Paris",
        "W. Europe Standard Time",        "Berlin",
        "Central Europe Standard Time",   "Prague",
        "Central European Standard Time", "Warsaw",
        "GMT Standard Time",              "London",
        "Greenwich Standard Time",        "Reykjavik",
        "E. Europe Standard Time",        "Chisinau",
        "FLE Standard Time",              "Helsinki",
        "GTB Standard Time",              "Athens",
        "Turkey Standard Time",           "Istanbul",
        "Russian Standard Time",          "Moscow",
        "Belarus Standard Time",          "Minsk",
        "Israel Standard Time",           "Jerusalem",
        "Egypt Standard Time",            "Cairo",
        "Morocco Standard Time",          "Casablanca",
        "South Africa Standard Time",     "Johannesburg",
        "E. Africa Standard Time",        "Nairobi",
        "W. Central Africa Standard Time", "Lagos",
        "Namibia Standard Time",          "Windhoek",
        "Arabian Standard Time",          "Dubai",
        "Arab Standard Time",             "Riyadh",
        "Iran Standard Time",             "Tehran",
        "Georgian Standard Time",         "Tbilisi",
        "Caucasus Standard Time",         "Yerevan",
        "Azerbaijan Standard Time",       "Baku",
        "Pakistan Standard Time",         "Karachi",
        "India Standard Time",            "Mumbai",
        "Sri Lanka Standard Time",        "Colombo",
        "Nepal Standard Time",            "Kathmandu",
        "Bangladesh Standard Time",       "Dhaka",
        "Myanmar Standard Time",          "Yangon",
        "SE Asia Standard Time",          "Bangkok",
        "Singapore Standard Time",        "Singapore",
        "China Standard Time",            "Shanghai",
        "Taipei Standard Time",           "Taipei",
        "Korea Standard Time",            "Seoul",
        "Tokyo Standard Time",            "Tokyo",
        "W. Australia Standard Time",     "Perth",
        "Cen. Australia Standard Time",   "Adelaide",
        "AUS Central Standard Time",      "Darwin",
        "E. Australia Standard Time",     "Brisbane",
        "AUS Eastern Standard Time",      "Sydney",
        "Tasmania Standard Time",         "Hobart",
        "New Zealand Standard Time",      "Auckland",
        "Hawaiian Standard Time",         "Honolulu",
        "Alaskan Standard Time",          "Anchorage",
        "Pacific Standard Time",          "Los Angeles",
        "Mountain Standard Time",         "Denver",
        "US Mountain Standard Time",      "Phoenix",
        "Central Standard Time",          "Chicago",
        "Canada Central Standard Time",   "Regina",
        "Central Standard Time (Mexico)", "Mexico City",
        "Central America Standard Time",  "Guatemala City",
        "Eastern Standard Time",          "New York City",
        "SA Pacific Standard Time",       "Bogota",
        "Atlantic Standard Time",         "Halifax",
        "Venezuela Standard Time",        "Caracas",
        "Newfoundland Standard Time",     "St. John's",
        "E. South America Standard Time", "Sao Paulo",
        "Argentina Standard Time",        "Buenos Aires",
        "Pacific SA Standard Time",       "Santiago",
        "Montevideo Standard Time",       "Montevideo",
        "West Asia Standard Time",        "Tashkent",
        "Central Asia Standard Time",     "Almaty",
        "Ekaterinburg Standard Time",     "Yekaterinburg",
        "North Asia Standard Time",       "Krasnoyarsk",
        "North Asia East Standard Time",  "Irkutsk",
        "Yakutsk Standard Time",          "Yakutsk",
        "Vladivostok Standard Time",      "Vladivostok")

    static cache := ""

    ;  Le nom du fuseau, tel que Windows le range.
    static Nom() {
        try return RegRead("HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation", "TimeZoneKeyName")
        return ""
    }

    ;  La ville du fuseau, ou "".
    static Ville() {
        n := Fuseau.Nom()
        return Fuseau.VILLES.Has(n) ? Fuseau.VILLES[n] : ""
    }

    ;  Le lieu : { nom, lat, lon }, ou 0. La table des villes n'est lue
    ;  qu'ici, c'est-a-dire seulement si le mode solaire est demande sans
    ;  lieu -- le demarrage ordinaire ne la voit pas.
    static Lieu() {
        if (Fuseau.cache != "")
            return Fuseau.cache
        v := Fuseau.Ville()
        if (v = "")
            return 0
        try {
            r := Villes.Chercher(v, 1)
            if (r.Length && r[1].nom = v) {
                Fuseau.cache := { nom: r[1].nom, lat: r[1].lat, lon: r[1].lon }
                return Fuseau.cache
            }
        }
        return 0
    }
}
