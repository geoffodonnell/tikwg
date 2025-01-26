[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [string] $Path,
    [Parameter(Position = 1, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $User = "admin",
    [Parameter(Position = 2, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $HostName = "router.localdomain",
    [Parameter(Position = 3, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $InterfaceName = "wg0",
    [Parameter(Position = 4, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $LanInterfaceName = "bridge",
    [Parameter(Position = 5, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $WanInterfaceName = "ether1",
    [Parameter(Position = 6, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $CheckDomain = "mikrotik.com"
)

# SEE: https://protonvpn.com/support/wireguard-mikrotik-routers/

# Main script
$ENVIRONMENT_FILE_NAME = "tikwg-env"
$HOST_DIRECTORY = "tikwg"

$scriptDirectory = Join-Path -Path $PSScriptRoot -ChildPath "script"
$stagingDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "tikwg"

## Create temporary directory
if (Test-Path -Path $stagingDirectory -ErrorAction Continue) {
    Get-ChildItem -Path $stagingDirectory | Remove-Item -Recurse -Force
} else {
    New-Item -Path $stagingDirectory -ItemType Directory
}

## Read in configuration file
$configuration = & $PSScriptRoot\Read-ConfigFile.ps1 -Path $Path

## Save the configuration as JSON for install script
$configuration | `
    ConvertTo-Json | `
    Set-Content -Path (Join-Path -Path $stagingDirectory -ChildPath "install.json")

## Extract values from configuration
$gateway = $configuration.Interface.DNS;

## Copy static scripts
Copy-Item -Path (Join-Path -Path $scriptDirectory -ChildPath "install.rsc") -Destination $stagingDirectory
Copy-Item -Path (Join-Path -Path $scriptDirectory -ChildPath "uninstall.rsc") -Destination $stagingDirectory
Copy-Item -Path (Join-Path -Path $scriptDirectory -ChildPath "status.rsc") -Destination $stagingDirectory

## Copy configuration file
@{
    interface = $InterfaceName;
    lanInterface = $LanInterfaceName;
    wanInterface = $WanInterfaceName;
    gateway = $gateway;
    checkDomain = $CheckDomain
} | ConvertTo-Json | Set-Content -Path (Join-Path -Path $stagingDirectory -ChildPath "config")

## Run scripts on device

### Create the environment file
$envFile = New-TemporaryFile

@{
    directory = "$HOST_DIRECTORY"
} | ConvertTo-Json | Set-Content -Path $envFile

scp "$envFile" "$($HostName):/$ENVIRONMENT_FILE_NAME"

Remove-Item -Path $envFile

### Execute preflight script
$id = [System.Guid]::NewGuid().ToString().Split("-")[4]
$preflight = Join-Path -Path $scriptDirectory -ChildPath "preflight.rsc"

ssh $HostName "/file add type=directory name=$id"
scp "$preflight" "$($HostName):/$id/preflight.rsc"
ssh $HostName "/import $id/preflight.rsc; /file remove `"$id`""

### Copy files from staging directory onto device
Get-ChildItem -Path $stagingDirectory | ForEach-Object {
    scp "$($_.FullName)" "$($HostName):/$HOST_DIRECTORY/$($_.Name)"
}

### Execute install script
ssh $HostName "/import $HOST_DIRECTORY/install.rsc;"