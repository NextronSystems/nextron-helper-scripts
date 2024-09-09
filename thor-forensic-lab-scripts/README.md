# Thor Forensic Lab Scripts

This folder provides a collection of community-created scripts to automate everyday commands used with Thor using the Forensic Lab license.

## Scripts by [Andrew Rathbun](https://github.com/AndrewRathbun):

For each of these scripts and their examples, the following should be established to better understand what each script is looking for:

* `C:\temp\KapeTriage\tout` emulates a location where loose artifacts are collected and waiting to be processed. Think of this like running KAPE against a mounted image or a live system, and these are the raw artifacts that were acquired from that. `tout` is short for Target Output, which is simply where target files are collected and stored for further processing. Usually, a command similar to `.\kape.exe --tsource C: --tdest C:\temp\KapeTriage\tout --tflush --target KapeTriage --debug --gui` is implied for the below examples.
* `C:\temp\KapeTriage` is provided for output paths in the below example because scripts tasked with scanning files and/or mounted images will create a child folder to the path provided, similar to `C:\temp\KapeTriage\Thor`. So when `C:\temp\KapeTriage` is passed, I'm really passing it with the intent for `C:\temp\KapeTriage\Thor` as my final destination for the script output.

The following scripts are provided by [Andrew Rathbun](https://github.com/AndrewRathbun) from his [DFIRPowerShellScripts](https://github.com/AndrewRathbun/DFIRPowerShellScripts/tree/main/ThorScriptshttps://github.com/AndrewRathbun/DFIRPowerShellScripts/tree/main/ThorScripts) repo:

* `Invoke-ThorScanMountedImage.ps1`
* `Invoke-ThorScanOfflineFiles.ps1`
* `Invoke-ThorUpgrade.ps1`
* `Invoke-ThorUtilConvertLogToCSV.ps1`
* `Scan-MFTECmdMFTThor.ps1`

If there are any questions or issues, please create an Issue on the [DFIRPowerShellScripts](https://github.com/AndrewRathbun/DFIRPowerShellScripts/tree/main/ThorScriptshttps://github.com/AndrewRathbun/DFIRPowerShellScripts/tree/main/ThorScripts) repo.

### Invoke-ThorScanMountedImage.ps1

This script is meant to be used against a mounted forensic image (`E01`, `VMDK`, `VHDX`, etc). Use Arsenal Image Mounter (or similar) to mount a forensic image, then feed the script the drive letter of the partition you want to scan, and then provide the script with an output path where you want your Thor scan output and log files to go.

There are two ways to run this script:

1. Run the script without arguments and feed the script values for the mandatory parameters
    * Example: In PowerShell, run: `.\Invoke-ThorScanMountedImage.ps1`
    * When prompted for `DriveLetter`, provide the drive letter only with no colon or backslash: `D`
    * When prompted for `OutputPath`, provide the desired path for scan and log file output: `C:\temp\ThorScanResults`
    * Please note, this script will automatically add a `\Thor` folder to whatever output path you provide, so if you add one yourself, you'll end up with `C:\temp\ThorScanResults\Thor\Thor`

2. Run the script by passing values to the parameters of interest
    * Example: In PowerShell, run: `.\Invoke-ThorScanMountedImage.ps1 -DriveLetter D -OutputPath C:\temp\ThorScanResults`

Once scanning has completed, Thor will convert the `.txt` log file output into CSV using `Invoke-ThorUtilConvertLogToCSV.ps1`

### Invoke-ThorScanOfflineFiles.ps1

This script is meant to be used against loose forensic artifacts (KapeTriage packages, loose raw artifacts, etc). 

There are two ways to run this script:

1. Run the script without arguments and feed the script values for the mandatory parameters
    * Example: In PowerShell, run: `.\Invoke-ThorScanOfflineFiles.ps1`
    * When prompted for `Target`, provide the drive letter only with no colon or backslash: `C:\temp\KapeTriage\tout`
    * When prompted for `OutputPath`, provide the desired path for scan and log file output: `C:\temp\KapeTriage`
    * Please note, this script will automatically add a `\Thor` folder to whatever output path you provide, so if you add one yourself, you'll end up with `C:\temp\KapeTriage\Thor\Thor`
2. Run the script by passing values to the parameters of interest
    * Example: In PowerShell, run: `.\Invoke-ThorScanOfflineFiles.ps1 -Target C:\temp\KapeTriage\tout -OutputPath C:\temp\KapeTriage`

Once scanning has completed, Thor will convert the `.txt` log file output into CSV using `Invoke-ThorUtilConvertLogToCSV.ps1`

### Invoke-ThorUpgrade.ps1

This script is meant to automate the admittedly simple process of ensuring the Thor binary and Thor signature files are updated to their latest versions using `thor-util.exe`. This script only needs to be ran without arguments as there are no parameters.

### Invoke-ThorUtilConvertLogToCSV.ps1

This script is meant to automate the conversion of `.txt` Thor log files into CSV output for easy ingestion into Excel, Timeline Explorer, Modern CSV, etc. This script is automatically called upon by `Invoke-ThorScanMountedImage.ps1` and `Invoke-ThorScanOfflineFiles.ps1`, but can also be utilized independently from those scripts. 

There are two ways to run this script:

1. Run the script without arguments and feed the script values for the mandatory parameters
    * Example: In PowerShell, run: `.\Invoke-ThorUtilConvertLogToCSV.ps1`
    * When prompted for `Target`, provide the drive letter only with no colon or backslash: `C:\temp\KapeTriage\Thor`
2. Run the script by passing values to the parameters of interest
    * Example: In PowerShell, run: `.\Invoke-ThorUtilConvertLogToCSV.ps1 -Target C:\temp\KapeTriage\Thor`

### Scan-MFTECmdMFTThor.ps1

This script is meant to automate the processing of `$MFT` files into bodyfile format, then changing the forward slashes with backwards slashes, and finally changing the file extension from `.bodyfile` to `.log` to trigger the LogScan Module in Thor. This essentially allows you to scan the contents of an `$MFT` against Thor's IOCs and rulesets. This can be very helpful to hit on filename IOCs!

There are two ways to run this script:

1. Run the script without arguments and feed the script values for the mandatory parameters
    * Example: In PowerShell, run: `.\Scan-MFTECmdMFTThor.ps1`
    * When prompted for `TargetFolder`, provide the drive letter only with no colon or backslash: `C:\temp\KapeTriage\tout`
2. Run the script by passing values to the parameters of interest
    * Example: In PowerShell, run: `.\Scan-MFTECmdMFTThor.ps1 -Target C:\temp\KapeTriage\Thor`
    