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
    :local oldDnsfileName "$dirName/old-dns"
    :local config
    :local oldDns

    ## Read configuration file
    :onerror e in={
        :set config [:deserialize [/file get [find name=$configFileName] contents] from=json options=json.no-string-conversion]
        :set oldDns [/file get [find name=$oldDnsfileName] contents]
    } do={
        :error "Failure reading configuration file: '$e'"
    }

    :local ifaceName [($config->"interface")]
    :local lanIfaceName [($config->"lanInterface")]
    :local wanIfaceName [($config->"wanInterface")]
    :local gateway ($config->"gateway")

    # Sanity check - ensure the interface exists
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

    :if (!$interfaceExists) do={
        :error "Interface '$ifaceName' does not exists. Quitting."
    }

    # Remove filter rules
    /ip firewall filter remove [find out-interface=$ifaceName]

    # Remove route(s) to associated peer(s)
    :foreach i in=[/interface wireguard peers find] do={
        :local addr [/interface wireguard peers get $i "endpoint-address"]
        /ip route remove [find dst-address="$addr/32"]
    }

    # Try to update WAN DNS, if configured
    :onerror e in={
        /ip dhcp-client set [find interface="$wanIfaceName"] use-peer-dns=yes
    } do={
        if ($e = "no such item") do={
            # Do nothing - if WAN has a static IP, there won't be a DHCP client to update
        } else={
            :error "$errorName"
        }
    }

    # Reset DNS
    /ip dns set servers="$oldDns"

    # Remove routes
    /ip route remove [find dst-address=128.0.0.0/1]
    /ip route remove [find dst-address=0.0.0.0/1]

    # Remove masquerade rule
    /ip firewall nat remove [find out-interface=$ifaceName]

    # Remove peer(s)
    :foreach i in=[/interface wireguard peers find interface="wg0"] do={
        /interface wireguard peers remove $i
    }

    # Remove the IP address
    /ip address remove [find interface=$ifaceName]

    # Remove the interface
    /interface wireguard remove [find name=$ifaceName]
}