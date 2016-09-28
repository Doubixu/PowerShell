# eastmoney public tools
# version: v1.0.2
# create by XuHoo, 2016-9-27
#


try {
    Import-Module ServerManager -ErrorAction Stop
    Import-Module BitsTransfer -ErrorAction Stop
}
catch {
    Write-Warning "$_"; exit
}

$packages_path = "D:\software"  # Packages storage directory

function Download() {
    $isExists = Test-Path $packages_path
    if(!$isExists) {
        New-Item -ItemType Directory $packages_path
    }
    # instantiate a socket object,
    # Try connect to download the source
    $testConn = New-Object Net.Sockets.TcpClient
    $testConn.Connect("$address", 80)  # $address need to custom
    if($testConn) {
        Start-BitsTransfer $address/dotnet4.0.exe $packages_path
        Start-BitsTransfer $address/dotnet4.5.exe $packages_path
        return $true
    } else {
        return $false
    }
}

function CheckVersion {
    # To detect the .NET Framework whether exists in the registry
    $isExists = Test-Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\"
    if(!$isExists) {
        return $false
    } else {
        # Returns the current .NET Framework version
        $version = gci "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP" | sort pschildname -desc | select -fi 1 -exp pschildname
        return $version
    }
}

function Update {
    Add-WindowsFeature As-Net-Framework  # Update .NET Framework 3.5
    # The first cycle:
    #   Perfrom CheckVersion function, returns the value assigned to $response
    #   If $response < 4.0, start install dotnet 4.0 and dotnet 4.5
    #   Enter the second loop
    # The second cycle:
    #   Again to perfrom CheckVersion function
    #   If the installation is successful,
    #   the value of variable $response at this time will be greater than 4.0,
    #   the output corrent .NET Framework version and returns $true
    for($i=0;$i -lt 2;$i++) {
        $response = CheckVersion
        if($response -lt "v4.0") {
            Start-Process -Wait $packages_path\dotnet4.0.exe -ArgumentList "/quiet"
            Start-Process -Wait $packages_path\dotnet4.5.exe -ArgumentList "/quiet"
        } else {
            Write-Host "DotNET current version is: $response"
            return $true
        }
    }
    # Above cycle without entering the return statement,
    # then .NET Framework update failed, this function will return the $false
    return $false
}

function Install {
    $features = Get-WindowsFeature Web-Server,Web-Static-Content,Web-Default-Doc,Web-Http-Errors,Web-Http-Redirect,Web-Asp-Net,Web-Net-Ext,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Http-Logging,Web-Request-Monitor,Web-Filtering,Web-IP-Security,Web-Stat-Compression,Web-Mgmt-Console,Web-WHC
    # Install IIS features
    foreach($item in $features) {
        Add-WindowsFeature $item
    }
    Remove-WindowsFeature Web-Dir-Browsing  # Delete "Web-Dir-Browsing" function
}

function Registry {
    $is64bit = [IntPtr]::Size -eq 8  # To determine whether a system is 64-bit
    $isapiPath_32 = "$env:windir\Microsoft.NET\Framework\v4.0.30319\aspnet_isapi.dll"
    Set-Location "$env:windir\Microsoft.NET\Framework\v4.0.30319\"; .\aspnet_regiis.exe -i
    if($is64bit) {
        $isapiPath_64 = "$env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll"
        Set-Location "$env:windir\Microsoft.NET\Framework64\v4.0.30319\"; .\aspnet_regiis.exe -i
    }
}

try {
    $chkGet_result = Download
    $chkUp_result = Update
    if($chkUp_result) {
        Install; Registry
    } else {
        Write-Warning "Update .NET Framework error."
    }
}
catch {
    Write-Warning "$_"; exit
}
finally {
    Remove-Item $packages_path -Recurse
    Remove-Item $MyInvocation.MyCommand.Path -Force
}
