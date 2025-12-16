# Vogon Cleaner

A PowerShell-based log file cleanup utility for local and remote Windows servers.

"Resistance is useless!" - Much like the Vogons demolishing Earth to make way for a hyperspace bypass, this tool efficiently removes old log files to make way for disk space.

## Overview

Vogon Cleaner provides automated log file cleanup based on file age. It supports both local and remote server operations via PowerShell remoting, includes a safe WhatIf mode for previewing changes, and provides detailed output of all operations.

## Scripts

### Log_Cleanup.ps1

The main cleanup script that identifies and removes log files older than a specified retention period.

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| TargetServer | String | localhost | The server to clean up log files on. Can be localhost or a remote server DNS name. |
| FolderPath | String | C:\inetpub\logs\LogFiles | Path to the log folder on the target server. |
| MaxAgeDays | Int | 60 | Maximum age of log files to retain in days. Files older than this will be deleted. |
| DebugPreference | String | Continue | Set to Continue for verbose logging with transcript, or SilentlyContinue for quiet operation. |
| WhatIf | Switch | False | When specified, reports which files would be deleted without actually deleting them. |

#### Examples

Clean up local IIS logs older than 60 days:

```powershell
.\Log_Cleanup.ps1 -FolderPath "C:\inetpub\logs\LogFiles" -MaxAgeDays 60
```

Preview cleanup on a remote server without deleting files:

```powershell
.\Log_Cleanup.ps1 -TargetServer "Server01" -FolderPath "C:\Logs" -MaxAgeDays 30 -WhatIf
```

Clean up logs via UNC path with debug logging disabled:

```powershell
.\Log_Cleanup.ps1 -FolderPath "\\Server01\Logs" -MaxAgeDays 90 -DebugPreference "SilentlyContinue"
```

### Test_Log_Generation.ps1

A utility script that generates a test folder structure with log files of varying ages for testing the cleanup script.

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| TestFolderPath | String | C:\TestLogs | The root path where test folders and files will be created. |

#### Generated Structure

The script creates the following folder structure with 13 log files of varying ages:

```
TestLogs\
    app_current.log (5 days old)
    app_recent.log (30 days old)
    app_old.log (90 days old)
    Application\
        app_archive_2024.log (15 days old)
        app_archive_2023.log (120 days old)
        Archive\
            deep_archive.log (200 days old)
            deep_recent.log (10 days old)
    System\
        system_current.log (3 days old)
        system_old.log (75 days old)
        system_ancient.log (365 days old)
    IIS\
        iis_w3svc1.log (45 days old)
        iis_w3svc2.log (100 days old)
        iis_current.log (1 day old)
```

#### Example

Create test files and preview cleanup:

```powershell
.\Test_Log_Generation.ps1 -TestFolderPath "C:\TestLogs"
.\Log_Cleanup.ps1 -FolderPath "C:\TestLogs" -MaxAgeDays 60 -WhatIf
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- For remote server operations: PowerShell remoting must be enabled on the target server
- Appropriate permissions to read and delete files in the target folder

## Remote Server Requirements

When using the TargetServer parameter to clean up files on a remote server, ensure the following:

1. PowerShell remoting is enabled on the target server (run Enable-PSRemoting on the target)
2. The executing user has administrative access to the remote server
3. Windows Remote Management (WinRM) service is running on both machines
4. Appropriate firewall rules are configured to allow WinRM traffic

## Output

The script provides color-coded console output showing:

- Total files processed
- Number of files deleted (or would be deleted in WhatIf mode)
- Number of files that failed to delete
- Detailed list of affected files with their dates

When DebugPreference is set to Continue, a transcript log is saved to the script directory.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Disclaimer

Always use the WhatIf parameter first to preview which files will be deleted. The authors are not responsible for any unintended data loss. Unlike the Vogons, we do give you a chance to review the demolition plans before execution.