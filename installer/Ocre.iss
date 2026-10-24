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
;   L'AppId ne doit JAMAIS changer : c'est lui qui fait d'une version suivante
;   une mise a jour de celle-ci, et non une seconde installation.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef RepoUrl
  #define RepoUrl ""
#endif

[Setup]
AppId={{4DDF7B9E-D39F-4240-A27B-9E92C4B10488}
AppName=Ocre
AppVersion={#AppVersion}
AppVerName=Ocre {#AppVersion}
AppPublisher=Ocre contributors
#if RepoUrl != ""
AppPublisherURL={#RepoUrl}
AppSupportURL={#RepoUrl}/issues
AppUpdatesURL={#RepoUrl}/releases
#endif
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\Ocre
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\Ocre.exe
SetupIconFile=..\Ocre.ico
LicenseFile=..\LICENSE
OutputDir=..\dist
OutputBaseFilename=Ocre-{#AppVersion}-setup
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
; Ocre.exe est un executable 64 bits (AutoHotkey64) ; x64compatible couvre
; aussi Windows sur ARM, qui l'emule.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; GdiIcmGammaRange est dans HKLM : l'elevation est le prix d'un filtre qui ne
; plafonne pas. Les entrees propres a l'utilisateur sont posees par
; utilisateur.ps1 avec son jeton d'origine (runasoriginaluser).
PrivilegesRequired=admin
; PAS de Restart Manager. Il fermerait Ocre de force pour liberer l'exe, et un
; Ocre tue de force n'a pas rendu la rampe gamma : l'ecran resterait chaud.
; QuitterOcre (plus bas) demande l'arret propre, "Ocre.exe /quit", et attend.
CloseApplications=no
RestartApplications=no

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
french.Fenetre=Réglages Windows :
french.TacheDemarrage=Lancer Ocre à l'ouverture de session Windows
french.TacheFiltres=Désactiver le raccourci Win+Ctrl+C des filtres de couleur de Windows (il entre en collision avec Ctrl+F7 sur certains portables)
french.IconeReset=Ocre - remettre l'écran à plat
french.GammaSession=Le plafond du filtre vient d'être levé (GdiIcmGammaRange) : fermez puis rouvrez votre session Windows pour qu'il soit pris en compte.
french.OcreResiste=Ocre ne s'est pas arrêté. Quittez-le depuis son icône de la zone de notification (clic droit), puis poursuivez.
french.SupprimerReglages=Supprimer aussi vos réglages Ocre (%1) ?
english.Fenetre=Windows settings:
english.TacheDemarrage=Start Ocre when I sign in to Windows
english.TacheFiltres=Turn off Windows' Win+Ctrl+C colour-filter shortcut (it collides with Ctrl+F7 on some laptops)
english.IconeReset=Ocre - reset the screen
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
; L'OFL demande que la licence de la police accompagne l'exe qui l'embarque.
Source: "..\lib\Inter-LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Ocre\Ocre"; Filename: "{app}\Ocre.exe"
Name: "{autoprograms}\Ocre\{cm:IconeReset}"; Filename: "{app}\Ocre.exe"; Parameters: "/reset"; IconFilename: "{app}\Ocre.exe"
Name: "{autodesktop}\Ocre"; Filename: "{app}\Ocre.exe"; Tasks: bureau

[Registry]
; Le garde-fou gamma : sans 256, Windows rogne la rampe et le filtre plafonne.
; Laisse en place a la desinstallation (aucun drapeau uninsdelete*), comme le
; fait install.ps1 -Uninstall : d'autres outils s'en servent.
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM"; ValueType: dword; ValueName: "GdiIcmGammaRange"; ValueData: 256; Check: GammaAPoser

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\utilisateur.ps1"" -Exe ""{app}\Ocre.exe"" -Demarrage"; Flags: runhidden runasoriginaluser; Tasks: demarrage
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\utilisateur.ps1"" -FiltresCouleur"; Flags: runhidden runasoriginaluser; Tasks: filtres
; Avec le jeton d'origine, pas le notre : un Ocre eleve ferait taire, par
; l'UIPI, toute commande venue d'un terminal ordinaire ("Ocre.exe /set 40"
; ne ferait plus rien, sans un mot).
Filename: "{app}\Ocre.exe"; Description: "{cm:LaunchProgram,Ocre}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[Code]
const
  MutexOcre = 'Local\OcreInstance';
  Icm = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM';
  FiltresCouleurCle = 'Software\Microsoft\ColorFiltering';

var
  GammaChange: Boolean;

function GammaAPoser: Boolean;
var
  Valeur: Cardinal;
begin
  Result := not (RegQueryDWordValue(HKLM, Icm, 'GdiIcmGammaRange', Valeur) and (Valeur = 256));
end;

{ Un arret PROPRE : "Ocre.exe /quit" demande a l'instance en place de partir,
  et elle rend la rampe gamma et le retroeclairage en sortant. Le mutex nomme
  lui appartient tant qu'elle vit : on l'attend, cinq secondes au plus. }
procedure QuitterOcre(Dossier: String; Installation: Boolean);
var
  Exe: String;
  Code, I: Integer;
begin
  if not CheckForMutexes(MutexOcre) then Exit;
  Exe := Dossier + '\Ocre.exe';
  { Premiere installation, alors qu'un Ocre tourne d'ailleurs -- le dossier
    d'un install.ps1, un exe pose sur le bureau : le dossier d'installation
    est vide, rien pour parler a l'instance. La commande est diffusee a
    toutes les fenetres, d'ou qu'elle vienne : l'exe de l'installateur fait
    aussi bien l'affaire. }
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

procedure CurStepChanged(CurStep: TSetupStep);
var
  I: Integer;
begin
  if CurStep = ssInstall then
  begin
    GammaChange := GammaAPoser;
    QuitterOcre(ExpandConstant('{app}'), True);
    { Une tache posee par une version precedente, ou par install.ps1 lance en
      administrateur, ne se remplace pas sans elevation : on la retire d'ici,
      utilisateur.ps1 la recree ensuite. Un raccourci Demarrage a cote ferait
      lancer Ocre deux fois. }
    if WizardIsTaskSelected('demarrage') then
    begin
      Exec(ExpandConstant('{sys}\schtasks.exe'), '/Delete /TN Ocre /F', '', SW_HIDE, ewWaitUntilTerminated, I);
      DeleteFile(ExpandConstant('{userstartup}\Ocre.lnk'));
    end;
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = wpFinished) and GammaChange then
    WizardForm.FinishedLabel.Caption :=
      WizardForm.FinishedLabel.Caption + #13#10#13#10 + CustomMessage('GammaSession');
end;

{ Le retrait : arreter Ocre proprement, defaire ce que l'installation a pose
  chez l'utilisateur, et demander avant de toucher a ses reglages. }
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Code: Integer;
  Valeur: Cardinal;
  Reglages: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    QuitterOcre(ExpandConstant('{app}'), False);
    Exec(ExpandConstant('{sys}\schtasks.exe'), '/Delete /TN Ocre /F', '', SW_HIDE, ewWaitUntilTerminated, Code);
    DeleteFile(ExpandConstant('{userstartup}\Ocre.lnk'));
    { Win+Ctrl+C rendu tel que Windows le livre. }
    if RegQueryDWordValue(HKCU, FiltresCouleurCle, 'HotkeyEnabled', Valeur) and (Valeur = 0) then
      RegWriteDWordValue(HKCU, FiltresCouleurCle, 'HotkeyEnabled', 1);
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
