[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [object] $Path
)

function Get-IniContent {

    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [object] $Path
    )

    $result = @{}

    switch -regex -file $Path {
        "^\[(.+)\]" { # Section
            $section = $matches[1]

            if ($null -eq $result[$section]) {
                $result[$section] = @{}
            } elseif ($result[$section] -is [array]) {
                $result[$section] += @{}
            } else {
                $result[$section] = @( $result[$section], @{} )
            }
            continue;
        }
        "^(;.*)$" { # Comment 
            #Ignore comments
            continue;
        }
        "^(#.*)$" { # Comment 
            #Ignore comments
            continue;
        }
        "(.+?)\s*=(.*)" { # Key
            if (!$section) { continue } # Skip keys outside sections
            $name, $value = $matches[1..2]
            #$result[$section][$name] = $value

            if ($result[$section] -is [array]) {
                $result[$section][$result[$section].Length - 1][$name] = $value.Trim()
            } else {
                $result[$section][$name] = $value.Trim()
            }
        }
    }
    return $result
}

Function ConvertTo-Array {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
        [object] $Object
    )

    Begin {
        $result = @()
    }

    Process {
        if ($null -eq $Object) {
            ## Do nothing
        } elseif ($Object -is [array]) {
            $Object | ForEach-Object {
                $result += $_
            }
        } else {
            $result += $Object
        }
    }

    End {
        return $result;
    }
}

if (-not (Test-Path -Path $Path)) {
    Write-Error -Message "Configuration file path not found" -ErrorAction Stop
}

$conf = Get-IniContent -Path $Path
$peers = $conf["Peer"] | ConvertTo-Array

Write-Output -InputObject @{
    Interface = $conf["Interface"]
    Peers = [Array]$peers
}