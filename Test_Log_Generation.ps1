<#
.SYNOPSIS
    Creates test folders and log files for testing the Log_Cleanup.ps1 script.

.DESCRIPTION
    This script generates a folder structure with .log files of varying ages
    to test the Log_Cleanup.ps1 script functionality.

.PARAMETER TestFolderPath
    The root path where test folders and files will be created.

.EXAMPLE
    .\Create_TestLogFiles.ps1 -TestFolderPath "C:\TestLogs"
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$TestFolderPath = (Join-Path -Path $PSScriptRoot -ChildPath "TestLogs")
)

# Create the main test folder
if (-not (Test-Path -Path $TestFolderPath)) {
    New-Item -Path $TestFolderPath -ItemType Directory -Force | Out-Null
    Write-Host "Created main folder: $TestFolderPath" -ForegroundColor Green
}
else {
    Write-Host "Main folder already exists: $TestFolderPath" -ForegroundColor Yellow
}

# Create subfolders
$subfolders = @(
    "Application",
    "Application\Archive",
    "System",
    "IIS"
)

foreach ($subfolder in $subfolders) {
    $fullPath = Join-Path -Path $TestFolderPath -ChildPath $subfolder
    if (-not (Test-Path -Path $fullPath)) {
        New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
        Write-Host "Created subfolder: $fullPath" -ForegroundColor Green
    }
}

# Define test files with their ages (in days) and locations
$testFiles = @(
    @{ Name = "app_current.log"; Folder = ""; DaysOld = 5 },
    @{ Name = "app_recent.log"; Folder = ""; DaysOld = 30 },
    @{ Name = "app_old.log"; Folder = ""; DaysOld = 90 },
    @{ Name = "app_archive_2024.log"; Folder = "Application"; DaysOld = 15 },
    @{ Name = "app_archive_2023.log"; Folder = "Application"; DaysOld = 120 },
    @{ Name = "deep_archive.log"; Folder = "Application\Archive"; DaysOld = 200 },
    @{ Name = "deep_recent.log"; Folder = "Application\Archive"; DaysOld = 10 },
    @{ Name = "system_current.log"; Folder = "System"; DaysOld = 3 },
    @{ Name = "system_old.log"; Folder = "System"; DaysOld = 75 },
    @{ Name = "system_ancient.log"; Folder = "System"; DaysOld = 365 },
    @{ Name = "iis_w3svc1.log"; Folder = "IIS"; DaysOld = 45 },
    @{ Name = "iis_w3svc2.log"; Folder = "IIS"; DaysOld = 100 },
    @{ Name = "iis_current.log"; Folder = "IIS"; DaysOld = 1 }
)

Write-Host "`nCreating test log files..." -ForegroundColor Cyan

foreach ($file in $testFiles) {
    $folderPath = if ($file.Folder) { Join-Path -Path $TestFolderPath -ChildPath $file.Folder } else { $TestFolderPath }
    $filePath = Join-Path -Path $folderPath -ChildPath $file.Name

    # Create the file with some sample content
    $content = @"
Log File: $($file.Name)
Created for testing Log_Cleanup.ps1
Simulated age: $($file.DaysOld) days old
Timestamp: $(Get-Date)
----------------------------------------
Sample log entry 1
Sample log entry 2
Sample log entry 3
"@

    Set-Content -Path $filePath -Value $content -Force

    # Set the LastWriteTime to simulate the file age
    $newDate = (Get-Date).AddDays(-$file.DaysOld)
    (Get-Item -Path $filePath).LastWriteTime = $newDate

    Write-Host "  Created: $filePath (Age: $($file.DaysOld) days)" -ForegroundColor Gray
}

# Summary
Write-Host "`n========== Test Environment Created ==========" -ForegroundColor Cyan
Write-Host "Root Folder: $TestFolderPath" -ForegroundColor White
Write-Host "Total Files Created: $($testFiles.Count)" -ForegroundColor White
Write-Host "`nFile Age Summary:" -ForegroundColor White
Write-Host "  Files < 30 days old:  $(($testFiles | Where-Object { $_.DaysOld -lt 30 }).Count)" -ForegroundColor Green
Write-Host "  Files 30-60 days old: $(($testFiles | Where-Object { $_.DaysOld -ge 30 -and $_.DaysOld -le 60 }).Count)" -ForegroundColor Yellow
Write-Host "  Files > 60 days old:  $(($testFiles | Where-Object { $_.DaysOld -gt 60 }).Count)" -ForegroundColor Red
Write-Host "`nTest with:" -ForegroundColor Cyan
Write-Host "  .\Log_Cleanup.ps1 -FolderPath `"$TestFolderPath`" -MaxAgeDays 60 -WhatIf" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor Cyan