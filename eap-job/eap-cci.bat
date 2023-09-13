@echo off

echo Set the environment variables for Maven and Java
set "PATH=%M2_HOME%\bin;%JAVA_HOME%\bin;%PATH%"

echo Expand all .zip files in the current directory
for %%F in (*.zip) do (
    powershell -Command "Expand-Archive -Path '%%~F' -DestinationPath 'eap' -Force"
)

REM Check if EAP_VERSION is set
IF "%EAP_VERSION%"=="" (
    echo EAP_VERSION is not set!
    exit /b 1
)

REM Where JBoss EAP stores
cd eap\eap-sources

REM Printing all the variables
echo Workspace is: %WORKSPACE%
echo EAP version is: jboss-eap-%EAP_VERSION%
echo Current ip version is: %ip%

REM Set the testsuite command
set "COMMAND=mvn clean install -fae -Djboss.dist=%WORKSPACE%\eap\jboss-eap-%EAP_VERSION% -DallTests -DfailIfNoTests=false -D%ip%"

echo Running testsuite command: %COMMAND%

echo Executing the testsuite
%COMMAND%

REM Check if the build was successful or not
IF %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    exit /b %ERRORLEVEL%
)

echo Build successful!