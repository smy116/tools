#requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#===============================================================================
# Description: Sync data with rclone and send NotifyMux notifications on failure.
# Author: SMY
#===============================================================================

# --- Configuration ---
# Job name used for logs and notifications.
$JobName = "Sync-Minio-To-E5"

# rclone executable path.
# If rclone is in PATH, keep this as "rclone"; otherwise use an absolute path.
$RclonePath = "rclone"

# rclone config file path.
# The usual Windows default is "$env:APPDATA\rclone\rclone.conf".
$DefaultRcloneConfigDir = if ($env:APPDATA) {
    Join-Path $env:APPDATA "rclone"
} else {
    Join-Path $HOME ".config/rclone"
}
$ConfigFile = Join-Path $DefaultRcloneConfigDir "rclone.conf"

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
$LogDir = Join-Path $DefaultRcloneConfigDir "log"
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

    if ([string]::IsNullOrWhiteSpace($ExcludeList)) {
        return
    }

    foreach ($item in ($ExcludeList -split ",")) {
        $trimmedItem = $item.Trim()
        if ($trimmedItem.Length -gt 0) {
            $script:RcloneOptions += @("--exclude", $trimmedItem)
        }
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

    $payload = @{
        title = $JobName
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
    Build-RcloneOptions
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

function Main {
    $exitCode = 0
    $message = ""

    if (-not (Ensure-LogDir)) {
        exit 1
    }

    Write-LogMessage -Level "INFO" -Message "==================== Job '$JobName' started at $(Get-Timestamp) ===================="

    if (Test-Preflight) {
        $exitCode = Invoke-Sync
    } else {
        $exitCode = 2
        $message = "Job '$JobName' preflight failed; sync was not executed. Source: '$SourceDir' -> Destination: '$DestDir'."
        Write-LogMessage -Level "ERROR" -Message $message
        Send-NotifyMux -Message $message | Out-Null
    }

    if ($exitCode -eq 0) {
        $message = "Job '$JobName' sync succeeded. Source: '$SourceDir' -> Destination: '$DestDir'."
        Write-LogMessage -Level "INFO" -Message $message
    } elseif ($exitCode -ne 2) {
        $message = "Job '$JobName' sync failed. Source: '$SourceDir' -> Destination: '$DestDir'. rclone exit code: $exitCode."
        Write-LogMessage -Level "ERROR" -Message $message
        Send-NotifyMux -Message $message | Out-Null
    }

    Write-LogMessage -Level "INFO" -Message "==================== Job '$JobName' finished at $(Get-Timestamp) (exit code: $exitCode) ================"
    Add-Content -LiteralPath $LogFile -Encoding UTF8 -Value ""

    exit $exitCode
}

# --- Entry point ---
Main
