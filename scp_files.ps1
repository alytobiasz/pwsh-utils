<#
.SYNOPSIS
    Copies files from a Linux server to Windows using SCP with password authentication.

.DESCRIPTION
    This script reads a list of file paths from a text file and copies each file
    from a Linux server to a local Windows directory using SCP. It uses native
    PowerShell SSH commands for secure file transfer.

.PARAMETER SourceListPath
    Path to a text file containing Linux file paths (one per line)

.PARAMETER RemoteUser
    Username for the Linux server

.PARAMETER RemoteHost
    Hostname or IP address of the Linux server

.PARAMETER LocalDestination
    Local Windows directory where files will be copied to

.PARAMETER Password
    Password for the Linux server (will be prompted if not provided)

.EXAMPLE
    # Basic usage (will prompt for password):
    .\scp_files.ps1 `
        -SourceListPath "C:\path\to\file_list.txt" `
        -RemoteUser "username" `
        -RemoteHost "server.example.com" `
        -LocalDestination "C:\Downloads\files"

.EXAMPLE
    # Usage with password provided in command:
    $pass = ConvertTo-SecureString "your_password" -AsPlainText -Force
    .\scp_files.ps1 `
        -SourceListPath "C:\path\to\file_list.txt" `
        -RemoteUser "username" `
        -RemoteHost "server.example.com" `
        -LocalDestination "C:\Downloads\files" `
        -Password $pass

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
    [string]$RemoteHost,
    
    [Parameter(Mandatory=$true)]
    [string]$LocalDestination,
    
    [Parameter(Mandatory=$false)]
    [SecureString]$Password = (Read-Host -AsSecureString "Enter password")
)

# Create destination directory if it doesn't exist
if (-not (Test-Path $LocalDestination)) {
    New-Item -ItemType Directory -Path $LocalDestination | Out-Null
    Write-Host "Created destination directory: $LocalDestination"
}

# Read the list of files
$files = Get-Content $SourceListPath | Where-Object { $_.Trim() -ne "" }
$totalFiles = $files.Count
$successCount = 0

# Create PSCredential object
$username = $RemoteUser
$credentials = New-Object System.Management.Automation.PSCredential($username, $Password)

Write-Host "`nStarting transfer of $totalFiles files..."
Write-Host "Destination directory: $LocalDestination`n"

foreach ($file in $files) {
    $fileName = Split-Path $file -Leaf
    $localPath = Join-Path $LocalDestination $fileName
    
    Write-Host "Copying: $file"
    try {
        # Use native scp command with credentials
        $result = Get-SCPItem -ComputerName $RemoteHost `
                            -Credential $credentials `
                            -Path $file `
                            -Destination $localPath `
                            -ErrorAction Stop

        Write-Host "Success: Copied to $localPath" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "Error copying file: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Clear sensitive data
$credentials = $null
[System.GC]::Collect()

Write-Host "Transfer complete. Successfully copied $successCount out of $totalFiles files."
Write-Host "Files are in: $LocalDestination" 