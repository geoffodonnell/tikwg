{
    :local envName "tikwg-env"
    :local dirName "tikwg"
    :local tikwg

    :put "Executing preflight script"

    ## Read root configuration file
    :onerror e in={
        :set tikwg [:deserialize [/file get [find name=$envName] contents] from=json options=json.no-string-conversion]
    } do={
        :error "Failure reading configuration file '$envName', this file is required for installation."
    }

    :if ([:typeof ($tikwg->"directory")] = "str") do={
        :set name=dirName value=($tikwg->"directory")
    }

    # Create directory if none exists
    {
        # Check for file
        :onerror errorName in={
            :if ([/file get [find type="file" name=$dirName] name] = $dirName) do={            
                :error "An existing file is named '$dirName', either remove the file or update the 'dirName' variable in this script."
            }
        } do={ 
            if ($errorName = "no such item") do={
                # Do nothing - happy path means nothing was found
            } else={
                :error "$errorName"
            }
        }

        # Check for directory
        :onerror errorName in={
            :if ([/file get [find type="directory" name=$dirName] name] = $dirName) do={            
                # Do nothing
            }
        } do={ 
            if ($errorName = "no such item") do={
                /file add type=directory name=$dirName
                :put "Created directory `$dirName`"
            } else={
                :error "$errorName"
            }
        }
    }

    # Execute uninstall.rsc if neccessary
    {
        :onerror errorName in={
            :if ([/file get [find type="script" name="$dirName/uninstall.rsc"] name] = "$dirName/uninstall.rsc") do={   

                :onerror errorName in={
                    :put "Executing '$dirName/uninstall.rsc'"
                    /import "$dirName/uninstall.rsc"
                    :put "Executed '$dirName/uninstall.rsc'"
                } do={ 
                    :put "$errorName"
                }
            }
        } do={ 
            if ($errorName = "no such item") do={
                :put "No uninstall to execute, '$dirName/uninstall.rsc' not found"
            } else={
                :error "$errorName"
            }
        }
    }

    # Remove files in directory
    {
        :onerror errorName in={     
            :foreach file in=[/file find name~"$dirName/.*\$"] do={
                :local name [[/file get [find .id=$file] name]]
                /file remove $name
                :put "Deleted '$name'"
            }
        } do={ 
            :error "$errorName"
        }
    }
}