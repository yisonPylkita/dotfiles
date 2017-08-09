function prompt { 
    Write-Host "$((Get-Item -Path "./" -Verbose).FullName)>" -nonewline -foregroundcolor Green
    return " "
}

