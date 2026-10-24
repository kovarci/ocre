; Ocre.iss -- l'installateur d'Ocre (Inno Setup 6).
;
;   Construit par tools\installer.ps1, qui passe la version :
;       ISCC /DAppVersion=1.3.0 installer\Ocre.iss      ->  dist\Ocre-1.3.0-setup.exe
;
;   Il refait ce que fait install.ps1, avec un assistant : Ocre.exe dans Program
;   Files, un raccourci dans le menu Demarrer, GdiIcmGammaRange pose a 256 (une
;   cle HKLM : c'est pour elle que l'installateur demande l'elevation), la
;   tache de demarrage, Win+Ctrl+C desactive, et une entree dans Parametres >
;   Applications pour le retirer.
;
;   RETOUR ARRIERE. Avant de toucher a Windows, l'installateur note ce qu'il va
;   changer -- {app}\sauvegarde\avant-installation.ini, que lit la
;   desinstallation, et avant-installation.reg, la meme chose en .reg : un
;   double-clic suffit a retablir Windows tel qu'il etait, installation en
;   place ou non. Valeur par valeur, jamais cle entiere : un export de cle
;   ecraserait aussi ce que l'utilisateur a change depuis. La desinstallation
;   ne retablit que ce que l'installation a vraiment change, et seulement si la
;   valeur est toujours celle qu'elle a posee.
;
;   L'AppId ne doit JAMAIS changer : c'est lui qui fait d'une version suivante
;   une mise a jour de celle-ci, et non une seconde installation.
;
;   VARIANTE D'ESSAI (ISCC /DESSAI) : meme script, mais tout ce qui touchait au
;   systeme -- HKLM, la vraie tache, le vrai Ocre, le menu Demarrer -- est
;   detourne vers des noms d'essai (HKCU\Software\OcreEssai, la tache
;   OcreEssai...) et l'elevation n'est pas demandee. Elle sert a jouer
;   l'installation, la mise a jour et le retour arriere sur une machine sans
;   rien risquer ; elle ne se publie pas.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef RepoUrl
  #define RepoUrl ""
#endif

#ifdef ESSAI
  #define NomApp "OcreEssai"
  #define AppGuid "{{B0E0E5A1-6B4E-4C57-9D52-0A6D7E4D1F10}"
  #define Privileges "lowest"
  #define RacineGamma "HKCU"
  #define RacineGammaReg "HKEY_CURRENT_USER"
  #define CleGamma "Software\OcreEssai\ICM"
  #define CleCouleurs "Software\OcreEssai\ColorFiltering"
  #define Tache "OcreEssai"
  #define Mutex "Local\OcreEssai"
#else
  #define NomApp "Ocre"
  #define AppGuid "{{4DDF7B9E-D39F-4240-A27B-9E92C4B10488}"
  ; GdiIcmGammaRange est dans HKLM : l'elevation est le prix d'un filtre qui
  ; ne plafonne pas.
  #define Privileges "admin"
  #define RacineGamma "HKLM"
  #define RacineGammaReg "HKEY_LOCAL_MACHINE"
  #define CleGamma "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM"
  #define CleCouleurs "Software\Microsoft\ColorFiltering"
  #define Tache "Ocre"
  #define Mutex "Local\OcreInstance"
#endif

