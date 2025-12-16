<#
.SYNOPSIS
    Cleans up old log files from a specified folder on a local or remote server.

.DESCRIPTION
    This script identifies and removes log files older than a specified number of days
    from a target folder. It can operate on the local machine or a remote server.

.PARAMETER TargetServer
    Remote server to clean up log files on.

.PARAMETER FolderPath
    Path to the log folder local to the system or on the remote server.

.PARAMETER MaxAgeDays
    Maximum age of log files to retain (in days). Files older than this will be deleted.

.PARAMETER DebugPreference
    Set the debug preference for logging. Options are "SilentlyContinue" or "Continue".

.PARAMETER WhatIf
    When specified, the script will only report which files would be deleted without actually deleting them.

.EXAMPLE
    .\Log_Cleanup.ps1 -TargetServer "Server01" -FolderPath "C:\Logs" -MaxAgeDays 30 -DebugPreference "Continue"

.EXAMPLE
    .\Log_Cleanup.ps1 -FolderPath "C:\Logs" -MaxAgeDays 15 -DebugPreference "SilentlyContinue"

.EXAMPLE
    .\Log_Cleanup.ps1 -FolderPath "\\Server01\Logs" -MaxAgeDays 60

.EXAMPLE
    .\Log_Cleanup.ps1 -FolderPath "C:\Logs" -MaxAgeDays 30 -WhatIf
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$TargetServer = 'localhost',

    [Parameter(Mandatory = $false)]
    [string]$FolderPath = "C:\inetpub\logs\LogFiles",

    [Parameter(Mandatory = $false)]
    [int]$MaxAgeDays = 60,

    [Parameter(Mandatory = $false)]
    [ValidateSet("SilentlyContinue", "Continue")]
    [string]$DebugPreference = "Continue",

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Start the transcript for debugging purposes
if ($DebugPreference -eq "Continue")
{
    $logFile = Join-Path -Path ($PSScriptRoot) -ChildPath "CSV_Parser_debug.log"
    Start-Transcript -Path $logFile -Append
}

function Get-FilePaths {
    param (
        [string]$TargetServer,
        [string]$FolderPath
    )
    <#
        Inputs:
            - TargetServer: The remote server to connect to. Can be localhost or DNS name
            - FolderPath: The path to the log folder.
        Outputs:
            - Array of log file paths to be processed.
    #>

    if ($TargetServer -eq "localhost" -or $TargetServer -eq $env:COMPUTERNAME) {
        # Local server - get files directly
        $files = Get-ChildItem -Path $FolderPath -File -Recurse -ErrorAction SilentlyContinue |
                 Select-Object -ExpandProperty FullName
    }
    else {
        # Remote server - use Invoke-Command
        $files = Invoke-Command -ComputerName $TargetServer -ScriptBlock {
            param($Path)
            Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
        } -ArgumentList $FolderPath
    }

    return $files
}

function Get-FileDate {
    param (
        [string]$TargetServer,
        [string]$FilePath
    )
    <#
        Inputs:
            - TargetServer: The remote server where the file resides.
            - FilePath: The path to the log file.
        Outputs:
            - DateTime object representing the date of the log file.
    #>

    if ($TargetServer -eq "localhost" -or $TargetServer -eq $env:COMPUTERNAME) {
        # Local server - get file date directly
        $fileDate = (Get-Item -Path $FilePath -ErrorAction SilentlyContinue).LastWriteTime
    }
    else {
        # Remote server - use Invoke-Command
        $fileDate = Invoke-Command -ComputerName $TargetServer -ScriptBlock {
            param($Path)
            (Get-Item -Path $Path -ErrorAction SilentlyContinue).LastWriteTime
        } -ArgumentList $FilePath
    }

    return $fileDate
}

function Compare-Dates {
    param (
        [DateTime]$FileDate,
        [int]$MaxAgeDays
    )
    <#
        Inputs:
            - FileDate: The date of the log file.
            - MaxAgeDays: The maximum age in days to retain log files.
        Outputs:
            - Boolean indicating whether the file is older than MaxAgeDays.
    #>

    $cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)
    return $FileDate -lt $cutoffDate
}

function Remove-OldFile {
    param (
        [string]$TargetServer,
        [string]$FilePath
    )
    <#
        Inputs:
            - TargetServer: The remote server where the file resides.
            - FilePath: The path to the log file to delete.
        Outputs:
            - Boolean indicating success or failure of deletion.
    #>

    try {
        if ($TargetServer -eq "localhost" -or $TargetServer -eq $env:COMPUTERNAME) {
            # Local server - delete file directly
            Remove-Item -Path $FilePath -Force -ErrorAction Stop
        }
        else {
            # Remote server - use Invoke-Command
            Invoke-Command -ComputerName $TargetServer -ScriptBlock {
                param($Path)
                Remove-Item -Path $Path -Force -ErrorAction Stop
            } -ArgumentList $FilePath
        }
        return $true
    }
    catch {
        Write-Warning "Failed to delete file: $FilePath. Error: $_"
        return $false
    }
}

