# SMY Root CA installer for Windows.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$FriendlyName = "SMY Root Certification Authority ECC"
$ExpectedThumbprint = "2288F7AC8427C290713FD1E3A369CF01D61332AC"
$CertPem = @'
-----BEGIN CERTIFICATE-----
MIICSDCCAc6gAwIBAgIUM4jeRFYbyv7wkCJ9C+j8hHpGECEwCgYIKoZIzj0EAwMw
WjELMAkGA1UEBhMCQ04xDjAMBgNVBAgMBUh1bmFuMQwwCgYDVQQKDANTTVkxLTAr
BgNVBAMMJFNNWSBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IEVDQzAgFw0y
MzEyMjEwNzUyNDVaGA8yMTIyMTEyNzA3NTI0NVowWjELMAkGA1UEBhMCQ04xDjAM
BgNVBAgMBUh1bmFuMQwwCgYDVQQKDANTTVkxLTArBgNVBAMMJFNNWSBSb290IENl
cnRpZmljYXRpb24gQXV0aG9yaXR5IEVDQzB2MBAGByqGSM49AgEGBSuBBAAiA2IA
BBvH4Xa36MTKrnhBIyyUg/IxykVOwZhzVXzYPswPGOYYE9enmuqmdaN6lhXzduBT
5arxSCULpsrZ8lb/wxO6cEkJCa5E1acfgVRdno6JfdBxZd7WEw8J94mrbqw5mxPr
Q6NTMFEwHQYDVR0OBBYEFD5c06VwJKNCtzLpVCcd6HS8RtrKMB8GA1UdIwQYMBaA
FD5c06VwJKNCtzLpVCcd6HS8RtrKMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0E
AwMDaAAwZQIwWOC+QllECy76guWZNdQSDXO5sSUlo1JBwQVTbwDrtF2ABB7ptjgh
9/ILrkbq7rM5AjEA7pXuwkLz/hZUQM/RtNAsMkzbxqBUOwrxV9LJ0sWF4uQjxMu8
aSsoBsICQmAdfnx+
-----END CERTIFICATE-----
'@

function Test-IsWindows {
    return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function Test-IsAdministrator {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList $identity
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-CertificateBytes {
    $body = $CertPem `
        -replace "-----BEGIN CERTIFICATE-----", "" `
        -replace "-----END CERTIFICATE-----", "" `
        -replace "\s", ""

    return ,([System.Convert]::FromBase64String($body))
}

function ConvertTo-PowerShellSingleQuotedLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return "'" + ($Value -replace "'", "''") + "'"
}

function Get-InstallerSourceUrl {
    $sourceUrl = Get-Variable -Name SmyCaInstallUrl -ValueOnly -ErrorAction SilentlyContinue
    if ($sourceUrl) {
        return [string]$sourceUrl
    }

    if ($env:SMY_CA_INSTALL_URL) {
        return [string]$env:SMY_CA_INSTALL_URL
    }

    return $null
}

if (-not (Test-IsWindows)) {
    throw "This installer only supports Windows."
}

if (-not (Test-IsAdministrator)) {
    $sourceUrl = Get-InstallerSourceUrl
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }

    if ($sourceUrl) {
        Write-Host "Requesting Administrator privileges..."
        $quotedUrl = ConvertTo-PowerShellSingleQuotedLiteral -Value $sourceUrl
        $command = "`$ErrorActionPreference = 'Stop'; irm $quotedUrl | iex"
        $encodedCommand = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
        $argumentList = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList $argumentList -Verb RunAs -Wait -PassThru
        exit $process.ExitCode
    }

    if ($scriptPath) {
        Write-Host "Requesting Administrator privileges..."
        $argumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList $argumentList -Verb RunAs -Wait -PassThru
        exit $process.ExitCode
    }

    throw "This script must be run as Administrator, or launched with: `$SmyCaInstallUrl = '<url>'; irm `$SmyCaInstallUrl | iex"
}

Write-Host "Installing $FriendlyName..."

$certBytes = Get-CertificateBytes
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes)
$actualThumbprint = $cert.Thumbprint.ToUpperInvariant()
if ($actualThumbprint -ne $ExpectedThumbprint) {
    throw "Certificate thumbprint mismatch. Expected $ExpectedThumbprint but got $actualThumbprint."
}

$store = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Store -ArgumentList "Root", "LocalMachine"
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$wasAlreadyInstalled = $false

try {
    $existing = $store.Certificates.Find(
        [System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,
        $ExpectedThumbprint,
        $false
    )

    if ($existing.Count -gt 0) {
        $wasAlreadyInstalled = $true
    }
    else {
        $cert.FriendlyName = $FriendlyName
        $store.Add($cert)
    }
}
finally {
    $store.Close()
}

$installed = Get-ChildItem -Path Cert:\LocalMachine\Root |
    Where-Object { $_.Thumbprint -eq $ExpectedThumbprint } |
    Select-Object -First 1

if (-not $installed) {
    throw "Failed to verify the installed certificate in LocalMachine\Root."
}

$installed.FriendlyName = $FriendlyName
if ($wasAlreadyInstalled) {
    Write-Host "$FriendlyName is already installed. FriendlyName has been updated."
}
else {
    Write-Host "$FriendlyName has been installed."
}
