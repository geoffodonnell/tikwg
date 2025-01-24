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
    [string] $WanInterfaceName = "ether1"
)

# SEE: https://protonvpn.com/support/wireguard-mikrotik-routers/

# addr [/ip address get [find interface="bridge1"] address]
# /interface enable [/interface find name="wireguard-inet"]
# /interface disable [/interface find name="wireguard-inet"]
# :put [/interface get [/interface find type="wg"]

Function Get-AddPeersCommand {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [object] $Peer
    )
    
    Begin {
        $result = @()
    }

    Process {
        $allowedIPs = $peer.AllowedIPs;
        $endpoint = $peer.Endpoint.Split(":");
        $endpointAddress = $endpoint[0];
        $endpointPort = $endpoint[1];

        $result += "/interface wireguard peers add allowed-address=$allowedIPs endpoint-address=$endpointAddress endpoint-port=$endpointPort interface=`"`$ifaceName`" persistent-keepalive=25s comment=`"ProtonVPN`" public-key=`"$($Peer.PublicKey)`"`n"
    }

    End {
        return ($result -join "`n");
    }
}

Function Get-AddRouteToPeersCommand {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [object] $Peer
    )
    
    Begin {
        $result = @()
    }

    Process {
        $endpoint = $peer.Endpoint.Split(":");
        $endpointAddress = $endpoint[0];

        $result += "/ip route add disabled=no dst-address=$endpointAddress/32 gateway=[/ip route get [find dst-address=0.0.0.0/0] gateway] routing-table=main suppress-hw-offload=no`n"
    }

    End {
        return ($result -join "`n");
    }
}

## Main Script

# Read in configuration file
$configuration = .$PSScriptRoot\Read-ConfigFile.ps1 -Path $Path

# Extract values from configuration
$privateKey = $configuration.Interface.PrivateKey;
$ipAddress = $configuration.Interface.Address.Split("/")[0];
$network = $ipAddress.Substring(0, $ipAddress.Length - 1) + "0";
$dns = $configuration.Interface.DNS;

# Create installation commands
$script = "{`n";
$script += ":local ifaceName `"$InterfaceName`"`n"
$script += ":local lanIfaceName `"$LanInterfaceName`"`n"
$script += ":local wanIfaceName `"$WanInterfaceName`"`n"
$script += ":local privateKey `"$privateKey`"`n"
$script += ":local ipAddress `"$ipAddress/30`"`n"
$script += ":local network `"$network`"`n"
$script += ":local gateway `"$dns`"`n"

## Add wg interface
$script += "/interface wireguard add listen-port=13231 mtu=1420 name=`"`$ifaceName`" private-key=`"`$privateKey`"`n";

## Add wg IP address
$script += "/ip address add address=`$ipAddress interface=`"`$ifaceName`" network=`$network`n";

## Add peer(s)
$script += ($configuration.Peers | Get-AddPeersCommand);

## Add NAT rule
$script += "/ip firewall nat add action=masquerade chain=srcnat out-interface=`"`$ifaceName`" src-address=[/ip address get [find interface=`"`$lanIfaceName`"] address]`n";

## Add routes
$script += "/ip route add disabled=no distance=1 dst-address=0.0.0.0/1 gateway=`$gateway pref-src=`"`" routing-table=main scope=30 suppress-hw-offload=no target-scope=10`n";
$script += "/ip route add disabled=no distance=1 dst-address=128.0.0.0/1 gateway=`$gateway pref-src=`"`" routing-table=main scope=30 suppress-hw-offload=no target-scope=10`n";

## Set DNS
$script += "/ip dns set servers=`$gateway`n";

## Update DHCP
$script += "/ip dhcp-client set [find interface=`"`$wanIfaceName`"] use-peer-dns=no`n";

## Add route to peer(s)
$script += ($configuration.Peers | Get-AddRouteToPeersCommand);

## Add firewall filter rule
$script += "/ip firewall filter add chain=`"forward`" in-interface=`"`$ifaceName`" connection-state=`"new`" connection-nat-state=`"!dstnat`" action=`"drop`" comment=`"Drop incoming packets that are not NAT'd`"`n";

$script += "}`n"

Write-Verbose -Message @"
====
$script
====
"@

Set-Content -Path .\tmp.rsc -Value $script

#ssh ("$($User)@$($HostName)") $script