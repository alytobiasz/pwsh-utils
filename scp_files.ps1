<#
.SYNOPSIS
    Copies files from a Linux server to Windows using SCP with password authentication.

.DESCRIPTION
    This script reads a list of file paths from a text file and copies each file
    from a Linux server to a local Windows directory using SCP. It uses native
    OpenSSH scp command for secure file transfer. Files are saved to a timestamped
    folder under ./data/output/.

.PARAMETER SourceListPath
    Path to a text file containing Linux file paths (one per line)

.PARAMETER RemoteUser
    Username for the Linux server

.PARAMETER RemoteHost
    Hostname or IP address of the Linux server

.EXAMPLE
    # Basic usage:
    .\scp_files.ps1 `
        -SourceListPath "C:\path\to\file_list.txt" `
        -RemoteUser "username" `
        -RemoteHost "server.example.com"

.NOTES
    Requirements:
    - OpenSSH client must be installed on Windows (included by default in recent Windows 10/11 versions)
    
    File list format (file_list.txt):
    /home/user/documents/file1.pdf
    /home/user/documents/file2.pdf
    /var/data/file3.pdf
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceListPath,
    
    [Parameter(Mandatory=$true)]
    [string]$RemoteUser,
    
    [Parameter(Mandatory=$true)]
    [string]$RemoteHost
)

# Create timestamped output directory
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$baseDir = Join-Path $PSScriptRoot "data"
$outputDir = Join-Path $baseDir "output${timestamp}"

# Create directory structure if it doesn't exist
if (-not (Test-Path $baseDir)) {
    New-Item -ItemType Directory -Path $baseDir | Out-Null
}
New-Item -ItemType Directory -Path $outputDir | Out-Null
Write-Host "Created output directory: $outputDir"

# Read the list of files
$files = Get-Content $SourceListPath | Where-Object { $_.Trim() -ne "" }
$totalFiles = $files.Count
$successCount = 0

Write-Host "`nStarting transfer of $totalFiles files..."
Write-Host "Destination directory: $outputDir`n"

# Set up SSH control socket
$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
}
$controlPath = Join-Path $sshDir "control-socket-%r@%h-%p"

# Initialize the SSH control master connection
Write-Host "Establishing SSH connection..."
$sshArgs = @(
    "-o", "ControlMaster=yes"
    "-o", "ControlPath=$controlPath"
    "-o", "ControlPersist=yes"
    "${RemoteUser}@${RemoteHost}"
    "exit"
)
Start-Process -FilePath "ssh" -ArgumentList $sshArgs -Wait -NoNewWindow

foreach ($file in $files) {
    # Preserve the full path structure, but remove leading slash
    $relativePath = $file.TrimStart('/')
    $localPath = Join-Path $outputDir $relativePath
    
    # Create the directory structure for this file
    $localDir = Split-Path $localPath -Parent
    if (-not (Test-Path $localDir)) {
        New-Item -ItemType Directory -Path $localDir -Force | Out-Null
    }
    
    Write-Host "Copying: $file"
    try {
        # Use native scp command with control socket
        $scpArgs = @(
            "-o", "ControlPath=$controlPath"
            "${RemoteUser}@${RemoteHost}:${file}"
            $localPath
        )
        
        $process = Start-Process -FilePath "scp" -ArgumentList $scpArgs -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "Success: Copied to $localPath" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "Failed to copy file. Exit code: $($process.ExitCode)" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error copying file: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Clean up the control socket
$sshArgs = @(
    "-O", "exit"
    "-o", "ControlPath=$controlPath"
    "${RemoteUser}@${RemoteHost}"
)
Start-Process -FilePath "ssh" -ArgumentList $sshArgs -Wait -NoNewWindow

Write-Host "Transfer complete. Successfully copied $successCount out of $totalFiles files."
Write-Host "Files are in: $outputDir" 