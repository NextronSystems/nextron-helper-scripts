# License retrieval script
# Florian Roth, June 2021

# ASGARD URL
$AsgardURL = "https://asgard.nextron-systems.com:8443/api/v0/licensing/issue"
$Token = "OJCBETq7VGLjrCes4k4ACCQOzg0AeAoz9Q"
$LicenseFile = "licenses.zip"
$OutputPath = ".\"
$ExtractLicenses = $True

# Config
# Ignore Self-signed certificates
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
# Set current working directory for .NET as well
[Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath

# Web Client
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$WebClient = New-Object System.Net.WebClient 
if ( $Token ) {
    $AsgardURL = [string]::Format("{0}?token={1}", $AsgardURL, $Token)
}
Write-Host "Using URL: $AsgardURL"

# Hostname
$Hostname = $env:COMPUTERNAME

# License Type
$LicenseType = "server"
$OsInfo = Get-CimInstance -ClassName Win32_OperatingSystem
if ( $osInfo.ProductType -eq 1 ) { 
    $LicenseType = "workstation"
}

# Proxy Support
$WebClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
$WebClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

# Prepare request
$postData=New-Object System.Collections.Specialized.NameValueCollection
$postData.Add('hostnames',$Hostname)
$postData.Add('type',$LicenseType)
Write-Host "Requesting license for HOST: $Hostname TYPE: $LicenseType"

# Request license
try {
    $Response = $WebClient.UploadValues($AsgardURL, $postData)
# HTTP Errors
} catch [System.Net.WebException] {
    Write-Host "The following error occurred: $_"
    $Response = $_.Exception.Response
    # 403
    if ( [int]$Response.StatusCode -eq 403 ) { 
        Write-Host "This can be caused by a missing download token."
    }
    break
}
[System.IO.File]::WriteAllBytes($LicenseFile, $Response);

# Extract licenses
if ( $ExtractLicenses ) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($LicenseFile, $OutputPath)
    } catch {
        Write-Host "The following error occurred: $_"
    }
    Remove-Item -Path $LicenseFile
}