[Setup]
AppId={#AppGuid}
AppName={#NomApp}
AppVersion={#AppVersion}
AppVerName={#NomApp} {#AppVersion}
AppPublisher=Ocre contributors
#if RepoUrl != ""
AppPublisherURL={#RepoUrl}
AppSupportURL={#RepoUrl}/issues
AppUpdatesURL={#RepoUrl}/releases
#endif
VersionInfoVersion={#AppVersion}
VersionInfoProductName=Ocre
VersionInfoDescription=Ocre Setup
VersionInfoCopyright=Ocre contributors
DefaultDirName={autopf}\{#NomApp}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\Ocre.exe
SetupIconFile=..\Ocre.ico
LicenseFile=..\LICENSE
OutputDir=..\dist
OutputBaseFilename={#NomApp}-{#AppVersion}-setup
SetupMutex={#NomApp}SetupMutex
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
; Ocre.exe est un executable 64 bits (AutoHotkey64) ; x64compatible couvre
; aussi Windows sur ARM, qui l'emule.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Les entrees propres a l'utilisateur -- la tache de demarrage -- sont posees
; par utilisateur.ps1 avec son jeton d'origine (runasoriginaluser).
PrivilegesRequired={#Privileges}
; PAS de Restart Manager. Il fermerait Ocre de force pour liberer l'exe, et un
; Ocre tue de force n'a pas rendu la rampe gamma : l'ecran resterait chaud.
; QuitterOcre (plus bas) demande l'arret propre, "Ocre.exe /quit", et attend.
CloseApplications=no
RestartApplications=no

[Languages]
; InfoBeforeFile : la page "Information", avant toute modification -- ce que
; l'installation change dans Windows, dit avant, et non decouvert apres.
Name: "french"; MessagesFile: "compiler:Languages\French.isl"; InfoBeforeFile: "info-fr.txt"
Name: "english"; MessagesFile: "compiler:Default.isl"; InfoBeforeFile: "info-en.txt"

[CustomMessages]
french.Fenetre=Réglages Windows :
french.TacheDemarrage=Lancer Ocre à l'ouverture de session Windows
french.TacheFiltres=Désactiver le raccourci Win+Ctrl+C des filtres de couleur de Windows (il entre en collision avec Ctrl+F7 sur certains portables)
french.IconeReset=Ocre - remettre l'écran à plat
french.IconeRestaurer=Ocre - restaurer les réglages Windows d'origine
french.GammaSession=Le plafond du filtre vient d'être levé (GdiIcmGammaRange) : fermez puis rouvrez votre session Windows pour qu'il soit pris en compte.
french.OcreResiste=Ocre ne s'est pas arrêté. Quittez-le depuis son icône de la zone de notification (clic droit), puis poursuivez.
french.SupprimerReglages=Supprimer aussi vos réglages Ocre (%1) ?
english.Fenetre=Windows settings:
english.TacheDemarrage=Start Ocre when I sign in to Windows
english.TacheFiltres=Turn off Windows' Win+Ctrl+C colour-filter shortcut (it collides with Ctrl+F7 on some laptops)
english.IconeReset=Ocre - reset the screen
english.IconeRestaurer=Ocre - restore the original Windows settings
english.GammaSession=The filter's ceiling has just been lifted (GdiIcmGammaRange): sign out of Windows and back in for it to take effect.
english.OcreResiste=Ocre did not stop. Quit it from its notification-area icon (right-click), then continue.
english.SupprimerReglages=Also delete your Ocre settings (%1)?

[Tasks]
Name: "demarrage"; Description: "{cm:TacheDemarrage}"; GroupDescription: "{cm:Fenetre}"
Name: "filtres"; Description: "{cm:TacheFiltres}"; GroupDescription: "{cm:Fenetre}"
Name: "bureau"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\Ocre.exe"; DestDir: "{app}"; Flags: ignoreversion
; La meme source, pour QuitterOcre : Inno ne la stocke qu'une fois.
Source: "..\Ocre.exe"; Flags: dontcopy
Source: "utilisateur.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.en.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
; L'OFL demande que la licence de la police accompagne l'exe qui l'embarque ;
; la GPL, celle de l'interpreteur AutoHotkey que Ahk2Exe embarque aussi.
Source: "..\lib\Inter-LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\lib\AutoHotkey-LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#NomApp}\Ocre"; Filename: "{app}\Ocre.exe"
Name: "{autoprograms}\{#NomApp}\{cm:IconeReset}"; Filename: "{app}\Ocre.exe"; Parameters: "/reset"; IconFilename: "{app}\Ocre.exe"
; Un .reg ouvert par son raccourci : regedit demande confirmation, puis rend
; Windows tel qu'il etait avant l'installation.
Name: "{autoprograms}\{#NomApp}\{cm:IconeRestaurer}"; Filename: "{app}\sauvegarde\avant-installation.reg"
Name: "{autodesktop}\{#NomApp}"; Filename: "{app}\Ocre.exe"; Tasks: bureau

[Registry]
; Le garde-fou gamma : sans 256, Windows rogne la rampe et le filtre plafonne.
Root: {#RacineGamma}; Subkey: "{#CleGamma}"; ValueType: dword; ValueName: "GdiIcmGammaRange"; ValueData: 256; Check: GammaAPoser
; Win+Ctrl+C, le raccourci des filtres de couleur de Windows, desactive : il
; entre en collision avec Ctrl+F7 sur les portables dont le firmware injecte
; une touche Win dans Fn+F7. C'est le raccourci qu'on coupe, pas le filtre.
Root: HKCU; Subkey: "{#CleCouleurs}"; ValueType: dword; ValueName: "HotkeyEnabled"; ValueData: 0; Tasks: filtres

[Dirs]
; Sauvegarder ecrit dans {app} avant que Setup ne l'ait cree : Setup le trouve
; alors deja la, ne le croit pas de lui et le laisserait, vide, a la
; desinstallation. uninsalwaysuninstall : on le retire s'il est vide, d'ou
; qu'il vienne.
Name: "{app}"; Flags: uninsalwaysuninstall

[UninstallDelete]
; La sauvegarde est faite de fichiers que Setup n'a pas copies : il ne les
; connait pas. Elle a servi (CurUninstallStepChanged) : elle part avec le reste.
Type: filesandordirs; Name: "{app}\sauvegarde"

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\utilisateur.ps1"" -Demarrage -Tache {#Tache} -Exe ""{app}\Ocre.exe"""; Flags: runhidden runasoriginaluser; Tasks: demarrage
; Avec le jeton d'origine, pas le notre : un Ocre eleve ferait taire, par
; l'UIPI, toute commande venue d'un terminal ordinaire ("Ocre.exe /set 40"
; ne ferait plus rien, sans un mot).
Filename: "{app}\Ocre.exe"; Description: "{cm:LaunchProgram,Ocre}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[Code]
const
  MutexOcre = '{#Mutex}';
  TacheOcre = '{#Tache}';
  CleGamma = '{#CleGamma}';
  CleCouleurs = '{#CleCouleurs}';

var
  GammaChange: Boolean;

function RacineGamma: Integer;
begin
  Result := {#RacineGamma};
end;

function DossierSauvegarde: String;
begin
  Result := ExpandConstant('{app}\sauvegarde');
end;

function FichierEtat: String;
begin
  Result := DossierSauvegarde + '\avant-installation.ini';
end;

// Une valeur DWORD en decimal, ou 'absent'.
function LireValeur(Racine: Integer; Cle, Nom: String): String;
var
  V: Cardinal;
begin
  if RegQueryDWordValue(Racine, Cle, Nom, V) then
    Result := IntToStr(V)
  else
    Result := 'absent';
end;

function GammaAPoser: Boolean;
begin
  Result := LireValeur(RacineGamma, CleGamma, 'GdiIcmGammaRange') <> '256';
end;

// ---------------------------------------------------------- sauvegarde ------

// Une ligne de .reg : la valeur telle qu'elle etait, ou sa suppression si elle
// n'existait pas ("nom"=- efface la valeur).
function LigneReg(Nom, Valeur: String): String;
begin
  if Valeur = 'absent' then
    Result := '"' + Nom + '"=-'
  else
    Result := '"' + Nom + '"=dword:' + Format('%.8x', [StrToInt(Valeur)]);
end;

// Le .reg est reecrit depuis l'etat note, et non l'inverse : l'etat est la
// seule source.
procedure EcrireReg;
var
  Ini, Texte: String;
begin
  Ini := FichierEtat;
  Texte := 'Windows Registry Editor Version 5.00' + #13#10 + #13#10 +
    '; Etat de Windows avant l''installation d''Ocre. L''ouvrir (double-clic)' + #13#10 +
    '; retablit les valeurs ci-dessous : une valeur "nom"=- est supprimee.' + #13#10 + #13#10;
  if IniKeyExists('Gamma', 'Avant', Ini) then
    Texte := Texte + '[{#RacineGammaReg}\{#CleGamma}]' + #13#10 +
      LigneReg('GdiIcmGammaRange', GetIniString('Gamma', 'Avant', 'absent', Ini)) + #13#10 + #13#10;
  if IniKeyExists('Couleurs', 'Avant', Ini) then
    Texte := Texte + '[HKEY_CURRENT_USER\{#CleCouleurs}]' + #13#10 +
      LigneReg('HotkeyEnabled', GetIniString('Couleurs', 'Avant', 'absent', Ini)) + #13#10 + #13#10;
  SaveStringToFile(DossierSauvegarde + '\avant-installation.reg', Texte, False);
end;

// Note ce qui va changer, AVANT de le changer. Une fois par valeur : a la mise
// a jour, la valeur a deja ete posee par nous, et la noter de nouveau
// ecraserait l'etat d'origine par le notre.
procedure Sauvegarder;
var
  Ini, Avant: String;
begin
  ForceDirectories(DossierSauvegarde);
  Ini := FichierEtat;
  if not IniKeyExists('Gamma', 'Avant', Ini) then
  begin
    Avant := LireValeur(RacineGamma, CleGamma, 'GdiIcmGammaRange');
    SetIniString('Gamma', 'Avant', Avant, Ini);
    // 'Pose' : l'installation a-t-elle vraiment change quelque chose ? Si la
    // valeur y etait deja, il n'y a rien a rendre.
    if Avant = '256' then
      SetIniString('Gamma', 'Pose', '0', Ini)
    else
      SetIniString('Gamma', 'Pose', '1', Ini);
  end;
  if WizardIsTaskSelected('filtres') and not IniKeyExists('Couleurs', 'Avant', Ini) then
  begin
    Avant := LireValeur(HKCU, CleCouleurs, 'HotkeyEnabled');
    SetIniString('Couleurs', 'Avant', Avant, Ini);
    if Avant = '0' then
      SetIniString('Couleurs', 'Pose', '0', Ini)
    else
      SetIniString('Couleurs', 'Pose', '1', Ini);
  end;
  EcrireReg;
end;

// Rend une valeur a son etat d'origine -- seulement si l'installation l'a
// changee, et seulement si elle vaut encore ce que l'installation y a mis :
// si quelqu'un d'autre l'a modifiee depuis, ce n'est plus a nous d'y toucher.
procedure Retablir(Section: String; Racine: Integer; Cle, Nom: String; Posee: Cardinal);
var
  Ini, Avant: String;
  V: Cardinal;
begin
  Ini := FichierEtat;
  if GetIniString(Section, 'Pose', '0', Ini) <> '1' then Exit;
  if not RegQueryDWordValue(Racine, Cle, Nom, V) then Exit;
  if V <> Posee then Exit;
  Avant := GetIniString(Section, 'Avant', 'absent', Ini);
  if Avant = 'absent' then
    RegDeleteValue(Racine, Cle, Nom)
  else
    RegWriteDWordValue(Racine, Cle, Nom, StrToInt(Avant));
end;

// -------------------------------------------------------------- Ocre --------

// Un arret PROPRE : "Ocre.exe /quit" demande a l'instance en place de partir,
// et elle rend la rampe gamma et le retroeclairage en sortant. Le mutex nomme
// lui appartient tant qu'elle vit : on l'attend, cinq secondes au plus.
procedure QuitterOcre(Dossier: String; Installation: Boolean);
var
  Exe: String;
  Code, I: Integer;
begin
  if not CheckForMutexes(MutexOcre) then Exit;
  Exe := Dossier + '\Ocre.exe';
  // Premiere installation, alors qu'un Ocre tourne d'ailleurs -- le dossier
  // d'un install.ps1, un exe pose sur le bureau : le dossier d'installation
  // est vide, rien pour parler a l'instance. La commande est diffusee a
  // toutes les fenetres, d'ou qu'elle vienne : l'exe de l'installateur fait
  // aussi bien l'affaire.
  if (not FileExists(Exe)) and Installation then
  begin
    ExtractTemporaryFile('Ocre.exe');
    Exe := ExpandConstant('{tmp}\Ocre.exe');
  end;
  if FileExists(Exe) then
    Exec(Exe, '/quit', '', SW_HIDE, ewWaitUntilTerminated, Code);
  for I := 1 to 50 do
  begin
    if not CheckForMutexes(MutexOcre) then Exit;
    Sleep(100);
  end;
  if not WizardSilent then
    MsgBox(CustomMessage('OcreResiste'), mbInformation, MB_OK);
end;

procedure SupprimerDemarrage;
var
  Code: Integer;
begin
  Exec(ExpandConstant('{sys}\schtasks.exe'), '/Delete /TN ' + TacheOcre + ' /F', '', SW_HIDE, ewWaitUntilTerminated, Code);
  DeleteFile(ExpandConstant('{userstartup}\{#NomApp}.lnk'));
end;

// ---------------------------------------------------------- l'assistant ------

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    GammaChange := GammaAPoser;
    QuitterOcre(ExpandConstant('{app}'), True);
    Sauvegarder;
    // Une tache posee par une version precedente, ou par install.ps1 lance en
    // administrateur, ne se remplace pas sans elevation : on la retire d'ici,
    // utilisateur.ps1 la recree ensuite. Un raccourci Demarrage a cote ferait
    // lancer Ocre deux fois.
    if WizardIsTaskSelected('demarrage') then
      SupprimerDemarrage;
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = wpFinished) and GammaChange then
    WizardForm.FinishedLabel.Caption :=
      WizardForm.FinishedLabel.Caption + #13#10#13#10 + CustomMessage('GammaSession');
end;

// Le retrait : arreter Ocre proprement, defaire ce que l'installation a pose,
// et demander avant de toucher aux reglages de l'utilisateur.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Reglages: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    QuitterOcre(ExpandConstant('{app}'), False);
    SupprimerDemarrage;
    Retablir('Couleurs', HKCU, CleCouleurs, 'HotkeyEnabled', 0);
    Retablir('Gamma', RacineGamma, CleGamma, 'GdiIcmGammaRange', 256);
  end;
  if (CurUninstallStep = usPostUninstall) and not UninstallSilent then
  begin
    Reglages := ExpandConstant('{userappdata}\Ocre');
    if DirExists(Reglages) then
      if MsgBox(FmtMessage(CustomMessage('SupprimerReglages'), [Reglages]),
                mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
        DelTree(Reglages, True, True, True);
  end;
end;
