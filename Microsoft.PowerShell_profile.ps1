#Disable update notification
$skipupdate = $false
    
if ($skipupdate) {
    Write-Host "############################################" -ForegroundColor Yellow
    Write-Host "#          Skip Update is enabled          #" -ForegroundColor Yellow
    Write-Host "#  Any future update will not be notified  #  " -ForegroundColor Yellow
    Write-Host "############################################"-ForegroundColor Yellow
}

#Disable Telemetry
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

#Check for update If $skipupdate = $false (I "borrow" the code from CTT's PowerShell-Profile)
$global:conngh = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1
#Check for PowerShell Profile Update
function CheckPSProfileUpdate {
    try {
        $url = "https://codeberg.org/patinopsu/powershell-profile/raw/branch/main/Microsoft.PowerShell_profile.ps1"
        $currversion = Get-FileHash $PROFILE
        $tempFile = "$env:temp/msprofile.ps1"
        Invoke-WebRequest -Uri $url -OutFile $tempFile
        $newhash = Get-FileHash $tempFile

        if ($newhash.Hash -ne $currversion.Hash) {
            Write-Host "An (optional) update to the PowerShell Profile is available! Use Update-Profile to update" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Unable to check for PowerShell Profile update ($_)" -ForegroundColor Red
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile
        }
    }
}



#Function to update profile
function Update-Profile {
    $url = "https://codeberg.org/patinopsu/powershell-profile/raw/branch/main/Microsoft.PowerShell_profile.ps1"
    $currversion = Get-FileHash $PROFILE
    Invoke-RestMethod $url -OutFile "$env:temp/msprofile.ps1"
    $newhash = Get-FileHash $env:temp/msprofile.ps1
    $backupfolder = "$env:USERPROFILE/Documents/PowerShell/Backups"
    if ($newhash.Hash -ne $currversion.Hash) {
        if(-not (Get-ChildItem $backupfolder -ErrorAction SilentlyContinue)) {
            Write-Host "Backups folder not found. Creating a new one"
            mkdir $backupfolder >> null
            New-Item $backupfolder/DONOTDELETE.CRITITCAL > $null
            Write-Host "Folder successfully created! Please Re-Run the Update-Profile again" -ForegroundColor Green
            return
        } else {
        $currrawhash = (Get-FileHash $PROFILE).hash
        Write-Host "Updating. Please DON'T CLOSE THE POWERSHELL WINDOW" -ForegroundColor Red
        Copy-Item $PROFILE "$env:USERPROFILE/Documents/PowerShell/Backups/PS-$currrawhash.ps1"
        Copy-Item -Path "$env:temp/msprofile.ps1" -Destination $PROFILE -Force
        Remove-Item -Path "$env:temp/msprofile.ps1" -Force
        Restart-Terminal
        }

    } else {
        Write-Host "You're up to date! No need to update" -ForegroundColor Green
    }
}

#Check for PowerShell Update
function CheckPSUpdate {
    try {
        $needupdate = $false
        $pscurrver = $PSVersionTable.PSVersion.ToString()
        $ghapiurl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestrelinfo = Invoke-RestMethod -Uri $ghapiurl
       $pslaterstver = $latestrelinfo.tag_name.Trim('v')
        if ($pscurrver -lt $pslaterstver) {
            $needupdate = $true
        }
        if ($needupdate) {
            Write-Host "An (optional) PowerShell update is avaliable! Use 'Update-Programs Microsoft.PowerShell' to update" -ForegroundColor Yellow
        }
        else {}
        } catch {
            Write-Host "Failed to check for PowerShell update ($_)" -ForegroundColor Red
    } 
}

if ($skipupdate) {} else {
    CheckPSUpdate
    CheckPSProfileUpdate
}

Import-Module Terminal-Icons
Import-Module PSReadLine
Set-PSReadLineOption -PredictionViewStyle ListView

try {
    $fullName = (Get-WmiObject Win32_UserAccount | Where-Object {
        $_.Name -eq $env:USERNAME -and $_.Domain -eq $env:USERDOMAIN
    }).FullName
} catch {
    $fullName = $null
}
if (-not $fullName) {
    $fullName = $env:USERNAME
}

# Greet the user
Write-Host "Hello, $fullName! Welcome to your PowerShell session." -ForegroundColor Cyan
Write-Host "For help, Invoke 'Get-Help' and all command available will show up" -ForegroundColor Cyan

# Function to Initialize Oh My Posh
function ompinit {
    if($global:ompinited) {
        Write-Host "oh-my-posh is already running." -ForegroundColor Red
        return
    }
    if (-not (Get-Command "oh-my-posh" -ErrorAction SilentlyContinue)) {
        Write-Host "Oh My Posh is not installed. Please install it using the command:" -ForegroundColor Red
        Write-Host "'Install-Programs JanDeDobbeleer.OhMyPosh'" -ForegroundColor Yellow
        return
    }

    $configPath = Join-Path $HOME "Documents\PowerShell\omp-p.json"
    oh-my-posh init pwsh --config $configPath | Invoke-Expression
    $global:ompinited = $true
}

# Initialize Oh My Posh
ompinit

