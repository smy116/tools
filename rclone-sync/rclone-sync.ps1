#requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#===============================================================================
# Description: Sync data with rclone and send NotifyMux notifications on failure.
# Author: SMY
#===============================================================================

# --- Configuration ---
$ScriptDir = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = (Get-Location).Path
}

# Job name used for logs and notifications.
$JobName = "Sync-Minio-To-E5"

# rclone executable path.
# Defaults to the rclone executable in the script directory.
$RclonePath = Join-Path $ScriptDir "rclone"

# rclone config file path.
$ConfigFile = Join-Path $ScriptDir "rclone.conf"

# Source directory, either an rclone remote or a local path.
# Examples: "minio_remote:bucket_name/path/" or "D:\data\"
$SourceDir = "minio:"

# Destination directory, either an rclone remote or a local path.
$DestDir = "E5-MinioBackup-Crypt:"

# Exclude list, using comma-separated rclone patterns.
# Example: "Public/**,*.tmp,cache/"
# Leave empty to disable excludes.
$ExcludeList = ""
# $ExcludeList = "Public/**,*.log,temp_files/"

# Log directory.
$LogDir = Join-Path $ScriptDir "logs"
$NotifyMuxApiKey = "<YOUR NOTIFYMUX API KEY HERE>"
$NotifyMuxEndpoint = "https://push.smy.me/send"

# --- Global values ---
# Use one log file per month.
$TimestampMonth = Get-Date -Format "yyyyMM"
$LogFile = Join-Path $LogDir "${JobName}_${TimestampMonth}.log"
$script:RcloneOptions = @()
$script:ResolvedRclonePath = $null

# --- Functions ---

function Get-Timestamp {
    Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Write-LogMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Add-Content -LiteralPath $LogFile -Encoding UTF8 -Value ("[{0}] [{1}] {2}" -f (Get-Timestamp), $Level, $Message)
}

function Write-CriticalStderr {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    [Console]::Error.WriteLine("[{0}] [CRITICAL] {1}" -f (Get-Timestamp), $Message)
}

function Ensure-LogDir {
    if (Test-Path -LiteralPath $LogDir -PathType Container) {
        return $true
    }

    try {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Write-LogMessage -Level "INFO" -Message "Log directory was created: $LogDir"
        return $true
    } catch {
        Write-CriticalStderr -Message "Unable to create log directory: $LogDir. Check permissions. $($_.Exception.Message)"
        return $false
    }
}

function Resolve-RclonePath {
    if ([string]::IsNullOrWhiteSpace($RclonePath)) {
        return $null
    }

    $looksLikePath = $RclonePath.Contains("\") -or $RclonePath.Contains("/") -or [System.IO.Path]::IsPathRooted($RclonePath)
    if ($looksLikePath) {
        if (Test-Path -LiteralPath $RclonePath -PathType Leaf) {
            return $RclonePath
        }

        $windowsExecutablePath = "$RclonePath.exe"
        if (Test-Path -LiteralPath $windowsExecutablePath -PathType Leaf) {
            return $windowsExecutablePath
        }

        return $null
    }

    $command = Get-Command $RclonePath -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return $null
    }

    return $command.Source
}

function Test-NotifyMuxConfigured {
    if ([string]::IsNullOrWhiteSpace($NotifyMuxApiKey)) {
        return $false
    }

    return -not $NotifyMuxApiKey.Contains("<YOUR NOTIFYMUX API KEY HERE>")
}

function Test-Preflight {
    $status = $true
    $script:ResolvedRclonePath = Resolve-RclonePath

    if ($null -eq $script:ResolvedRclonePath) {
        Write-LogMessage -Level "ERROR" -Message "rclone does not exist or is not executable: $RclonePath"
        $status = $false
    }

    if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
        Write-LogMessage -Level "ERROR" -Message "rclone config file does not exist or is not readable: $ConfigFile"
        $status = $false
    }

    if (-not (Test-NotifyMuxConfigured)) {
        Write-LogMessage -Level "WARNING" -Message "NotifyMux API Key is not configured or still uses the placeholder; failure notifications will be skipped."
    }

    return $status
}

