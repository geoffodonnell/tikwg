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

    :local fileName "$dirName/config"
    :local config

    ## Read configuration file
    :onerror e in={
        :set config [:deserialize [/file get [find name=$fileName] contents] from=json options=json.no-string-conversion]
    } do={
        :error "Failure reading configuration file '$fileName'"
    }

    :local ifaceName [($config->"interface")]
    :local gateway ($config->"gateway")
    :local checkDomain ($config->"checkDomain")

    ## Inspect interface
    :local exists true
    :local running false
    
    :onerror e in={
        :set running [/interface wireguard get [find name=$ifaceName] running]
    } do={
        :set exists false
    }

    :if ($running) do={
        :put "Interface: Running ($ifaceName)"
    } else={
        if (!$exists) do={
            :put "Interface: does NOT exist ($ifaceName)"

        } else={
            :put "Interface: NOT Running ($ifaceName)"
        }

        :error "Quitting. Interface error."
    }

    ## Perform ping
    :local ping [:ping 8.8.8.8 count=4 interface=$ifaceName as-value]

    :if ($ping->0->"status" = "timeout" || $ping->1->"status" = "timeout"|| $ping->2->"status" = "timeout" || $ping->3->"status" = "timeout") do={
        [/terminal style error]
        :put "Ping: FAILED"
        [/terminal style none]
    } else={
        :local avg 0
        :foreach try in=$ping do={
            :set avg ($avg + ($try->"time"))
        }
        :set avg ($avg / [:len $ping])
        :local out 0
        :set out (([:tonum [:pick $avg 6 8]] * 1000) + \
                   [:tonum [:pick $avg 9 12]])
        :put "Ping: Success, average: $($out)ms"
    }

    ## Test DNS
    :local dns false
    :local resolved ""
    :onerror e in={
        :set resolved [resolve server=$gateway domain-name=$checkDomain]
        :put "DNS: Success, resolved $checkDomain to $resolved"
    } do={
        [/terminal style error]
        :put "DNS: FAILED, error: $e"
        [/terminal style none]
    }
}