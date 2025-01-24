:global tikwg
:local dirName "tikwg"

:put "Executing preflight script"

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
        :if ([/file get [find type="file" name="$dirName/uninstall.rsc"] name] = $dirName) do={            
            :put "Executing '$dirName/uninstall.rsc'"
            /import "$dirName/uninstall.rsc"
            :put "Executed '$dirName/uninstall.rsc'"
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