function Build-RcloneOptions {
    param(
        [bool]$DryRun = $false
    )

    $script:RcloneOptions = @(
        "--config"
        $ConfigFile
        "sync"
        $SourceDir
        $DestDir
        # Keep only when self-signed certificates or private endpoints require it.
        "--no-check-certificate"
        # Single file transfer timeout.
        "--timeout"
        "60m"
        # Retry count.
        "--retries"
        "3"
        # Retry delay.
        "--retries-sleep"
        "5s"
        # Delete destination files that match exclude rules.
        "--delete-excluded"
        # Print transfer stats every minute.
        "--stats"
        "1m"
        # Faster listing for supported backends, such as Minio, S3, or OneDrive.
        "--fast-list"
        # rclone log level.
        "--log-level"
        "INFO"
        # Write rclone logs to the same monthly log file.
        "--log-file"
        $LogFile
        # Optional tuning examples:
        # "--checkers=8"
        # "--transfers=4"
        # "--buffer-size=16M"
        # "--bwlimit"
        # "2M"
    )

    if (-not [string]::IsNullOrWhiteSpace($ExcludeList)) {
        foreach ($item in ($ExcludeList -split ",")) {
            $trimmedItem = $item.Trim()
            if ($trimmedItem.Length -gt 0) {
                $script:RcloneOptions += @("--exclude", $trimmedItem)
            }
        }
    }

    if ($DryRun) {
        $script:RcloneOptions += "--dry-run"
    }
}

function Format-CommandArgument {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    if ($Value -match "^[A-Za-z0-9_./:\\-]+$") {
        return $Value
    }

    return "'" + $Value.Replace("'", "''") + "'"
}

function Format-RcloneCommand {
    $parts = @($script:ResolvedRclonePath) + $script:RcloneOptions
    return (($parts | ForEach-Object { Format-CommandArgument -Value ([string]$_) }) -join " ")
}

function Send-NotifyMux {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not (Test-NotifyMuxConfigured)) {
        Write-LogMessage -Level "WARNING" -Message "NotifyMux API Key is not configured; skipping failure notification."
        return $true
    }

    Write-LogMessage -Level "INFO" -Message "Sending NotifyMux notification..."

    $notifyTitle = "Rclone Sync: $JobName"
    $payload = @{
        title = $notifyTitle
        body = $Message
        channelIds = [object[]]@()
        metadata = @{
            service = "rclone-sync"
            job = $JobName
        }
    } | ConvertTo-Json -Depth 4

    $requestParams = @{
        Uri = $NotifyMuxEndpoint
        Method = "Post"
        Headers = @{
            "X-API-Key" = $NotifyMuxApiKey
        }
        Body = $payload
        ContentType = "application/json"
        ErrorAction = "Stop"
    }

    if ($PSVersionTable.PSVersion.Major -le 5) {
        $requestParams.UseBasicParsing = $true
    }

    try {
        $response = Invoke-WebRequest @requestParams
        if ([int]$response.StatusCode -eq 200) {
            Write-LogMessage -Level "INFO" -Message "NotifyMux notification sent."
            return $true
        }

        Write-LogMessage -Level "ERROR" -Message "NotifyMux notification failed. HTTP status: $($response.StatusCode). Response: $($response.Content)"
        return $false
    } catch {
        Write-LogMessage -Level "ERROR" -Message "NotifyMux notification failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-Sync {
    param(
        [bool]$DryRun = $false
    )

    Build-RcloneOptions -DryRun $DryRun
    Write-LogMessage -Level "INFO" -Message "Running rclone command: $(Format-RcloneCommand)"

    try {
        & $script:ResolvedRclonePath @script:RcloneOptions
        if ($null -eq $LASTEXITCODE) {
            return 0
        }
        return [int]$LASTEXITCODE
    } catch {
        Write-LogMessage -Level "ERROR" -Message "rclone execution error: $($_.Exception.Message)"
        return 1
    }
}

