<p align="center">
  <img src="tools/apercu-logo.png" width="520" alt="Le logo d'Ocre à cinq intensités, du clair à l'ocre profond">
</p>

<h1 align="center">Ocre</h1>

<p align="center"><strong>Un filtre de lumière chaude pour Windows 11, piloté au clavier.</strong></p>

<p align="center">
  <a href="https://github.com/kovarci/ocre/releases/latest"><img src="https://img.shields.io/github/v/release/kovarci/ocre?color=d6823a&label=version" alt="Dernière version"></a>
  <a href="https://github.com/kovarci/ocre/actions/workflows/ci.yml"><img src="https://github.com/kovarci/ocre/actions/workflows/ci.yml/badge.svg" alt="État de la CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-blue" alt="Licence MIT"></a>
  <img src="https://img.shields.io/badge/Windows-11-0078d4" alt="Windows 11">
  <img src="https://img.shields.io/badge/AutoHotkey-v2-3a7d44" alt="Écrit en AutoHotkey v2">
</p>

<p align="center">
  <a href="https://github.com/kovarci/ocre/releases/latest"><strong>Télécharger</strong></a> ·
  <a href="docs/fr/usage.md">Documentation</a> ·
  <a href="README.md">English</a>
</p>

<p align="center">
  <img src="docs/img/fr/panneau.png" height="360" alt="Le panneau du clic droit : curseurs d'intensité et de luminosité, trois préréglages">
  <img src="docs/img/fr/reglages.png" height="360" alt="La fenêtre des réglages">
  <img src="docs/img/fr/planificateur-soleil.png" height="260" alt="Le planificateur, qui suit le soleil">
</p>

Ocre réchauffe la couleur de vos écrans le soir, pour qu'ils cessent de vous éblouir à
minuit. On le pilote au clavier, à la molette, depuis un petit panneau ou en ligne de
commande, et il se programme tout seul si vous le laissez faire.

## Ce qu'il fait

- **Réchauffe la couleur de chaque écran** par une rampe gamma : instantané, écran par
  écran, sans service ni pilote. L'intensité s'exprime en **pourcents ou en Kelvin**
  (1200–6500 K).
- **Se pilote là où sont vos mains** : `Ctrl+F5` / `F6` / `F7` (et un jeu sans touche de
  fonction, pour les portables qui les captent), `Ctrl+Alt` + **molette**, l'icône de la
  zone de notification, un panneau, ou [la ligne de commande](docs/fr/command-line.md) pour
  un boîtier à boutons ou une macro.
- **Se programme** : heures fixes, ou selon le soleil de votre ville — d'après une table
  intégrée de 26 700 villes, rien n'est envoyé sur le réseau — avec des fondus aussi longs
  que vous le voulez.
- **Règle aussi la luminosité** : le vrai rétroéclairage des écrans externes (DDC/CI) et
  des dalles de portable, et la rampe en dessous du plancher matériel.
- **Gère les cas difficiles** : plusieurs écrans aux réglages propres, **HDR**,
  **noir OLED**, niveaux de gris, et un mode **chambre noire** (rouge seul).
- **Sait se faire oublier** : peut assombrir l'écran qu'on ne regarde plus, baisser la
  luminosité sur batterie, suivre le contenu de l'écran, apprendre vos habitudes, et
  rappeler la règle des 20-20-20. Tout est facultatif.
- **Privé par construction** : aucune connexion réseau, aucun compte, aucune télémétrie.
  Les réglages tiennent dans un simple `ocre.ini`.
- Interface en **français et en anglais**.

