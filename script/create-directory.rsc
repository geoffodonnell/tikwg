:local dirName "tikwg"

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
        } else={
            :error "$errorName"
        }
    }
}