function Invoke-SyncCommand {
    param(
        [bool]$DryRun = $false
    )

    $exitCode = 0
    $message = ""
    $modeLabel = if ($DryRun) { "dry-run" } else { "sync" }

    Write-LogMessage -Level "INFO" -Message "==================== Job '$JobName' $modeLabel started at $(Get-Timestamp) ===================="

    if (Test-Preflight) {
        $exitCode = Invoke-Sync -DryRun $DryRun
    } else {
        $exitCode = 2
        $message = "Job '$JobName' preflight failed; $modeLabel was not executed. Source: '$SourceDir' -> Destination: '$DestDir'."
        Write-LogMessage -Level "ERROR" -Message $message
        if (-not $DryRun) {
            Send-NotifyMux -Message $message | Out-Null
        }
    }

    if ($exitCode -eq 0) {
        $message = "Job '$JobName' $modeLabel succeeded. Source: '$SourceDir' -> Destination: '$DestDir'."
        Write-LogMessage -Level "INFO" -Message $message
    } elseif ($exitCode -ne 2) {
        $message = "Job '$JobName' $modeLabel failed. Source: '$SourceDir' -> Destination: '$DestDir'. rclone exit code: $exitCode."
        Write-LogMessage -Level "ERROR" -Message $message
        if (-not $DryRun) {
            Send-NotifyMux -Message $message | Out-Null
        }
    }

    Write-LogMessage -Level "INFO" -Message "==================== Job '$JobName' $modeLabel finished at $(Get-Timestamp) (exit code: $exitCode) ================"
    Add-Content -LiteralPath $LogFile -Encoding UTF8 -Value ""

    exit $exitCode
}

function Invoke-PushTest {
    if (-not (Test-NotifyMuxConfigured)) {
        Write-LogMessage -Level "ERROR" -Message "NotifyMux API Key is not configured; push-test cannot be sent."
        [Console]::Error.WriteLine("NotifyMux API Key is not configured. Set NotifyMuxApiKey first.")
        exit 1
    }

    $message = "rclone-sync push-test test message. Job '$JobName' can reach NotifyMux."
    Write-LogMessage -Level "INFO" -Message "Running push-test."

    if (Send-NotifyMux -Message $message) {
        Write-LogMessage -Level "INFO" -Message "push-test succeeded."
        Write-Output "push-test succeeded."
        exit 0
    }

    Write-LogMessage -Level "ERROR" -Message "push-test failed."
    [Console]::Error.WriteLine("push-test failed. See log: $LogFile")
    exit 1
}

function Show-Help {
    @"
rclone-sync

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1 [sync|dry-run|push-test|help]

Commands:
  sync       Run rclone sync. This is the default when no command is provided.
  dry-run    Run rclone sync with --dry-run. No NotifyMux failure notification is sent.
  push-test  Send one NotifyMux test notification. rclone and config are not checked.
  help       Show this help message.

Examples:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1 sync
  powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1 dry-run
  powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1 push-test

Configuration:
  JobName, RclonePath, ConfigFile, SourceDir, DestDir, ExcludeList, LogDir,
  NotifyMuxApiKey, NotifyMuxEndpoint
"@
}

function Write-HelpToStderr {
    $helpText = Show-Help | Out-String
    [Console]::Error.WriteLine($helpText.TrimEnd())
}

function Main {
    $command = if ($args.Count -gt 0) { [string]$args[0] } else { "sync" }

    switch ($command) {
        "sync" { }
        "dry-run" { }
        "push-test" { }
        "help" {
            Show-Help
            exit 0
        }
        "-h" {
            Show-Help
            exit 0
        }
        "--help" {
            Show-Help
            exit 0
        }
        default {
            Write-HelpToStderr
            exit 64
        }
    }

    if ($args.Count -gt 1) {
        Write-HelpToStderr
        exit 64
    }

    if (-not (Ensure-LogDir)) {
        exit 1
    }

    switch ($command) {
        "sync" {
            Invoke-SyncCommand -DryRun $false
        }
        "dry-run" {
            Invoke-SyncCommand -DryRun $true
        }
        "push-test" {
            Invoke-PushTest
        }
    }
}

# --- Entry point ---
Main @args
