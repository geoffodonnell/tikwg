[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [string] $Path,
    [Parameter(Position = 1, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $User,
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

    Write-Verbose -Message "Executed ssh command, result:`n$result "

    if ($LASTEXITCODE -ne 0) {
        Write-Error -Message "ssh exited with code '$LASTEXITCODE': $result"
    }

    return $result
}

Function Invoke-ScpUpload {
    [CmdletBinding()]
    param (
        [string] $User,
        [string] $HostName,
        [string] $SourcePath,
        [string] $DestinationPath
    )

    $exe = "scp";
    $arg0 = $SourcePath;
    $arg1 = [System.String]::IsNullOrWhiteSpace($User) ? "$($HostName):$DestinationPath" : "$($User)@$($HostName):$DestinationPath";

    Write-Verbose -Message "Executing scp command, copy $arg0 tp $arg1"

    $result = & $exe $arg0 $arg1
    $result = [System.String]::Join("`r`n", $result ?? @());

    Write-Verbose -Message "Executed scp command, result:`n$result "

    if ($LASTEXITCODE -ne 0) {
        Write-Error -Message "scp exited with code '$LASTEXITCODE': $result"
    }

    return $result
}

# Main script
$ENVIRONMENT_FILE_NAME = "tikwg-env"
$HOST_DIRECTORY = "tikwg"

$scriptDirectory = Join-Path -Path $PSScriptRoot -ChildPath "script"
$stagingDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "tikwg"

## Create temporary directory
if (Test-Path -Path $stagingDirectory -ErrorAction Continue) {
    Get-ChildItem -Path $stagingDirectory | Remove-Item -Recurse -Force
} else {
    New-Item -Path $stagingDirectory -ItemType Directory | Out-Null
}

## Read in configuration file
$configuration = & $PSScriptRoot\lib\Read-ConfigFile.ps1 -Path $Path

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

Invoke-ScpUpload -User $User -HostName $HostName -SourcePath $envFile -DestinationPath "/$ENVIRONMENT_FILE_NAME" -ErrorAction Stop | Out-Null

### Execute preflight script
$id = [System.Guid]::NewGuid().ToString().Split("-")[4]
$preflight = Join-Path -Path $scriptDirectory -ChildPath "preflight.rsc"

Invoke-Ssh -User $User -HostName $HostName -Command "/file add type=directory name=$id" -ErrorAction Stop | Out-Null
Invoke-ScpUpload -User $User -HostName $HostName -SourcePath $preflight -DestinationPath "/$id/preflight.rsc" -ErrorAction Stop | Out-Null
Invoke-Ssh -User $User -HostName $HostName -Command "/import $id/preflight.rsc; /file remove `"$id`";" -ErrorAction Stop | Out-Null

### Copy files from staging directory onto device
Get-ChildItem -Path $stagingDirectory | ForEach-Object {
    Invoke-ScpUpload -User $User -HostName $HostName -SourcePath "$($_.FullName)" -DestinationPath "/$HOST_DIRECTORY/$($_.Name)" -ErrorAction Stop | Out-Null
}

### Execute install script
Invoke-Ssh -User $User -HostName $HostName -Command "/import $HOST_DIRECTORY/install.rsc;" -ErrorAction Stop | Out-Null

## Cleanup temporary files
Remove-Item -Path $stagingDirectory -Recurse -Force
Remove-Item -Path $envFile