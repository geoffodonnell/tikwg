[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $User = "admin",
    [Parameter(Position = 1, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $HostName = "router.localdomain"
)

# SEE: https://protonvpn.com/support/wireguard-mikrotik-routers/

$ENVIRONMENT_FILE_NAME = "tikwg-env"

# Get the installation directory from the environment file on the device
$tikwgEnvAsJson = ssh $HostName ":put [/file get [find name=`"$ENVIRONMENT_FILE_NAME`"] contents]"
$tikwgEnv = $tikwgEnvAsJson | ConvertFrom-Json
$hostDirectory = $tikwgEnv.directory;

### Execute install script
ssh $HostName "/import $hostDirectory/uninstall.rsc;"