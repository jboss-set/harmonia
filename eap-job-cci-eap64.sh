#!/bin/bash
set -e

echo 'Adjust Surefire memory settings (due to failures in JDK6)'
sed -i 's/-Duser.language=en<\/argLine>/-Duser.language=en -XX:MaxPermSize=256m<\/argLine>/g' pom.xml

echo -n "Building release artifacts..."

readonly EAP_RELEASE_NAME=${EAP_RELEASE_NAME:-'jboss-eap-6.4'}
readonly EAP_MAVEN_ARTIFACTS_ZIPFILE_NAME=${EAP_MAVEN_ARTIFACTS_ZIPFILE_NAME:-"${EAP_RELEASE_NAME}-maven-artifacts.zip"}
readonly EAP_MAVEN_SOURCES_ZIPFILE_NAME=${EAP_MAVEN_ARTIFACTS_ZIPFILE_NAME:-"${EAP_RELEASE_NAME}-src-prepared.zip"}
zip -qr "${EAP_MAVEN_ARTIFACTS_ZIPFILE_NAME}" ${EAP_LOCAL_MAVEN_REPO_FOLDER} 2>&1 > /dev/null
zip -qr "${EAP_MAVEN_SOURCES_ZIPFILE_NAME}" ${WORKSPACE} 2>&1 > /dev/null
echo 'Done.'
