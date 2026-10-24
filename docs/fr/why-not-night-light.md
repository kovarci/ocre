# Pourquoi Ocre n'utilise pas le Night Light de Windows

[← Ocre](../../README.fr.md#documentation) · [English](../en/why-not-night-light.md)

C'etait l'intention de depart, et elle a echoue pour une raison qui merite
d'etre documentee, parce qu'elle invalide tous les outils existants sur les
builds recents.

Le Night Light n'a pas d'API. Son reglage est persiste dans deux valeurs
`REG_BINARY` sous `HKEY_CURRENT_USER`, au format **Microsoft Bond
CompactBinary v1** encapsule dans une enveloppe **CloudStore**. Toute la
litterature communautaire affirme qu'ecrire ces valeurs applique le reglage
immediatement.

**Ce n'est plus vrai depuis Windows 11 25H2 (build 26200).** Mesures faites
sur un Acer Aspire 14 AI, 25H2 build 26200.9168 :

| Observation | Consequence |
|---|---|
| Le codec de ce depot produit **exactement les memes octets** que Windows pour une meme temperature | le format est correctement compris |
| Les Parametres relisent bien la valeur ecrite (le curseur suit) | l'ecriture aboutit |
| Le rendu a l'ecran, lui, ne bouge pas | le moteur ne relit pas le registre |
| « Turn off now » n'ecrit **meme pas** la cle d'etat | l'etat vivant n'est plus dans CloudStore |

Ont ete essayes sans succes : ecriture de la temperature seule, reecriture de
la cle d'etat avec horodatage frais, cycle extinction/rallumage avec des delais
de 120 ms a 2,5 s, et le drapeau « reglage en cours » (champ 70) que
l'interface leve pendant qu'on fait glisser le curseur.

Conclusion : sur ces builds, le registre est un vestige de persistance, relu a
l'ouverture de session et plus jamais ensuite.

Contre-epreuve dans l'autre sens, en allumant puis en eteignant le Night
Light a la main depuis les reglages rapides, en surveillant les cles :

| Cle | Contenu | Ecrite |
|---|---|---|
| `Store\...\Cloud\...state` | un horodatage seul, pas d'etat | a chaque basculement |
| `Store\...\Current\...state` | « force ON » date de deux jours plus tot | touchee au basculement, **contenu inchange** |
| `Store\...\Current\...settings` | horaire, temperature | jamais |

Windows note donc *qu'il y a eu* un basculement, pas *lequel*. C'est
pourquoi Ocre ne sait pas voir un Night Light allume a la main (voir
[le bandeau](settings.md#quand-un-filtre-de-windows-se-cumule)).

Le codec reste dans [`recherche/`](../../recherche/) : il est correct, teste, et
permet toujours de **preregler** le Night Light pour la prochaine ouverture de
session.
