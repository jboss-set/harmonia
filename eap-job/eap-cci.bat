@echo off

REM Set the environment variables for Maven and Java
set "JAVA_HOME=%JDK_PATH%"
set "PATH=%PATH%;%JAVA_HOME%\bin"

echo Expand all .zip files in the current directory
for %%F in (*.zip) do (
    powershell -Command "Expand-Archive -Path '%%~F' -DestinationPath 'eap' -Force"
)

cd eap\eap-sources

REM Set the testsuite command
set "COMMAND=mvn clean install -Djboss.dist=%WORKSPACE%\eap\jboss-eap-%EAP_VERSION% -DallTests -D%ip%"

echo Running testsuite command: %COMMAND%

REM Execute the testsuite command
%COMMAND%

REM Check if the build was successful or not
IF %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    exit /b %ERRORLEVEL%
)

echo Build successful!