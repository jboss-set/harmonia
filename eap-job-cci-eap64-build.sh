#!/bin/bash
set -e

export HARMONIA_FOLDER=${HARMONIA_FOLDER:-"$(pwd)/harmonia/"}
export NO_ZIPFILES=${NO_ZIPFILES:-'true'}

"${HARMONIA_FOLDER}/eap-job.sh" ${@}

echo 'Adjust Surefire memory settings (due to failures in JDK6)'
sed -i 's/-Duser.language=en<\/argLine>/-Duser.language=en -XX:MaxPermSize=256m<\/argLine>/g' pom.xml

echo -n "Building release artifacts..."

readonly EAP_RELEASE_NAME=${EAP_RELEASE_NAME:-'jboss-eap-6.4'}
readonly EAP_MAVEN_ARTIFACTS_ZIPFILE_NAME=${EAP_MAVEN_ARTIFACTS_ZIPFILE_NAME:-"${EAP_RELEASE_NAME}-maven-artifacts.zip"}
readonly EAP_MAVEN_SOURCES_ZIPFILE_NAME=${EAP_MAVEN_SOURCES_ZIPFILE_NAME:-"${EAP_RELEASE_NAME}-src-prepared.zip"}
readonly EAP_LOCAL_MAVEN_REPO_FOLDER=${EAP_LOCAL_MAVEN_REPO_FOLDER:-'maven-local-repository'}

rm -rf "${HARMONIA_FOLDER}"

if [ -z "${NO_ZIPFILES}" ]; then
  cd ${EAP_LOCAL_MAVEN_REPO_FOLDER}
  zip -x "${HARMONIA_FOLDER}" -x \*.zip -qr "${EAP_MAVEN_ARTIFACTS_ZIPFILE_NAME}" .
  mv "${EAP_MAVEN_ARTIFACTS_ZIPFILE_NAME}" "${WORKSPACE}"
  cd "${WORKSPACE}"
  zip -x "${HARMONIA_FOLDER}" -x \*.zip -x "${EAP_LOCAL_MAVEN_REPO_FOLDER}" -qr "${EAP_MAVEN_SOURCES_ZIPFILE_NAME}" .

  # just to ensure zipfile are properly created
  unzip -t "${EAP_MAVEN_ARTIFACTS_ZIPFILE_NAME}" > /dev/null
  unzip -t "${EAP_MAVEN_SOURCES_ZIPFILE_NAME}" > /dev/null
fi
echo 'Done.'
