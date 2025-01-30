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

    $exe = "ssh";
    $arg0 = [System.String]::IsNullOrWhiteSpace($User) ? $HostName : "$User@$HostName";
    $arg1 = $Command

    Write-Verbose -Message "Executing ssh command `"$Command`""

    $result = & $exe $arg0 $arg1
    $result = [System.String]::Join("`r`n", $result ?? @());

    Write-Verbose -Message "Executed ssh command `"$Command`""

    if ($LASTEXITCODE -ne 0) {
        Write-Error -Message "ssh exited with code '$exitCode': $result"
    }

    return $result
}

$ENVIRONMENT_FILE_NAME = "tikwg-env"

# Get the installation directory from the environment file on the device
$tikwgEnvAsJson = Invoke-Ssh -User $User -HostName $HostName -Command ":put [/file get [find name=`"$ENVIRONMENT_FILE_NAME`"] contents]"
$tikwgEnv = $tikwgEnvAsJson | ConvertFrom-Json
$hostDirectory = $tikwgEnv.directory;

### Execute install script
Invoke-Ssh -User $User -HostName $HostName -Command "/import $hostDirectory/uninstall.rsc;"