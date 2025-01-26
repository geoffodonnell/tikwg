{
    :local envName "tikwg-env"
    :local dirName "tikwg"
    :local tikwg

    ## Read root configuration file
    :onerror e in={
        :set tikwg [:deserialize [/file get [find name=$envName] contents] from=json options=json.no-string-conversion]
    } do={
        :error "Failure reading configuration file '$envName'"
    }

    :if ([:typeof ($tikwg->"directory")] = "str") do={
        :set name=dirName value=($tikwg->"directory")
    }
    
    :local configFileName "$dirName/config"
    :local installFileName "$dirName/install.json"
    :local config
    :local install

    ## Read configuration file
    :onerror e in={
        :set config [:deserialize [/file get [find name=$configFileName] contents] from=json options=json.no-string-conversion]
        :set install [:deserialize [/file get [find name=$installFileName] contents] from=json options=json.no-string-conversion]
    } do={
        :error "Failure reading configuration file: '$e'"
    }

    :local ifaceName [($config->"interface")]
    :local lanIfaceName [($config->"lanInterface")]
    :local wanIfaceName [($config->"wanInterface")]
    :local gateway ($config->"gateway")
    :local checkDomain ($config->"checkDomain")

    :local privateKey ($install->"Interface"->"PrivateKey")
    :local ipAddress
    
    :local len [:find ($install->"Interface"->"Address") "/"]
    :set ipAddress [:pick ($install->"Interface"->"DNS") 0 $len]
    :set ipAddress "$ipAddress/30"

    # Sanity check - ensure the interface isn't already configured
    :local interfaceExists true
    :onerror e in={
        :local found [/interface wireguard get [find name="$ifaceName"]]
        :set interfaceExists true
    } do={
        if ($e = "no such item") do={
            :set interfaceExists false
        } else={
            :error "$errorName"
        }
    }

    :if ($interfaceExists) do={
        :error "Interface '$ifaceName' already exists. Quitting."
    }

    # Add the interface
    /interface wireguard add listen-port=13231 mtu=1420 name="$ifaceName" private-key="$privateKey"

    # Add IP Address to interface
    /ip address add address=$ipAddress interface="$ifaceName" network=$network

    # Configure peer(s)
    :foreach record in=($install->"Peers") do={
        :local endpoint ($record->"Endpoint")
        :local publicKey ($record->"PublicKey")
        :local allowedIPs ($record->"AllowedIPs")

        :local idx [:find $endpoint ":"]
        :local len [:find $endpoint]
        :local ip [:pick $endpoint 0 idx]
        :local port [:pick $endpoint (idx + 1) $len]

        # Add peer
        /interface wireguard peers add allowed-address=$allowedIPs endpoint-address=$ip endpoint-port=$port interface="$ifaceName" persistent-keepalive=25s comment="ProtonVPN" public-key=$publicKey
    
        # Add route to peer
        /ip route add disabled=no dst-address="$ip/32" gateway=[/ip route get [find dst-address=0.0.0.0/0] gateway] routing-table=main suppress-hw-offload=no
    }

    # Add masquerade rule
    /ip firewall nat add action=masquerade chain=srcnat out-interface="$ifaceName" src-address=[/ip address get [find interface="$lanIfaceName"] address]
    
    # Add routes
    /ip route add disabled=no distance=1 dst-address=0.0.0.0/1 gateway=$gateway pref-src="" routing-table=main scope=30 suppress-hw-offload=no target-scope=10
    /ip route add disabled=no distance=1 dst-address=128.0.0.0/1 gateway=$gateway pref-src="" routing-table=main scope=30 suppress-hw-offload=no target-scope=10
    
    # Set DNS
    /ip dns set servers=$gateway
    
    # Try to update WAN DNS, if configured
    :onerror e in={
        /ip dhcp-client set [find interface="$wanIfaceName"] use-peer-dns=no
    } do={
        if ($e = "no such item") do={
            # Do nothing - if WAN has a static IP, there won't be a DHCP client to update
        } else={
            :error "$errorName"
        }
    }

    # Add rule to drop un-NAT'd packets
    /ip firewall filter add chain="forward" in-interface="$ifaceName" connection-state="new" connection-nat-state="!dstnat" action="drop" comment="Drop incoming packets that are not NAT'd"

    # Remove the install configuration file so the private key isn't hanging around
    /file remove $installFileName
}