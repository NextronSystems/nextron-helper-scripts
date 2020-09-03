@ECHO OFF
SETLOCAL EnableDelayedExpansion

REM Configuration
SET ASGARD_HOST=asgard.nextron-systems.com
SET API_KEY="not set"

ECHO =============================================
ECHO  Bulk License Generator for ASGARD v2
ECHO  Florian Roth v1.0, Win10 Version using Curl
ECHO =============================================
ECHO. 

IF %API_KEY% == "not set" (
    ECHO Error: No API key set. Open this batch file with a text editor and set your asgard host and api key in the configurtaion section. You can find your API Key in User Settings > API Key.
    EXIT /b 1
)

ECHO Remember that you can only generate license in bulk for servers OR workstations
SET /p answer="Do you want to generate licenses for workstations only? (y=workstations, n=servers) "
REM Default value is for server
SET type="server"
IF %answer% == "y" SET type="workstation"

IF NOT EXIST %CD%\hostnames.txt (
    ECHO Cannot find file hostnames.txt with the hostnames line seperated to generate licenses for.
    EXIT /b 1
)

FOR /F "tokens=*" %%A in (%CD%\hostnames.txt) DO (
    ECHO Generating license for %%A ...
    curl -X POST "https://%ASGARD_HOST%:8443/api/v0/licensing/issue" ^
    -H "accept: application/octet-stream" ^
    -H "Authorization: %API_KEY%" ^
    -H "Content-Type: application/x-www-form-urlencoded" ^
    -d "hostnames=%%A&type=%type%" ^
    -o %%A.lic -s
    ECHO [+] Successfully generated license for host %%A named %%A.lic
)

ECHO Bulk license generator finished. 
ECHO. 
