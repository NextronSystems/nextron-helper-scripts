@ECHO OFF
SETLOCAL EnableDelayedExpansion

:: ----------------------------------------------------------------
:: THOR Thunderstorm Collector
:: Windows Batch
:: Florian Roth
:: v0.3
:: 
:: A Windows Batch script that uses a compiled Curl for Windows 
:: to upload files to a THOR Thunderstorm server
::
:: Requirements:
:: Curl for Windows (place ./bin/curl.exe from the package into the script folder)
:: https://curl.haxx.se/windows/
::
:: Note on Windows 10
:: Windows 10 already includes a curl since build 17063, so all versions newer than 
:: version 1709 (Redstone 3) from October 2017 already meet the requirements
::
:: Note on very old Windows versions:
:: The last version of curl that works with Windows 7 / Windows 2008 R2 
:: and earlier is v7.46.0 and can be still be downloaded from here: 
:: https://bintray.com/vszakats/generic/download_file?file_path=curl-7.46.0-win32-mingw.7z

:: CONFIGURATION -------------------------------------------------

:: THUNDERSTORM SERVER -------------------------------------------
:: The thunderstorm server host name (fqdn) or IP
SET THUNDERSTORM_SERVER=ygdrasil.nextron
SET THUNDERSTORM_PORT=8080
:: Use http or https
SET URL_SCHEME=http

:: SELECTION -----------------------------------------------------

:: The directory that should be walked
SET COLLECT_DIRS=C:\Users C:\Temp C:\Windows
:: The pattern of files to include
SET RELEVANT_EXTENSIONS=.vbs .ps .ps1 .rar .tmp .bat .chm .dll .exe .hta .js .lnk .sct .vbs .war .jsp .jspx .php .asp .aspx .log .dmp .txt .jar .job
:: Maximum file size to collect (in bytes) (defualt: 3MB)
SET /A COLLECT_MAX_SIZE=3000000
:: Maximum file age in days (default: 7300 days = 20 years)
SET /A MAX_AGE=30

:: Debug
SET DEBUG=1

:: WELCOME -------------------------------------------------------

ECHO =============================================================
ECHO    ________                __            __                
ECHO   /_  __/ /  __ _____  ___/ /__ _______ / /____  ______ _  
ECHO    / / / _ \/ // / _ \/ _  / -_) __(_--/ __/ _ \/ __/  ' \ 
ECHO   /_/ /_//_/\_,_/_//_/\_,_/\__/_/ /___/\__/\___/_/ /_/_/_/ 
ECHO. 
ECHO   Windows Batch Collector
ECHO   Florian Roth, 2020
ECHO.
ECHO =============================================================
ECHO. 

:: REQUIREMENTS -------------------------------------------------
:: CURL in PATH
where /q curl.exe 
IF NOT ERRORLEVEL 1 (
    GOTO CHECKDONE
)
:: CURL in current directory
IF EXIST %CD%\curl.exe (
    GOTO CHECKDONE
)
ECHO Cannot find curl in PATH or the current directory. Download it from https://curl.haxx.se/windows/ and place curl.exe from the ./bin sub folder into the collector script folder. 
ECHO If you're collecting on Windows systems older than Windows Vista, use curl version 7.46.0 from https://bintray.com/vszakats/generic/download_file?file_path=curl-7.46.0-win32-mingw.7z
EXIT /b 1
:CHECKDONE
ECHO Curl has been found. We're ready to go. 

:: COLLECTION --------------------------------------------------

:: Directory walk and upload
ECHO Processing %COLLECT_DIRS% with filters MAX_SIZE: %COLLECT_MAX_SIZE% MAX_AGE: %MAX_AGE% days EXTENSIONS: %RELEVANT_EXTENSIONS% 
ECHO This could take a while depending on the disk size and number of files. (set DEBUG=1 to see all skips)
FOR %%T IN (%COLLECT_DIRS%) DO (
    SET TARGETDIR=%%T
    ECHo Checking !TARGETDIR! ...
    FOR /R C:\Users %%F IN (*.*) DO (
        SETLOCAL
        :: Marker if processed due to selected extensions
        SET PROCESSED=false
        :: Extension Check
        FOR %%E IN (%RELEVANT_EXTENSIONS%) DO (
            :: Check if one of the relevant extensions matches the file extension
            IF /I "%%~xF"=="%%E" (
                SET PROCESSED=true
                :: When the folder is empty (root directory) add extra characters
                IF "%%~pF"=="\" (
                    SET FOLDER=%%~dF%%~pF\\
                ) ELSE (
                    SET FOLDER=%%~dF%%~pF
                )
                :: File Size Check 
                IF %%~zF GTR %COLLECT_MAX_SIZE% (
                    :: File is too big
                    IF %DEBUG% == 1 ECHO Skipping %%F due to big file size ...
                ) ELSE (
                    :: Age check
                    FORFILES /P "!FOLDER:~0,-1!" /M "%%~nF%%~xF" /D -%MAX_AGE% >nul 2>nul && (
                        :: File is too old
                        IF %DEBUG% == 1 ECHO Skipping %%F due to age ...
                    ) || (
                        :: Upload
                        ECHO Uploading %%F ..
                        :: We'll start the upload process in background to speed up the submission process 
                        START /B curl -F file=@%%F -H "Content-Type: multipart/form-data" -o nul -s %URL_SCHEME%://%THUNDERSTORM_SERVER%:%THUNDERSTORM_PORT%/api/checkAsync
                    )
                )
            )
        )
        :: Note that file was skippe due to wrong extension
        IF %DEBUG% == 1 (
            IF !PROCESSED! == false ECHO Skipping %%F due to extension ...
        )
        ENDLOCAL
    )
)