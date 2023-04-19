# PowerShell script to mount an NFS share if not already mounted and backup specified folders using Duplicacy

# Preconfig
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Configuration variables
$NfsShare = "\\192.168.1.112\bulkStorage" # Replace with the NFS share path
$MountPoint = "X:" # Replace with the desired mount point
$DuplicacyExe = "C:\Program Files\duplicacy-cli\Duplicacy_latest.exe" # Replace with the path to the Duplicacy executable
$BackupRootFolder = "X:\killswitch-pc-backup" # Replace with the root folder where you want to store backups
# $FoldersToBackup = @("C:\Users\KillSwitch\GitProjects", "C:\Users\KillSwitch\Desktop") # Replace with the list of folders you want to backup
$FoldersToBackup = @("C:\Users\KillSwitch\GitProjects")
$StorageURL = "file://$BackupRootFolder" # Replace with the Duplicacy storage URL (supports various backends)

# Function to check if Duplicacy CLI is installed
function IsDuplicacyInstalled($DuplicacyExe) {
	return Test-Path $DuplicacyExe
}

# Function to download and install the latest version of Duplicacy CLI
function InstallDuplicacy($DuplicacyExe, $LatestReleaseAsset) {
	$DownloadPath = "$env:TEMP\Duplicacy_latest.exe"

	# Download the latest Duplicacy CLI release using wget
	wget $LatestReleaseAsset.browser_download_url -OutFile $DownloadPath

	# Move file to directory
	Move-Item -Path $DownloadPath -Destination $(Split-Path $DuplicacyExe)

	# Remove the downloaded archive
	Remove-Item $DownloadPath
}

# Function to update Duplicacy CLI to the latest version
function UpdateDuplicacy($DuplicacyExe) {
	$DownloadUrl = "https://api.github.com/repos/gilbertchen/duplicacy/releases/latest"
	$LatestRelease = Invoke-WebRequest -Uri $DownloadUrl -UseBasicParsing | ConvertFrom-Json
	$LatestReleaseAsset = $LatestRelease.assets | Where-Object { $_.name -match "duplicacy_win_i386" }
    
	if (-not (IsDuplicacyInstalled $DuplicacyExe)) {
		# InstallDuplicacy $DuplicacyExe
		InstallDuplicacy $DuplicacyExe $LatestReleaseAsset
	}
 else {
		$CurrentVersion = (& $DuplicacyExe) -split "`n" | Where-Object { $_ -match "^\s*\d+\.\d+\.\d+" } | Where-Object { $_ -match "^\s*\d+\.\d+\.\d+" } | Select-String -Pattern '(\d+\.\d+\.\d+)' | ForEach-Object { $_.Matches.Groups[1].Value }
		$LatestVersion = $LatestReleaseAsset.name | Select-String -Pattern '(\d+\.\d+\.\d+)' | ForEach-Object { $_.Matches.Groups[1].Value }

		if ($LatestVersion -ne $CurrentVersion) {
			Write-Host "Duplicacy has been updated from version $CurrentVersion to version $LatestVersion."
		}
		else {
			Write-Host "Duplicacy is already up to date. Version: $CurrentVersion"
		}
	}
}

# Function to check if the NFS share is mounted
function IsNfsShareMounted($MountPoint, $NfsShare) {
	$mounted = $false
	$mountedShares = Get-SmbMapping | Where-Object -Property Status -EQ "OK"

	foreach ($share in $mountedShares) {
		if ($share.LocalPath -eq $MountPoint -and $share.RemotePath -eq $NfsShare) {
			$mounted = $true
			break
		}
	}
	return $mounted
}

# Function to mount the NFS share
function MountNfsShare($MountPoint, $NfsShare) {
	try {
		New-SmbMapping -LocalPath $MountPoint -RemotePath $NfsShare
	}
 catch {
		Write-Host "Failed to mount the NFS share. Error: $_"
		exit 1
	}
}

# Function to backup a folder using Duplicacy
function BackupFolderWithDuplicacy($Source, $DuplicacyExe, $BackupRootFolder) {
	$DuplicacyFolder = Join-Path $Source ".duplicacy"
	$repository_id = (Split-Path $Source -Leaf).Replace(' ', '') + "_repo"

	try {
		Set-Location -Path $Source

		if (-not (Test-Path $DuplicacyFolder)) {
			& $DuplicacyExe init $repository_id $BackupRootFolder
		}
		else {
			Write-Host "Duplicacy repository already initialized."
		}

		& $DuplicacyExe backup
	}
 	catch {
		Write-Host "Failed to backup the folder using Duplicacy. Error: $_"
		exit 1
	}
}

# Main script
# Call the UpdateDuplicacy function to ensure Duplicacy CLI is installed and up-to-date
UpdateDuplicacy $DuplicacyExe

if (-not (IsNfsShareMounted $MountPoint $NfsShare)) {
	MountNfsShare $MountPoint $NfsShare
}

foreach ($folder in $FoldersToBackup) {
	Write-Host "Backing up folder: $folder"
	BackupFolderWithDuplicacy $folder $DuplicacyExe $BackupRootFolder
}

Write-Host "Backup completed successfully using Duplicacy."
