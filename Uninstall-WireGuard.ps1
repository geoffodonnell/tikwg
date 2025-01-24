[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $User = "admin",
    [Parameter(Position = 1, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $HostName = "router.localdomain",
    [Parameter(Position = 2, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $InterfaceName = "wg0",
    [Parameter(Position = 3, Mandatory = $false, ValueFromPipeline = $false)]
    [string] $WanInterfaceName = "ether1"
)

# SEE: https://protonvpn.com/support/wireguard-mikrotik-routers/

Function Format-MultiLineCommand {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [string] $Value
    )

    $result = $Value.Replace("`r`n", ";")
    $result = $result.Replace("`r", ";")
    $result = $result.Replace("`n", ";")

    return $result
}

$setInterfaceName = ":global interfaceName [/interface get [find name=`"$InterfaceName`"] name]"

$removeRouteToPeers = ":foreach i in=[/interface wireguard peers find] do={
    :local addr [/interface wireguard peers get `$i `"endpoint-address`"]
    /ip route remove [find dst-address=`"`$addr/32`"]
 }" | Format-MultiLineCommand

$resetDhcp = "/ip dhcp-client set [find interface=`"$WanInterfaceName`"] use-peer-dns=yes"
$resetDns = "/ip dns set servers=`"`""

$removeRoute2 = "/ip route remove [find dst-address=128.0.0.0/1]"
$removeRoute1 = "/ip route remove [find dst-address=0.0.0.0/1]"

$removeNat = "/ip firewall nat remove [find out-interface=`$interfaceName]"

$removePeers = ":foreach i in=[/interface wireguard peers find interface=`"$InterfaceName`"] do={
    /interface wireguard peers remove `$i
 }" | Format-MultiLineCommand

$removeIpAddress = "/ip address remove [find interface=`$interfaceName]"
$removeInterface = "/interface wireguard remove [find name=`$interfaceName]"

$command = @"
$setInterfaceName
$removeRouteToPeers
$resetDhcp
$resetDns
$removeRoute2
$removeRoute1
$removeNat
$removePeers
$removeIpAddress
$removeInterface
"@

$command

ssh ("$($User)@$($HostName)") $command