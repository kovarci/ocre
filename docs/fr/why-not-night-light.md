# Pourquoi Ocre n'utilise pas le Night Light de Windows

[← Ocre](../../README.fr.md#documentation) · [English](../en/why-not-night-light.md)

C'était l'intention de départ, et elle a échoué pour une raison qui mérite
d'être documentée, parce qu'elle invalide tous les outils existants sur les
builds récents.

Le Night Light n'a pas d'API. Son réglage est persisté dans deux valeurs
`REG_BINARY` sous `HKEY_CURRENT_USER`, au format **Microsoft Bond
CompactBinary v1** encapsulé dans une enveloppe **CloudStore**. Toute la
littérature communautaire affirme qu'écrire ces valeurs applique le réglage
immédiatement.

**Ce n'est plus vrai depuis Windows 11 25H2 (build 26200).** Mesures faites
sur un Acer Aspire 14 AI, 25H2 build 26200.9168 :

| Observation | Conséquence |
|---|---|
| Le codec de ce dépôt produit **exactement les mêmes octets** que Windows pour une même température | le format est correctement compris |
| Les Paramètres relisent bien la valeur écrite (le curseur suit) | l'écriture aboutit |
| Le rendu à l'écran, lui, ne bouge pas | le moteur ne relit pas le registre |
| « Turn off now » n'écrit **même pas** la clé d'état | l'état vivant n'est plus dans CloudStore |

Ont été essayés sans succès : écriture de la température seule, réécriture de
la clé d'état avec horodatage frais, cycle extinction/rallumage avec des délais
de 120 ms à 2,5 s, et le drapeau « réglage en cours » (champ 70) que
l'interface lève pendant qu'on fait glisser le curseur.

Conclusion : sur ces builds, le registre est un vestige de persistance, relu à
l'ouverture de session et plus jamais ensuite.

Contre-épreuve dans l'autre sens, en allumant puis en éteignant le Night
Light à la main depuis les réglages rapides, en surveillant les clés :

| Clé | Contenu | Écrite |
|---|---|---|
| `Store\...\Cloud\...state` | un horodatage seul, pas d'état | à chaque basculement |
| `Store\...\Current\...state` | « force ON » daté de deux jours plus tôt | touchée au basculement, **contenu inchangé** |
| `Store\...\Current\...settings` | horaire, température | jamais |

Windows note donc *qu'il y a eu* un basculement, pas *lequel*. C'est
pourquoi Ocre ne sait pas voir un Night Light allumé à la main (voir
[le bandeau](settings.md#quand-un-filtre-de-windows-se-cumule)).

Le codec reste dans [`recherche/`](../../recherche/) : il est correct, testé, et
permet toujours de **prérégler** le Night Light pour la prochaine ouverture de
session.
