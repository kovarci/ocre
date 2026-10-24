<#
    install.ps1 -- installation d'Ocre

      1. leve le garde-fou gamma (GdiIcmGammaRange) -- demande l'elevation
      2. construit Ocre.exe s'il manque ou si -Build est demande
      3. cree le raccourci de demarrage automatique
      4. lance l'application

    Ocre.exe est autonome : une fois construit, ni AutoHotkey ni le compilateur
    ne sont necessaires pour s'en servir.

      -Build       force la regeneration de l'icone et la recompilation
      -NoStart     n'ouvre pas l'application a la fin
      -NoStartup   ne cree pas le raccourci de demarrage
      -Uninstall   retire le raccourci et arrete l'application
      -Test        lance les tests (tools\test.ps1) et s'arrete la
      -NoRegistry  ne touche pas au registre (garde-fou gamma, raccourci
                   Win+Ctrl+C des filtres de couleur) : pour construire
                   sans installer, ce que fait tools\release.ps1

    Usage : powershell -ExecutionPolicy Bypass -File .\install.ps1
#>

[CmdletBinding()]
param(
    [switch]$Build,
    [switch]$NoStart,
    [switch]$NoStartup,
    [switch]$Uninstall,
    [switch]$Test,
    [switch]$NoRegistry
)

$ErrorActionPreference = 'Stop'

#------------------------------------------------------------------ tests ----
if ($Test) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tools\test.ps1')
    exit $LASTEXITCODE
}

$Root     = $PSScriptRoot
$Exe      = Join-Path $Root 'Ocre.exe'
$Src      = Join-Path $Root 'Ocre.ahk'
$Ico      = Join-Path $Root 'Ocre.ico'
$Shortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Ocre.lnk'

