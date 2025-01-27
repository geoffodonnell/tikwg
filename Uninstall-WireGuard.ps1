[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $User,
    [Parameter(Position = 1, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $HostName = "router.localdomain"
)

# SEE: https://protonvpn.com/support/wireguard-mikrotik-routers/

Function Invoke-Ssh {
    [CmdletBinding()]
    param (
        [string] $User,
        [string] $HostName,
        [string] $Command
    )

    if ([System.String]::IsNullOrWhiteSpace($User)) {
        return (ssh $HostName $Command);
    } else {
        return (ssh "$User@$HostName" $Command);
    }
}

$ENVIRONMENT_FILE_NAME = "tikwg-env"

# Get the installation directory from the environment file on the device
$tikwgEnvAsJson = Invoke-Ssh -User $User -HostName $HostName -Command ":put [/file get [find name=`"$ENVIRONMENT_FILE_NAME`"] contents]"
$tikwgEnv = $tikwgEnvAsJson | ConvertFrom-Json
$hostDirectory = $tikwgEnv.directory;

### Execute install script
Invoke-Ssh -User $User -HostName $HostName -Command "/import $hostDirectory/uninstall.rsc;"