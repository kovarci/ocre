<#
    sign.ps1 -- signe Ocre.exe (Authenticode, SHA-256, horodate).

    Un executable AutoHotkey compile et non signe declenche l'ecran bleu
    "Windows a protege votre ordinateur" chez tout le monde sauf son auteur,
    et certains antivirus le mettent en quarantaine. Une signature avec un
    certificat de signature de code reconnu regle le second point tout de
    suite, et le premier avec le temps (SmartScreen accorde sa confiance a
    la reputation du certificat).

    Le certificat, lui, ne se fabrique pas ici :

      - SignPath Foundation (signpath.org) signe gratuitement les projets
        open source, depuis leur depot GitHub et leur CI ;
      - Azure Trusted Signing (Microsoft) : quelques euros par mois, apres
        verification d'identite ;
      - un certificat OV classique chez une autorite (Sectigo, DigiCert...),
        de l'ordre de 200 euros par an, livre sur cle materielle.

    Ce script prend ce qu'il trouve : un certificat de signature de code
    dans le magasin de l'utilisateur (le premier, ou celui de -Thumbprint),
    ou un fichier PFX (-Pfx, avec -Password). -SelfSigned en fabrique un de
    test, qui ne convainc ni SmartScreen ni personne, mais permet de verifier
    que la chaine fonctionne.

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\sign.ps1
            .\tools\sign.ps1 -Thumbprint ABCD...
            .\tools\sign.ps1 -Pfx .\ocre.pfx -Password (Read-Host -AsSecureString)
            .\tools\sign.ps1 -SelfSigned
#>

[CmdletBinding()]
param(
    [string]$Fichier = (Join-Path (Split-Path $PSScriptRoot) 'Ocre.exe'),
    [string]$Thumbprint,
    [string]$Pfx,
    [SecureString]$Password,
    [switch]$SelfSigned,
    [string]$Horodatage = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Fichier)) { Write-Host "  [X] $Fichier introuvable" -ForegroundColor Red; exit 1 }

#--------------------------------------------------------------- signtool --
$SignTool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\x64\\' } | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $SignTool) {
    Write-Host "  [X] signtool.exe introuvable : installez le Windows SDK (composant 'Windows SDK Signing Tools')." -ForegroundColor Red
    exit 1
}

#------------------------------------------------------------- certificat --
$Cert = $null
if ($SelfSigned) {
    $Cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=Ocre (essai, non reconnu)' `
        -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(1)
    Write-Host "  [!] certificat auto-signe cree : il ne convainc ni SmartScreen ni les antivirus." -ForegroundColor Yellow
} elseif ($Pfx) {
    if (-not $Password) { $Password = Read-Host -AsSecureString "Mot de passe du PFX" }
    # Importe dans le magasin de l'utilisateur pour signer par empreinte : le
    # mot de passe ne passe ainsi jamais sur la ligne de commande de signtool,
    # ou n'importe quel processus pourrait le lire.
    $Cert = Import-PfxCertificate -FilePath $Pfx -CertStoreLocation Cert:\CurrentUser\My -Password $Password
} elseif ($Thumbprint) {
    $Cert = Get-Item "Cert:\CurrentUser\My\$Thumbprint"
} else {
    $Cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.NotAfter -gt (Get-Date) } | Select-Object -First 1
}
if (-not $Cert) {
    Write-Host "  [!] aucun certificat de signature de code : $(Split-Path $Fichier -Leaf) reste non signe." -ForegroundColor Yellow
    Write-Host "      (voir l'en-tete de ce script pour en obtenir un)"
    exit 2
}
Write-Host "  certificat : $($Cert.Subject)  (expire le $($Cert.NotAfter.ToString('yyyy-MM-dd')))"

#------------------------------------------------------------------ signer --
$Arguments = @('sign', '/fd', 'SHA256', '/td', 'SHA256', '/tr', $Horodatage, '/sha1', $Cert.Thumbprint, $Fichier)

& $SignTool @Arguments | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "  [X] signtool a echoue (code $LASTEXITCODE)" -ForegroundColor Red; exit 1 }

$sig = Get-AuthenticodeSignature $Fichier
Write-Host "  [ok] $((Split-Path $Fichier -Leaf)) signe : $($sig.Status)" -ForegroundColor Green
exit 0