function Write-Results {
    param (
        [string[]]$DeletedFiles,
        [string[]]$DeletedFileDates,
        [string[]]$FailedFiles,
        [int]$TotalProcessed,
        [bool]$WhatIfMode
    )
    <#
        Inputs:
            - DeletedFiles: Array of deleted (or would-be deleted) log file paths.
            - DeletedFileDates: Array of dates for the deleted files.
            - FailedFiles: Array of files that failed to delete.
            - TotalProcessed: Total number of files processed.
            - WhatIfMode: Boolean indicating if running in WhatIf mode.
        Outputs:
            - None. Outputs results to console or log.
    #>

    $actionVerb = if ($WhatIfMode) { "would be deleted" } else { "deleted" }
    $headerText = if ($WhatIfMode) { "Log Cleanup Results (WhatIf Mode - No Changes Made)" } else { "Log Cleanup Results" }

    Write-Host "`n========== $headerText ==========" -ForegroundColor Cyan
    Write-Host "Total files processed: $TotalProcessed" -ForegroundColor White
    Write-Host "Files $($actionVerb): $($DeletedFiles.Count)" -ForegroundColor Green

    if (-not $WhatIfMode) {
        Write-Host "Files failed to delete: $($FailedFiles.Count)" -ForegroundColor $(if ($FailedFiles.Count -gt 0) { "Red" } else { "White" })
    }

    if ($DeletedFiles.Count -gt 0) {
        $listHeader = if ($WhatIfMode) { "--- Files That Would Be Deleted ---" } else { "--- Deleted Files ---" }
        Write-Host "`n$listHeader" -ForegroundColor Green
        for ($i = 0; $i -lt $DeletedFiles.Count; $i++) {
            Write-Host "  $($DeletedFiles[$i]) (Date: $($DeletedFileDates[$i]))" -ForegroundColor Gray
        }
    }

    if (-not $WhatIfMode -and $FailedFiles.Count -gt 0) {
        Write-Host "`n--- Failed Files ---" -ForegroundColor Red
        foreach ($file in $FailedFiles) {
            Write-Host "  $file" -ForegroundColor Gray
        }
    }

    Write-Host "`n==========================================" -ForegroundColor Cyan
}

# Main execution
Write-Host "Starting Log Cleanup Script" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "*** RUNNING IN WHATIF MODE - NO FILES WILL BE DELETED ***" -ForegroundColor Yellow
}
Write-Host "Target Server: $TargetServer" -ForegroundColor White
Write-Host "Folder Path: $FolderPath" -ForegroundColor White
Write-Host "Max Age (Days): $MaxAgeDays" -ForegroundColor White
Write-Host ""

# Get all file paths
$filePaths = Get-FilePaths -TargetServer $TargetServer -FolderPath $FolderPath

if (-not $filePaths -or $filePaths.Count -eq 0) {
    Write-Host "No files found in the specified folder path." -ForegroundColor Yellow
}
else {
    Write-Host "Found $($filePaths.Count) file(s) to process." -ForegroundColor White

    # Initialize tracking arrays
    $deletedFiles = @()
    $deletedFileDates = @()
    $failedFiles = @()

    foreach ($filePath in $filePaths) {
        # Get the file date
        $fileDate = Get-FileDate -TargetServer $TargetServer -FilePath $filePath

        if ($null -eq $fileDate) {
            Write-Warning "Could not retrieve date for file: $filePath"
            continue
        }

        # Check if file is older than MaxAgeDays
        $isOld = Compare-Dates -FileDate $fileDate -MaxAgeDays $MaxAgeDays

        if ($isOld) {
            Write-Debug "File '$filePath' (Date: $fileDate) is older than $MaxAgeDays days. $(if ($WhatIf) { 'Would delete...' } else { 'Deleting...' })"

            if ($WhatIf) {
                # WhatIf mode - just record the file without deleting
                $deletedFiles += $filePath
                $deletedFileDates += $fileDate.ToString("yyyy-MM-dd HH:mm:ss")
            }
            else {
                # Actually delete the file
                $deleted = Remove-OldFile -TargetServer $TargetServer -FilePath $filePath

                if ($deleted) {
                    $deletedFiles += $filePath
                    $deletedFileDates += $fileDate.ToString("yyyy-MM-dd HH:mm:ss")
                }
                else {
                    $failedFiles += $filePath
                }
            }
        }
        else {
            Write-Debug "File '$filePath' (Date: $fileDate) is within retention period. Skipping."
        }
    }

    # Output the results
    Write-Results -DeletedFiles $deletedFiles -DeletedFileDates $deletedFileDates -FailedFiles $failedFiles -TotalProcessed $filePaths.Count -WhatIfMode $WhatIf
}

if ($DebugPreference -eq "Continue") {
    # Stop the transcript
    Stop-Transcript
}