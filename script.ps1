$BackupFolder = "Z:\stream deck\"
$BackupLocation = Join-Path $BackupFolder "StreamDeckbackup $(Get-Date -Format 'MM-dd-yyyy HH-mm-ss')"

function Invoke-BackupRestore {
    [CmdletBinding()]
    param (
        [ValidateSet("Backup", "Restore")]
        [string]$Mode,
        [switch]$restoreConfirmation
    )

    $source = Join-Path $env:APPDATA "Elgato\StreamDeck"

    switch ($Mode) {
        "Backup" {
            try {
                Copy-Item -Path $source -Destination $BackupLocation -Recurse -Force -ErrorAction Stop
                return 0
            }
            catch {
                Write-Error "Error backupping $_"
                return 42
            }
        }
        "Restore" {
            $latestBackup = Get-ChildItem -Path (Join-Path $BackupLocation '..') -Directory |
            Where-Object { $_.Name -like "StreamDeckBackup *" } |
            Sort-Object CreationTime -Descending |
            Select-Object -First 1

            if (-not $latestBackup) {
                Write-Warning "No backup found in $BackupFolder."
                return 44
            }
            
            if (-not $restoreConfirmation) {
                $restoreConfirmation = Confirm-Restore $latestBackup.FullName
            }

            if ($restoreConfirmation) {
                $restoreSource = $latestBackup.FullName
                # Ensure the original directory exists before restoring
                if (-not (Test-Path $source)) {
                    New-Item -ItemType Directory -Path $source -Force
                }
                try {
                    Remove-Item -Path "$source\*" -Recurse -Force -ErrorAction Stop
                    Copy-Item -Path "$restoreSource\*" -Destination $source -Recurse -Force -ErrorAction Stop
                    return 0 # indicate success
                }
                catch {
                    Write-Error "Error while restoring $restoreSource to destination $source $_"
                    return 45
                }
            }
            else {
                Write-Warning "Restore cancelled by user."
                return 47
            }
        }
    }
}

function Confirm-Restore {
    param (
        [string]$NewestBackupPath
    )
    $confirmation = Read-Host "Do you want to proceed with restoring from the newest backup located at '$NewestBackupPath'? (Y/N)"
    return $confirmation -eq "Y" -or $confirmation -eq "y"
}

# Example usage
$code = Invoke-BackupRestore -Mode Restore -Verbose
Write-Host "Operation returned code $code"