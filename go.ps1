# The one command to start, on any Windows PC. In PowerShell:
#
#   irm https://raw.githubusercontent.com/oliverb-cbr/cbr-start/HEAD/go.ps1 | iex
#
# The repo with the scripts is private, so this launcher is published on its own in the public repo
# oliverb-cbr/cbr-start. This copy is the one to edit; copy it there after changing it. It holds no
# secrets: it asks for the CBR deploy key from the password manager, uses it to get the scripts into
# C:\CBR\cbr-beatles, then runs their bootstrap.bat, which shows the menu.
& {
    $ErrorActionPreference = 'Stop'
    $self = 'https://raw.githubusercontent.com/oliverb-cbr/cbr-start/HEAD/go.ps1'
    $repoSsh = 'git@github.com:oliverb-cbr/cbr-beatles.git'
    $repo = 'C:\CBR\cbr-beatles'
    $keyDir = 'C:\CBR\keys'
    $key = Join-Path $keyDir 'cbr-deploy'
    $git = 'C:\Program Files\Git\cmd\git.exe'
    # Windows' own ssh, with the deploy key and only GitHub's published host key (as bootstrap.bat).
    $ssh = 'C:/Windows/System32/OpenSSH/ssh.exe -i C:/CBR/keys/cbr-deploy -o IdentitiesOnly=yes -o UserKnownHostsFile=C:/CBR/keys/known_hosts -o StrictHostKeyChecking=yes'

    # Needs admin rights: run again elevated, from a downloaded copy of itself.
    $me = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'Asking for administrator rights...'
        $copy = Join-Path $env:TEMP 'cbr-go.ps1'
        Invoke-WebRequest -UseBasicParsing -Uri $self -OutFile $copy
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$copy`""
        return
    }
    $host.UI.RawUI.WindowTitle = 'CBR workstations'

    try {
        # The deploy key: lets this PC read the scripts on GitHub, and nothing else. Admin-only.
        New-Item -ItemType Directory -Force -Path $keyDir | Out-Null
        & icacls $keyDir /inheritance:r /grant:r 'Administrators:(OI)(CI)F' 'SYSTEM:(OI)(CI)F' /Q | Out-Null
        if (-not (Test-Path $key)) {
            Write-Host 'Copy the CBR deploy key from the password manager (all of it, from the BEGIN line to the END line),'
            Write-Host 'then press Enter.'
            [void](Read-Host)
            $text = (@(Get-Clipboard) -join "`n").Trim()
            if ($text -notmatch '-----BEGIN OPENSSH PRIVATE KEY-----') { throw "There's no deploy key on the clipboard. Copy it and run the command again." }
            [IO.File]::WriteAllText($key, $text + "`n")
            Set-Clipboard -Value ' '
            Write-Host 'Got it. Clipboard cleared.'
        }
        # GitHub's published SSH host key (fingerprint SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU).
        [IO.File]::WriteAllText((Join-Path $keyDir 'known_hosts'), "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl`n")

        if (-not (Test-Path $git)) {
            # winget can take a few minutes to appear on a brand-new Windows install.
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-Host 'Getting winget ready. On a new Windows install this can take a few minutes...'
                try { Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe } catch { }
                for ($i = 0; $i -lt 18 -and -not (Get-Command winget -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Seconds 10 }
            }
            Write-Host 'Installing Git...'
            & winget install --id Git.Git --exact --source winget --scope machine --silent --accept-source-agreements --accept-package-agreements
            if (-not (Test-Path $git)) { throw "Git didn't install; see the messages above." }
        }

        if (Test-Path (Join-Path $repo '.git')) {
            # An existing copy, perhaps from before the repo went private: point it at the key.
            & $git -C $repo remote set-url origin $repoSsh
            & $git -C $repo config core.sshCommand $ssh
            Write-Host 'Getting the latest scripts...'
            & $git -C $repo pull --ff-only
        } else {
            Write-Host 'Downloading the scripts...'
            & $git -c "core.sshCommand=$ssh" clone $repoSsh $repo
            if ($LASTEXITCODE -eq 0) { & $git -C $repo config core.sshCommand $ssh }
        }
        if ($LASTEXITCODE -ne 0) { throw 'Getting the scripts failed; see the messages above. If GitHub refused the key, check it on GitHub under the repo''s Settings > Deploy keys.' }

        # bootstrap.bat does the rest (permissions, the menu), the same as running it from the stick.
        & cmd.exe /c "`"$repo\bootstrap.bat`""
    } catch {
        Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
        Read-Host "`nPress Enter to close this window" | Out-Null
    }
}
