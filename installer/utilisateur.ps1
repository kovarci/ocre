<#
    utilisateur.ps1 -- ce que l'installateur pose DANS LE COMPTE de l'utilisateur.

    L'installateur s'execute eleve (il ecrit dans Program Files et dans HKLM).
    Ce qui appartient a l'utilisateur -- sa tache de demarrage, ses filtres de
    couleur -- ne doit pas etre ecrit par le jeton eleve : si un autre compte a
    donne l'autorisation, ce serait son profil et son nom qui s'y retrouveraient.
    Inno Setup lance donc ce script avec le drapeau runasoriginaluser, qui
    rend le jeton de celui qui a double-clique.

      -Demarrage        tache planifiee a l'ouverture de session. Meme tache que
                        celle de Demarrage.CreerTache (lib\Config.ahk) : sans
                        elevation, et que la batterie n'interrompt ni ne retarde.
      -FiltresCouleur   desactive Win+Ctrl+C, le raccourci des filtres de couleur
                        de Windows, qui entre en collision avec Ctrl+F7 sur
                        certains portables (voir install.ps1).
#>

[CmdletBinding()]
param(
    [string]$Exe,
    [switch]$Demarrage,
    [switch]$FiltresCouleur
)

$ErrorActionPreference = 'Stop'

if ($Demarrage) {
    $service = New-Object -ComObject Schedule.Service
    $service.Connect()
    $def = $service.NewTask(0)
    $def.RegistrationInfo.Description = 'Ocre - filtre de lumiere chaude'

    $s = $def.Settings
    $s.DisallowStartIfOnBatteries = $false
    $s.StopIfGoingOnBatteries     = $false
    $s.ExecutionTimeLimit         = 'PT0S'          # jamais arrete pour duree
    $s.MultipleInstancesPolicy    = 2               # TASK_INSTANCES_IGNORE_NEW
    $s.StartWhenAvailable         = $true
    $s.IdleSettings.StopOnIdleEnd = $false

    $trig = $def.Triggers.Create(9)                 # TASK_TRIGGER_LOGON
    $trig.UserId = "$env:USERDOMAIN\$env:USERNAME"

    $act = $def.Actions.Create(0)                   # TASK_ACTION_EXEC
    $act.Path = $Exe

    $def.Principal.LogonType = 3                    # TASK_LOGON_INTERACTIVE_TOKEN
    $def.Principal.RunLevel  = 0                    # TASK_RUNLEVEL_LUA : sans elevation

    # TASK_CREATE_OR_UPDATE, TASK_LOGON_INTERACTIVE_TOKEN
    $service.GetFolder('\').RegisterTaskDefinition('Ocre', $def, 6, $null, $null, 3) | Out-Null
}

if ($FiltresCouleur) {
    $Cf = 'HKCU:\Software\Microsoft\ColorFiltering'
    New-Item -Path $Cf -Force | Out-Null
    New-ItemProperty -Path $Cf -Name HotkeyEnabled -Value 0 -PropertyType DWord -Force | Out-Null
}