function Info  ($m) { Write-Host "  $m" }
function Ok    ($m) { Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn2 ($m) { Write-Host "  [!] $m"  -ForegroundColor Yellow }
function Fail  ($m) { Write-Host "  [X] $m"  -ForegroundColor Red }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

#  Un arret PROPRE : "Ocre.exe /quit" demande a l'instance en place de
#  partir, et elle rend la rampe gamma et le retroeclairage en sortant.
#  Stop-Process -Force tue le processus sans lui laisser executer sa
#  sortie : l'ecran restait chaud et le retroeclairage la ou Ocre l'avait
#  mis. On ne s'en sert qu'en dernier recours, si l'instance ne repond plus.
function Stop-Ocre {
    $procs = @(Get-Process Ocre -ErrorAction SilentlyContinue)
    if (-not $procs) { return }
    if (Test-Path $Exe) {
        try { Start-Process $Exe -ArgumentList '/quit' -WindowStyle Hidden -Wait -ErrorAction Stop } catch {}
    }
    foreach ($p in $procs) {
        if (-not $p.WaitForExit(5000)) {
            $p | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Milliseconds 200
}

#--------------------------------------------------------------- desinstall --
if ($Uninstall) {
    Write-Host "`nRetrait d'Ocre" -ForegroundColor Cyan
    if (Test-Path $Shortcut) { Remove-Item $Shortcut -Force; Ok "raccourci de demarrage supprime" }
    else                     { Info "aucun raccourci de demarrage" }
    # Absente, refusee, supprimee : trois cas, et schtasks rend le meme code
    # pour les deux premiers. On regarde avant et apres : une tache que l'on
    # n'a pas pu retirer relancerait Ocre a la prochaine session.
    & schtasks.exe /Query /TN 'Ocre' 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Info "aucune tache planifiee"
    } else {
        & schtasks.exe /Delete /TN 'Ocre' /F 2>&1 | Out-Null
        & schtasks.exe /Query /TN 'Ocre' 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Ok "tache planifiee supprimee" }
        else { Warn2 "la tache planifiee n'a pas pu etre supprimee : relancez ce script en administrateur, sinon Ocre reviendra a la prochaine session" }
    }
    Stop-Ocre
    Ok "application arretee (la rampe gamma revient a neutre)"
    # L'installation avait desactive Win+Ctrl+C, le raccourci des filtres de
    # couleur de Windows (voir plus bas) : on le rend tel que Windows le livre.
    $Cf = 'HKCU:\Software\Microsoft\ColorFiltering'
    if ((Get-ItemProperty $Cf -Name HotkeyEnabled -ErrorAction SilentlyContinue).HotkeyEnabled -eq 0) {
        New-ItemProperty -Path $Cf -Name HotkeyEnabled -Value 1 -PropertyType DWord -Force | Out-Null
        Ok "raccourci Win+Ctrl+C des filtres de couleur de Windows retabli"
    }
    Write-Host "`nLes reglages restent dans %APPDATA%\Ocre, a supprimer a la main si besoin."
    Write-Host "GdiIcmGammaRange est laisse tel quel : d'autres outils s'en servent.`n"
    return
}

Write-Host "`nInstallation d'Ocre" -ForegroundColor Cyan

#------------------------------------------------------- 1. garde-fou gamma --
Write-Host "`n[1/4] Garde-fou gamma"

if ($NoRegistry) {
    Info "ignore (-NoRegistry)"
} else {
$Icm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM'
$Cur = (Get-ItemProperty $Icm -Name GdiIcmGammaRange -ErrorAction SilentlyContinue).GdiIcmGammaRange

if ($Cur -eq 256) {
    Ok "GdiIcmGammaRange deja a 256"
} elseif (Test-Admin) {
    New-Item -Path $Icm -Force | Out-Null
    New-ItemProperty -Path $Icm -Name GdiIcmGammaRange -Value 256 -PropertyType DWord -Force | Out-Null
    Ok "GdiIcmGammaRange pose a 256"
    Warn2 "fermez puis rouvrez votre session pour que ce soit pris en compte"
} else {
    Warn2 "GdiIcmGammaRange vaut '$Cur' au lieu de 256 -- le filtre plafonnera"
    Info  "relancez ce script en administrateur, ou posez la valeur a la main :"
    Info  "  HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM"
    Info  "  GdiIcmGammaRange  (REG_DWORD)  =  256"
    Info  "puis rouvrez votre session."
}

#  Le raccourci Windows des filtres de couleur, Win+Ctrl+C, est actif par
#  defaut. Sur les portables dont le firmware injecte une touche Win dans les
#  combinaisons Fn+F7 -- les Acer, notamment -- la bascule d'Ocre sur Ctrl+F7
#  le declenche en meme temps : le filtre niveaux de gris s'allume, et l'ecran
#  vire au gris des qu'Ocre se coupe. On desactive le raccourci, pas le filtre :
#  qui s'en sert le rallume dans Accessibilite > Filtres de couleur.
#  C'est une cle HKCU : aucune elevation necessaire.
$Cf = 'HKCU:\Software\Microsoft\ColorFiltering'
$Hk = (Get-ItemProperty $Cf -Name HotkeyEnabled -ErrorAction SilentlyContinue).HotkeyEnabled
if ($Hk -eq 0) {
    Ok "raccourci Win+Ctrl+C des filtres de couleur deja desactive"
} else {
    New-Item -Path $Cf -Force | Out-Null
    New-ItemProperty -Path $Cf -Name HotkeyEnabled -Value 0 -PropertyType DWord -Force | Out-Null
    Ok "raccourci Win+Ctrl+C des filtres de couleur desactive (il entrait en collision avec Ctrl+F7)"
}
}

#------------------------------------------------------------ 2. Ocre.exe ----
Write-Host "`n[2/4] Application"

if ((Test-Path $Exe) -and -not $Build) {
    Ok "Ocre.exe present ($([math]::Round((Get-Item $Exe).Length/1MB,2)) Mo)"
} else {
    Info "construction..."

    $AhkCandidates = @(
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey32.exe"
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
    )
    $Ahk = $AhkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $Ahk) {
        Info "AutoHotkey v2 absent, installation via winget..."
        & winget install --id AutoHotkey.AutoHotkey -e --accept-package-agreements --accept-source-agreements --silent | Out-Null
        $Ahk = $AhkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $Ahk) { Fail "AutoHotkey v2 introuvable"; throw "AutoHotkey v2 requis pour construire." }
    Ok "AutoHotkey : $Ahk"

    # Ahk2Exe n'est pas livre avec AutoHotkey : son installeur officiel le
    # telecharge. Un argument quelconque le fait travailler sans poser de question.
    $Compiler = Join-Path (Split-Path (Split-Path $Ahk)) 'Compiler\Ahk2Exe.exe'
    if (-not (Test-Path $Compiler)) {
        $Ux = Join-Path (Split-Path (Split-Path $Ahk)) 'UX\install-ahk2exe.ahk'
        if (Test-Path $Ux) {
            Info "recuperation du compilateur Ahk2Exe..."
            $q = Start-Process $Ahk -ArgumentList "`"$Ux`"","silent" -PassThru
            $q.WaitForExit(180000) | Out-Null
            Get-Process Ahk2Exe -ErrorAction SilentlyContinue | Stop-Process -Force
        }
    }
    if (-not (Test-Path $Compiler)) { Fail "Ahk2Exe introuvable"; throw "Compilateur requis." }
    Ok "compilateur : $Compiler"

    Info "generation de l'icone..."
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tools\make-icon.ps1') | Out-Null
    if (-not (Test-Path $Ico)) { Fail "icone non generee"; throw "Ocre.ico manquant." }
    Ok "Ocre.ico"

    Stop-Ocre
    Remove-Item $Exe -ErrorAction SilentlyContinue
    $r = Start-Process $Compiler -Wait -PassThru -ArgumentList `
        "/in","`"$Src`"","/out","`"$Exe`"","/icon","`"$Ico`"","/base","`"$Ahk`"","/silent","verbose"
    if (-not (Test-Path $Exe)) { Fail "compilation echouee (code $($r.ExitCode))"; throw "Compilation impossible." }
    Ok "Ocre.exe construit ($([math]::Round((Get-Item $Exe).Length/1MB,2)) Mo)"

    # Signature, si un certificat de signature de code est dans le magasin de
    # l'utilisateur (voir tools\sign.ps1). Sans certificat, l'exe reste tel
    # quel : SmartScreen le dira, le README explique pourquoi.
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tools\sign.ps1') -Fichier $Exe
    if ($LASTEXITCODE -eq 2) {
        Info "non signe : SmartScreen avertira au premier lancement (voir docs\fr\installation.md, 'SmartScreen')"
        # 2 veut dire "pas de certificat" : ce n'est pas un echec. Laisse tel
        # quel, il resterait le code de sortie du script, et tout appelant qui
        # le lit -- le workflow GitHub -- y verrait une erreur.
        $global:LASTEXITCODE = 0
    }
}

#------------------------------------------------------- 3. demarrage auto ---
Write-Host "`n[3/4] Demarrage automatique"

if ($NoStartup) {
    Info "ignore (-NoStartup)"
} else {
    # Un raccourci dans le dossier Demarrage est lance par l'explorateur une
    # fois le shell pret, derriere toute la file des autres elements : mesure
    # faite sur un portable charge en services constructeur, 46 secondes apres
    # l'allumage, alors qu'Ocre s'initialise en 0,35 s. Une tache planifiee a
    # l'ouverture de session echappe a cette file.
    $Tache = 'Ocre'

    # Decrite en XML, la tache se cree SANS elevation (verifie) : seul le
    # remplacement d'une tache posee par un administrateur -- celles des
    # versions precedentes -- la demande. On regarde donc d'abord ce qui est
    # en place, pour ne pas ajouter un raccourci a cote d'une tache valide :
    # Ocre se lancerait deux fois.
    # Une tache d'une version precedente, creee par "schtasks /Create /SC
    # ONLOGON", porte les defauts de schtasks : "ne pas demarrer sur
    # batterie" et "arreter si l'on passe sur batterie". Debrancher le
    # chargeur tuait Ocre net, rampe chaude laissee a l'ecran. On la refait.
    $xml = & schtasks.exe /Query /TN $Tache /XML 2>&1 | Out-String
    $existe = ($LASTEXITCODE -eq 0)
    $ok = $existe -and ($xml -match [regex]::Escape($Exe)) `
          -and ($xml -match '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>') `
          -and ($xml -match '<ExecutionTimeLimit>PT0S</ExecutionTimeLimit>')

    if ($ok) {
        Ok "tache planifiee deja en place"
    } else {
        # La tache est decrite en XML : c'est la seule facon de dire a
        # schtasks que la batterie ne compte pas et que la duree est libre.
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $exeXml = [System.Security.SecurityElement]::Escape($Exe)
        $tacheXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Ocre - filtre de lumiere chaude</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$sid</UserId>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$sid</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <StartWhenAvailable>true</StartWhenAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$exeXml</Command>
    </Exec>
  </Actions>
</Task>
"@
        $tmp = Join-Path $env:TEMP 'ocre-tache.xml'
        try {
            [IO.File]::WriteAllText($tmp, $tacheXml, [Text.Encoding]::Unicode)
            & schtasks.exe /Create /TN $Tache /XML "$tmp" /F 2>&1 | Out-Null
            $xml = & schtasks.exe /Query /TN $Tache /XML 2>&1 | Out-String
            $ok = ($LASTEXITCODE -eq 0) -and ($xml -match '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>')
        } catch {
            $ok = $false
        }
        Remove-Item $tmp -ErrorAction SilentlyContinue
        if ($ok) { Ok "tache planifiee a l'ouverture de session -- demarrage immediat, batterie ou pas" }
    }

    if ($ok) {
        # un seul mecanisme a la fois, sinon Ocre se lancerait deux fois
        if (Test-Path $Shortcut) {
            Remove-Item $Shortcut -Force -ErrorAction SilentlyContinue
            Info "raccourci de demarrage retire (la tache le remplace)"
        }
    } elseif ($existe) {
        # Une tache d'avant est la et l'on n'a pas pu la refaire : pas de
        # raccourci en plus, Ocre se lancerait deux fois. Elle marche, avec
        # ses defauts ; on dit comment la refaire.
        Warn2 "une tache planifiee d'une version precedente est en place et n'a pas pu etre refaite"
        Info  "(sur batterie elle ne lance pas Ocre, et l'arrete si l'on debranche :"
        Info  " remplacer une tache posee par un administrateur demande l'elevation --"
        Info  " Win+X, Terminal (administrateur), puis relancez ce script)"
    } else {
        Warn2 "tache planifiee refusee, repli sur le dossier Demarrage"
        Info  "(une strategie d'entreprise peut interdire le planificateur ;"
        Info  " par le dossier Demarrage, le lancement est retarde par la"
        Info  " file d'attente de Windows)"
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut($Shortcut)
        $lnk.TargetPath       = $Exe
        $lnk.WorkingDirectory = $Root
        $lnk.Description      = 'Ocre - filtre de lumiere chaude'
        $lnk.IconLocation     = "$Exe,0"
        $lnk.Save()
        Ok "raccourci cree"
    }
}

#-------------------------------------------------------------- 4. lancement -
Write-Host "`n[4/4] Lancement"

if ($NoStart) {
    Info "ignore (-NoStart)"
} else {
    Stop-Ocre
    # Pas depuis ce processus s'il est eleve : Ocre heriterait du jeton
    # administrateur, et l'UIPI bloquerait ensuite toute commande venue d'un
    # terminal ordinaire -- "Ocre.exe /set 40" ne faisait plus rien, sans un
    # mot. La tache planifiee lance Ocre en tant qu'utilisateur, sans
    # elevation ; a defaut, l'explorateur le fait aussi.
    $lance = $false
    if (Test-Admin) {
        & schtasks.exe /Run /TN 'Ocre' 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $lance = $true }
        else {
            try { Start-Process explorer.exe -ArgumentList "`"$Exe`""; $lance = $true } catch {}
        }
    }
    if (-not $lance) { Start-Process $Exe -WorkingDirectory $Root }
    Ok "Ocre demarre -- l'icone est dans la zone de notification"
}

Write-Host "`nTermine." -ForegroundColor Green
Write-Host @"

  Ctrl+F5   ou  Ctrl+Alt+Retour arriere    filtre moins fort
  Ctrl+F6   ou  Ctrl+Alt+Entree            filtre plus fort
  Ctrl+F7   ou  Ctrl+Alt+Espace            coupe / retablit

  Ctrl+Alt+molette         regle le filtre en continu
  Ctrl+Alt+Maj+molette     regle la luminosite

  Clic gauche sur l'icone : les reglages -- raccourcis, pas, planificateur,
  demarrage automatique. Clic droit : un panneau avec les deux curseurs.

  Si l'ecran reste chaud apres un arret force :   Ocre.exe /reset

  Laissez l'eclairage nocturne de Windows DESACTIVE : les deux filtres
  se cumuleraient.

"@