# Function to get public IP address
function Get-PubAddr {
    Write-Host "Public IP Information"
    Write-Host "IPv4:"
    try {
        $ipv4 = Invoke-WebRequest api.ipify.org -ErrorAction Stop | Select-Object -ExpandProperty Content
        Write-Host $ipv4
    } catch {
        Write-Host "IPv4 Address could not be resolved" -ForegroundColor Red
    }
    Write-Host "IPv6:"
    try {
        $ipv6 = Invoke-WebRequest api6.ipify.org -ErrorAction Stop | Select-Object -ExpandProperty Content
        Write-Host $ipv6
    } catch {
        Write-Host "IPv6 Address could not be resolved" -ForegroundColor Red
    }
}

# Function to Restart Termianl
function Restart-Terminal {
    Write-Host "Restarting terminal..." -ForegroundColor Yellow
    # Add a delay so that the user sees the message before the terminal restarts
    Start-Sleep -Seconds 2
    # Restart PowerShell by invoking a new process
    Start-Process "pwsh.exe" -ArgumentList "-NoExit", "-Command", "& {Start-Sleep -Seconds 1}"
    # Exit the current session
    exit
}

# Function to fetch system information
function fetch {
    if(-not(Get-Command fastfetch -ErrorAction SilentlyContinue)) {
        Write-Host "fastfetch Is not installed. Please install fastfetch using 'Install-Programs fastfetch-cli.fastfetch'"
        return
    }
    fastfetch
}

# Function to install Programs
function Install-Programs {
    param(
        [string]$package
    )
    if (-not $package) {
        Write-Host No Programs specified. Please input the Programs -ForegroundColor Yellow
        return
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "winget is not installed. Please install winget and try again." -ForegroundColor Red
        return
    }

    try {
        winget install $package
    } catch {
        Write-Host "Failed to install package: $package" -ForegroundColor Red
    }
}

#Function to search a Programs
function Search-Programs {
    param (
        [string]$package
    )
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "winget is not installed. Please install winget and try again." -ForegroundColor Red
        return
    }
    if (-not $package) {
        Write-Host "No package detected. Please type in the package" -ForegroundColor Yellow
        return
    }
    winget search $package
    
}

# Function to update specific package
function Update-Programs {
    param(
        [string]$package
    )
    if (-not $package) {
        Write-Host "No Programs detected. Please input the Programs name"
        return
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "winget is not installed. Please install winget and try again." -ForegroundColor Red
        return
    }
    try {
        winget upgrade $package
    } catch {
        Write-Host "Failed to upgrade package: $package" -ForegroundColor Red
    }
}

#Launch lazygit without typing lazygit
function lz {
    if (-not (Get-Command lazygit -ErrorAction SilentlyContinue)) {
        Write-Host "lazygit is not installed. Please install lazygit using 'Install-Programs lazygit'" -ForegroundColor Red
        return
    }
    lazygit
}

function reload {
    if ($experimental -eq $true) {
        Write-Output "Experimental mode is enabled. Skipping profile reload."
    } else {
        Write-Output "Reloading the profile..."
        Clear-Host
        . $PROFILE
    }
}


# Function to update all Programs
function Update-AllPrograms {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "winget is not installed. Please install winget and try again." -ForegroundColor Red
        return
    }
    try {
        winget upgrade --all
    } catch {
        Write-Host "Failed to upgrade all Programs." -ForegroundColor Red
    }
}

# Function to download YouTube videos
function Download-Videos {
    param(
        [string]$yturl,
        [string]$videoformat = "mp4"
    )
    if (-not $yturl) {
        Write-Host "No URL detected. Please input URL" -ForegroundColor Red
        return
    }
    $supportedFormats = @("mp4", "mkv", "webm")
    $ytregex = '^https?://(www\.)?(youtube|youtu|youtube-nocookie)\.(com|be)/.*(?:v=|\/)([A-Za-z0-9_-]{11})'
    if ($yturl -notmatch $ytregex) {
        Write-Host "Invalid YouTube URL. Please check and try again." -ForegroundColor Red
        return
    }
    if ($videoformat -notin $supportedFormats) {
        Write-Host "Invalid video format. Supported formats are: $($supportedFormats -join ', ')" -ForegroundColor Red
        return
    }
    if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
        Write-Host "yt-dlp is not installed or not configured correctly." -ForegroundColor Red
        return
    }
    try {
        yt-dlp $yturl --remux-video $videoformat
    } catch {
        Write-Host "Failed to download video." -ForegroundColor Red
    }
}

# Help Function
function Get-Help {
    $helpData = @{
        "Get-PubAddr"        = "Fetches and displays the public IPv4 and IPv6 addresses."
        "Restart-Terminal"   = "Restarts the terminal session."
        "fetch"              = "Displays system information using 'fastfetch'."
        "Search-Programs"    = "Search the package using 'winget. Usage: Search-Package <Programs name>"    
        "Install-Programs"   = "Installs specified package(s) using 'winget'. Usage: Install-Programs <Programs Name>"
        "Update-Programs"    = "Updates a specified package using 'winget'. Usage: Update-Programs <Programs Name>"
        "Update-AllPrograms" = "Updates all installed Programs using 'winget'."
        "lz"                 = "Launch lazygit without typing the whole thing."
        "Download-Videos"    = "Downloads a video from YouTube using 'yt-dlp'. Usage: Download-Videos <URLs> <Video Format (default: mp4)>"
    }
    Write-Host "Welcome to help menu!" -ForegroundColor Cyan
    Write-Host "Here are the available commands:" -ForegroundColor Cyan
    foreach ($key in $helpData.Keys) {
        Write-Host "`t$key - $($helpData[$key])" -ForegroundColor Green
    }
}

