@echo off

echo Set the environment variables for Maven and Java
set "PATH=%M2_HOME%\bin;%JAVA_HOME%\bin;%PATH%"

echo Java version is
java -version

echo Maven version is
call mvn -v

echo Expand all .zip files in the current directory
for %%F in (*.zip) do (
    powershell -Command "Expand-Archive -Path '%%~F' -DestinationPath 'eap' -Force"
)

REM Check if EAP_VERSION is set
IF "%EAP_VERSION%"=="" (
    echo EAP_VERSION is not set!
    exit /b 1
)

REM Printing all the variables
echo Workspace is: %WORKSPACE%
echo EAP version is: jboss-eap-%EAP_VERSION%
echo Current ip version is: %ip%

REM Where JBoss EAP testsuite stores
cd eap\eap-sources

REM Check if %ip% is defined and run the testsuite accordingly
if "%ip%"=="ipv6" (
    echo Using IPv6
    REM delete hanging test case
    REM no IPv6 connection outside our infrastructure -> Maven repositories are not reachable inside the test case (IPv6 forced)
    del testsuite\integration\basic\src\test\java\org\jboss\as\test\integration\management\api\ClientCompatibilityUnitTestCase.java
    del testsuite\integration\basic\src\test\java\org\jboss\as\test\integration\xerces\unit\XercesUsageTestCase.java
    del testsuite\integration\basic\src\test\java\org\jboss\as\test\integration\xerces\ws\unit\XercesUsageInWebServiceTestCase.java
    cmd /c "mvn clean install -fae -DallTests -DfailIfNoTests=false -Dipv6"
) else (
    echo Using IPv4
    cmd /c "mvn clean install -fae -DallTests -DfailIfNoTests=false -Dipv4"
)

REM Check if the build was successful or not
IF %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    exit /b %ERRORLEVEL%
)

echo Build successful!