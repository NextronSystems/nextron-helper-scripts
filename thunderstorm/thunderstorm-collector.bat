@ECHO OFF
SETLOCAL EnableDelayedExpansion

:: ----------------------------------------------
:: THOR Thunderstorm Collector
:: Windows Batch
:: Florian Roth
:: v0.1
:: 
:: A Windows Batch script that uses a compiled curl for Windows 
:: to upload files to a THOR Thunderstorm server
::
:: Requirements:
:: Curl for Windows (place ./bin/curl.exe from the package into the script folder)
:: https://curl.haxx.se/windows/
::
:: Note on OLD Windows versions
:: The latest version of curl that works with Windows 2003 and earlier is 
:: v7.46.0 and can be still be downloaded from here: 
:: https://bintray.com/vszakats/generic/download_file?file_path=curl-7.46.0-win32-mingw.7z

:: Configuration
:: The thunderstorm server host name (fqdn) or IP
SET THUNDERSTORM_SERVER=ygdrasil.nextron
SET THUNDERSTORM_PORT=8080
:: Use http or https
SET URL_SCHEME=http

:: The directory that should be walked
SET COLLECT_DIR="C:\"
:: The pattern of files to include
SET COLLECT_PATTERN=*.*
:: Maximum file size to collect (in bytes) (defualt: 3MB)
SET /A COLLECT_MAX_SIZE=3000000
:: Maximum file age in days (default: 7300 days = 20 years)
SET /A MAX_AGE=3

:: Debug
SET DEBUG=0

ECHO =============================================
ECHO  THOR Thunderstorm Batch Collector
ECHO =============================================
ECHO. 

:: Requirements Check
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

:: Directory walk and upload
ECHO Processing %COLLECT_DIR% with filters PATTERN: %COLLECT_PATTERN% MAX_SIZE: %COLLECT_MAX_SIZE% MAX_AGE: %MAX_AGE% days
ECHO This could take a while depending on the disk size and number of files. (set DEBUG=1 to see all skips)
FOR /R %COLLECT_DIR% %%F IN (%COLLECT_PATTERN%) DO (
    :: If the folder is empty (root directory), add extra characters
    SETLOCAL 
    IF "%%~pF"=="\" (
        SET FOLDER=%%~dF%%~pF\\
    ) ELSE (
        SET FOLDER=%%~dF%%~pF
    )
    :: Walk through files
    FORFILES /P "!FOLDER:~0,-1!" /M "%%~nF%%~xF" /D -%MAX_AGE% >nul 2>nul && (
        :: File is too old
        IF %DEBUG% == 1 ECHO Skipping %%F due to age ...
    ) || (
        :: File Size Check 
        IF %%~zF GTR %COLLECT_MAX_SIZE% (
            :: File is too big
            IF %DEBUG% == 1 ECHO Skipping %%F due to big file size ...
        ) ELSE (
            :: Upload
            ECHO Uploading %%F ..
            :: We'll start the upload process in background to speed up the submission process 
            START /B curl -F file=@%%F ^
            -H "Content-Type: multipart/form-data" ^
            -o nul ^
            -s ^
            %URL_SCHEME%://%THUNDERSTORM_SERVER%:%THUNDERSTORM_PORT%/api/checkAsync
        )
    )
    ENDLOCAL
)