Il n'utilise pas l'éclairage nocturne de Windows : sur les versions récentes de Windows 11,
son réglage ne se commande plus de l'extérieur.
[Voici l'enquête](docs/fr/why-not-night-light.md).

## Installation

### L'installateur (recommandé)

Téléchargez **`Ocre-<version>-setup.exe`** depuis la
[dernière version](https://github.com/kovarci/ocre/releases/latest) et lancez-le. Ocre
s'installe comme n'importe quelle application : menu Démarrer, une entrée dans
*Paramètres > Applications*, et, au choix, le lancement à l'ouverture de session.

Il demande les droits d'administrateur **une seule fois**, pour lever l'écrêtage des
rampes gamma que Windows applique par défaut (une valeur de registre,
`GdiIcmGammaRange`). Avant de toucher à quoi que ce soit, il note l'état d'origine dans
`C:\Program Files\Ocre\sauvegarde\`, et la désinstallation rend exactement ce qu'il a
changé — détails dans [Installation](docs/fr/installation.md).

> **SmartScreen.** Les fichiers ne sont pas encore signés : Windows peut afficher
> *« Windows a protégé votre ordinateur »* au premier lancement. Cliquez sur
> **Informations complémentaires**, puis **Exécuter quand même**. Voir
> [SmartScreen](docs/fr/installation.md#smartscreen) et la
> [politique de signature](#politique-de-signature-code-signing-policy).

### Autres façons

- **`Ocre-<version>.zip`**, portable, sur la même page : `Ocre.exe` et `install.ps1`.
- Depuis les sources : installez [AutoHotkey v2](https://www.autohotkey.com/), clonez le
  dépôt, lancez `Ocre.ahk`. Voir [Développement](docs/fr/development.md).

## Prise en main

Ocre démarre à 0 % : rien ne se passe tant qu'on ne demande rien. Appuyez plusieurs fois
sur **`Ctrl+F6`**.

| | Jeu principal | Jeu de secours |
|---|---|---|
| filtre moins fort | `Ctrl+F5` | `Ctrl+Alt+Retour arrière` |
| filtre plus fort | `Ctrl+F6` | `Ctrl+Alt+Entrée` |
| coupe / rétablit | `Ctrl+F7` | `Ctrl+Alt+Espace` |

Les deux jeux sont actifs en même temps et entièrement reconfigurables. Le principal
demande que le verrouillage Fn du portable soit en mode *touches de fonction* ; le jeu de
secours marche partout.

| Geste | Effet |
|---|---|
| `Ctrl+Alt` + molette | règle le filtre en continu |
| `Ctrl+Alt+Maj` + molette | règle la luminosité |
| Molette sur l'icône | règle le filtre |
| Clic gauche sur l'icône | les réglages |
| Clic droit sur l'icône | le panneau : les deux curseurs et trois préréglages |
| Clic milieu sur l'icône | coupe / rétablit le filtre |

Plus de détails dans [Utiliser Ocre](docs/fr/usage.md).

## Ligne de commande

```
Ocre.exe /set 40          # intensité, 0-100  (/set +5, /set -5 : relatif)
Ocre.exe /kelvin 3400     # température de couleur
Ocre.exe /preset nuit     # lecture, film, nuit
Ocre.exe /get             # état courant
Ocre.exe /reset           # rampe neutre, puis arrêt
```

La liste complète, avec les codes de retour, est dans
[Ligne de commande](docs/fr/command-line.md).

## En cas de problème

- **L'écran reste chaud** après un arrêt brutal : lancez `Ocre.exe /reset` (le menu
  Démarrer en propose un raccourci).
- **Les raccourcis ne répondent pas**, ou l'écran vire au gris quand Ocre se coupe :
  [Dépannage](docs/fr/troubleshooting.md).
- **Un bogue** : ouvrez *Réglages > À propos > Copier le diagnostic* (ou lancez
  `Ocre.exe /diag`) et collez le résultat dans un
  [nouveau ticket](https://github.com/kovarci/ocre/issues/new/choose). Il contient la
  version, la build de Windows et les écrans — aucune donnée personnelle.

## Documentation

| | |
|---|---|
| [Utiliser Ocre](docs/fr/usage.md) | raccourcis, molette, clics, Kelvin |
| [Réglages](docs/fr/settings.md) | chaque réglage, et pourquoi il existe |
| [Le planificateur](docs/fr/scheduler.md) | heures fixes, suivre le soleil, où vous êtes |
| [L'interface](docs/fr/interface.md) | l'icône, le panneau, les fenêtres, le logo |
| [Ligne de commande](docs/fr/command-line.md) | chaque commande et chaque code de retour |
| [Comment ça marche](docs/fr/how-it-works.md) | la rampe, chaque écran, la luminosité, le HDR, la chambre noire |
| [Pourquoi pas le Night Light](docs/fr/why-not-night-light.md) | l'enquête qui l'a écarté |
| [Installation](docs/fr/installation.md) | l'installateur, le retour arrière, la tâche de démarrage |
| [Dépannage](docs/fr/troubleshooting.md) | filtre bloqué, touches de fonction, écran gris |
| [Développement](docs/fr/development.md) | construire, tester, arborescence |

## Vie privée et sécurité

Ocre n'ouvre **aucune connexion réseau** : son code n'émet aucun appel réseau, et rien
n'est collecté ni envoyé. Il tourne sous votre utilisateur ordinaire ; seul l'installateur
s'exécute avec élévation. Pour signaler une faille, voir [SECURITY.md](SECURITY.md).

## Politique de signature (Code signing policy)

> **État :** la demande de signature de code gratuite auprès de la SignPath
> Foundation est en cours. Tant qu'elle n'est pas acceptée, les fichiers
> publiés — la 1.3.0 comprise — **ne sont pas signés**. Cette ligne disparaîtra
> à l'acceptation.

Free code signing provided by [SignPath.io](https://signpath.io), certificate
by [SignPath Foundation](https://signpath.org).

**Ce qui est signé.** `Ocre.exe` (aussi présent dans l'archive `.zip`) et
`Ocre-<version>-setup.exe`. L'archive `.zip` elle-même n'est pas un fichier
signable.

**D'où ça sort.** Uniquement de
[`.github/workflows/release.yml`](.github/workflows/release.yml), exécuté par
GitHub Actions à partir d'un tag de ce dépôt, avec des outils de construction
épinglés à une version et à une empreinte
([`tools/outils-ci.ps1`](tools/outils-ci.ps1)). Rien n'est signé depuis un
poste local. Chaque version publiée par ce workflow joint aussi
`SHA256SUMS.txt`.

**Qui décide.**

| Rôle | Qui |
|---|---|
| Auteurs (modifient le code sans relecture supplémentaire) | [@kovarci](https://github.com/kovarci) |
| Relecteurs (relisent les contributions de tiers) | [@kovarci](https://github.com/kovarci) |
| Approbateurs (décident si une version peut être signée ; chaque demande de signature est approuvée à la main) | [@kovarci](https://github.com/kovarci) |

**Confidentialité.** Ocre ne transmet aucune information à un autre système
en réseau : son code n'ouvre aucune connexion. La table des villes (GeoNames)
et la police (Inter) sont embarquées dans l'exécutable ; les seuls fichiers
qu'Ocre écrit sont vos réglages, dans `%APPDATA%\Ocre`. L'installateur
n'ouvre pas de connexion non plus. Aucun service tiers n'intervient, donc
aucune politique de confidentialité tierce ne s'applique.

**Vérifier une signature.** Propriétés du fichier > *Signatures numériques*,
ou :

```powershell
Get-AuthenticodeSignature .\Ocre-1.3.0-setup.exe | Format-List
```

## Contribuer

Les signalements, correctifs, traductions et tests sont les bienvenus — en français ou en
anglais. Commencez par [CONTRIBUTING.md](CONTRIBUTING.md) (en anglais) et respectez le
[Code de conduite](CODE_OF_CONDUCT.md) (en anglais). L'historique des changements est dans
[CHANGELOG.md](CHANGELOG.md).

## Crédits

Le format binaire du Night Light a été documenté par deux dépôts, sans lesquels l'enquête
de [Pourquoi pas le Night Light](docs/fr/why-not-night-light.md) aurait été impossible :

- [**kvnxiao/win-nightlight-cli**](https://github.com/kvnxiao/win-nightlight-cli) —
  [structure du registre](https://github.com/kvnxiao/win-nightlight-cli/blob/main/docs/nightlight-registry-format.md)
  et [wire format Bond CompactBinary v1](https://github.com/kvnxiao/win-nightlight-cli/blob/main/docs/bond-compact-binary-v1.md)
- [**Enyium/sem-reg-rs**](https://github.com/Enyium/sem-reg-rs) —
  [documentation complémentaire](https://github.com/Enyium/sem-reg-rs/blob/master/src/cloud_store/night_light/docs.md),
  seule à documenter le drapeau « réglage en cours » et la règle d'horodatage
  croissant

Voir aussi [elModo7/WindowsNightLight_CLI](https://github.com/elModo7/WindowsNightLight_CLI)
et [Fleex's Lab sur CloudStore](https://fleexlab.blogspot.com/2017/05/the-windows-cloudstore.html).

Trois éléments embarqués dans l'exécutable viennent d'ailleurs :

- la table des villes (`lib/villes.txt`) est extraite de
  [**GeoNames**](https://www.geonames.org/), sous licence
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) ;
- la police de la pastille est [**Inter**](https://rsms.me/inter/) de Rasmus Andersson,
  sous [SIL Open Font License 1.1](lib/Inter-LICENSE.txt) ;
- l'interpréteur [**AutoHotkey v2**](https://www.autohotkey.com/), que le compilateur
  Ahk2Exe place dans `Ocre.exe` pour que le script s'exécute seul, sous
  [GNU GPL v2](lib/AutoHotkey-LICENSE.txt). Son code source est sur
  [github.com/AutoHotkey/AutoHotkey](https://github.com/AutoHotkey/AutoHotkey) ; la
  version embarquée dans une build est celle que `Ocre.exe /diag` écrit sur sa ligne
  *AutoHotkey*, et les builds officielles utilisent celle qu'épingle, avec son empreinte,
  [`tools/outils-ci.ps1`](tools/outils-ci.ps1). Le script d'Ocre, lui, reste sous licence
  MIT, compatible avec la GPL.

## Licence

MIT — voir [LICENSE](LICENSE).
