param(
    [Parameter(Mandatory = $false)]
    [string]$SevenZipPath = "C:\Program Files\7-Zip\7z.exe",

    [Parameter(Mandatory = $false)]
    [string[]]$BackupPaths = @(
        "C:\inetpub\logs\LogFiles\W3SVC1",
        "C:\inetpub\logs\LogFiles\W3SVC2"
    ),

    [Parameter(Mandatory = $false)]
    [string]$ArchiveExtension = ".7z",

    # ???????????? ????? ?????? ?????????? ?????????? ????.
    # -1 = ???, ??? ?????? ?????.
    [Parameter(Mandatory = $false)]
    [int]$Days = -1,

    # ??????? ?????? ?????? ?????????? ?????????? ????.
    # -31 = ?????? 31 ???.
    [Parameter(Mandatory = $false)]
    [int]$ArchiveDays = -31,

    # ??? ?????? ?????? ???????.
    [Parameter(Mandatory = $false)]
    [string]$LogFile = "C:\Logs\IIS-Archive.log"
)


function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$TimeStamp [$Level] $Message"

    Write-Host $LogMessage

    try {
        Add-Content `
            -Path $LogFile `
            -Value $LogMessage `
            -Encoding UTF8 `
            -ErrorAction Stop
    }
    catch {
        Write-Host "ERROR: Failed to write to log file $LogFile : $($_.Exception.Message)"
    }
}


function Initialize-Script {
    try {
        if (-not (Test-Path -LiteralPath $SevenZipPath)) {
            throw "7-Zip not found: $SevenZipPath"
        }

        $LogDirectory = Split-Path -Path $LogFile -Parent

        if (-not [string]::IsNullOrWhiteSpace($LogDirectory)) {
            if (-not (Test-Path -LiteralPath $LogDirectory)) {
                New-Item `
                    -Path $LogDirectory `
                    -ItemType Directory `
                    -Force `
                    -ErrorAction Stop | Out-Null
            }
        }

        Write-Log "============================================================"
        Write-Log "IIS log archive script started."
        Write-Log "7-Zip: $SevenZipPath"
        Write-Log "Archive files older than: $Days day(s)"
        Write-Log "Delete archives older than: $ArchiveDays day(s)"
    }
    catch {
        Write-Host "Initialization failed: $($_.Exception.Message)"
        exit 1
    }
}


function Archive-Files {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Directory does not exist: $Path"
        }

        Write-Log "Processing directory: $Path"

        $CutoffDate = (Get-Date).AddDays($Days)

        $Files = Get-ChildItem `
            -LiteralPath $Path `
            -File `
            -Recurse `
            -ErrorAction Stop |
            Where-Object {
                $_.Extension -in @(".log", ".txt") -and
                $_.LastWriteTime -le $CutoffDate
            }

        if (-not $Files) {
            Write-Log "No files found for archiving in: $Path"
            return
        }

        Write-Log "Found $($Files.Count) file(s) for archiving."

        #
        # ?????????? ????? ?? ????.
        #
        # ????????:
        #
        # 2026-09-28.7z
        # 2026-09-29.7z
        #
        $Groups = $Files | Group-Object {
            $_.LastWriteTime.ToString("yyyy-MM-dd")
        }

        foreach ($Group in $Groups) {

            $ArchiveDate = $Group.Name

            $ArchiveFile = Join-Path `
                -Path $Path `
                -ChildPath "$ArchiveDate$ArchiveExtension"

            Write-Log "Creating/updating archive: $ArchiveFile"

            foreach ($File in $Group.Group) {

                try {
                    Write-Log "Archiving: $($File.FullName)"

                    $Arguments = @(
                        "a",
                        $ArchiveFile,
                        "-t7z",
                        "-m0=lzma2",
                        "-mx=9",
                        "-aoa",
                        "-mfb=64",
                        "-md=32m",
                        "-ms=on",
                        $File.FullName
                    )

                    $SevenZipOutput = & $SevenZipPath @Arguments 2>&1

                    $ExitCode = $LASTEXITCODE

                    if ($ExitCode -ne 0) {

                        Write-Log `
                            "7-Zip failed for '$($File.FullName)'. Exit code: $ExitCode" `
                            "ERROR"

                        foreach ($Line in $SevenZipOutput) {
                            Write-Log "7-Zip: $Line" "ERROR"
                        }

                        #
                        # ?????:
                        # ???????? ???? ?? ???????.
                        #
                        continue
                    }

                    #
                    # ?????? ????? ???????? ????????? ??????? ???????? ???.
                    #
                    Remove-Item `
                        -LiteralPath $File.FullName `
                        -Force `
                        -ErrorAction Stop

                    Write-Log "Archived and removed source file: $($File.FullName)"
                }
                catch {
                    Write-Log `
                        "Failed to archive '$($File.FullName)': $($_.Exception.Message)" `
                        "ERROR"
                }
            }
        }
    }
    catch {
        Write-Log `
            "Failed while processing directory '$Path': $($_.Exception.Message)" `
            "ERROR"
    }
}


function Remove-OldArchives {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Directory does not exist: $Path"
        }

        $ArchiveCutoffDate = (Get-Date).AddDays($ArchiveDays)

        $Archives = Get-ChildItem `
            -LiteralPath $Path `
            -Filter "*$ArchiveExtension" `
            -File `
            -Recurse `
            -ErrorAction Stop |
            Where-Object {
                $_.LastWriteTime -lt $ArchiveCutoffDate
            }

        if (-not $Archives) {
            Write-Log "No old archives found in: $Path"
            return
        }

        foreach ($Archive in $Archives) {

            try {
                Write-Log "Removing old archive: $($Archive.FullName)"

                Remove-Item `
                    -LiteralPath $Archive.FullName `
                    -Force `
                    -ErrorAction Stop

                Write-Log "Old archive removed: $($Archive.FullName)"
            }
            catch {
                Write-Log `
                    "Failed to remove archive '$($Archive.FullName)': $($_.Exception.Message)" `
                    "ERROR"
            }
        }
    }
    catch {
        Write-Log `
            "Failed while removing old archives from '$Path': $($_.Exception.Message)" `
            "ERROR"
    }
}


#
# MAIN
#

Initialize-Script

foreach ($BackupPath in $BackupPaths) {

    try {
        Write-Log "------------------------------------------------------------"
        Write-Log "Starting processing: $BackupPath"

        Archive-Files -Path $BackupPath
        Remove-OldArchives -Path $BackupPath

        Write-Log "Finished processing: $BackupPath"
    }
    catch {
        Write-Log `
            "Unexpected error for '$BackupPath': $($_.Exception.Message)" `
            "ERROR"
    }
}

Write-Log "IIS log archive script finished."
Write-Log "============================================================"
