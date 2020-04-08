#!/bin/bash
set -e

readonly EAP_LOCAL_MAVEN_REPO_FOLDER=${EAP_LOCAL_MAVEN_REPO_FOLDER:-'maven-local-repository'}
readonly EAP_LOCAL_MAVEN_REPO=${EAP_LOCAL_MAVEN_REPO:-${WORKSPACE}/${EAP_LOCAL_MAVEN_REPO_FOLDER}}

readonly EAP_SOURCES_ZIPFILE=${EAP_SOURCES_ZIPFILE:-'jboss-eap-6.4-src-prepared.zip'}
readonly EAP_MAVEN_ARTIFACTS_ZIPFILE=${EAP_MAVEN_ARTIFACTS_ZIPFILE:-'jboss-eap-6.4-maven-artifacts.zip'}

readonly BUILD_SCRIPT=${BUILD_SCRIPT:-"${HARMONIA_FOLDER}/eap-job.sh"}

export NO_ZIPFILES=${NO_ZIPFILES:-'true'}
if [ -z "${NO_ZIPFILES}" ]; then

  if [ ! -e "${EAP_SOURCES_ZIPFILE}" ]; then
    echo "No such zipfile for the EAP sources: ${EAP_SOURCES_ZIPFILE}. Aborting."
    exit 1
  fi

  if [ ! -e "${EAP_MAVEN_ARTIFACTS_ZIPFILE=}" ]; then
    echo "No such zipfile for the EAP artifacts: ${EAP_MAVEN_ARTIFACTS_ZIPFILE=}. Aborting."
    exit 2
  fi

  unzip "${EAP_SOURCES_ZIPFILE}" -d . > /dev/null
  rm -rf "${EAP_LOCAL_MAVEN_REPO}"
  unzip "${EAP_MAVEN_ARTIFACTS_ZIPFILE}" -d "${EAP_LOCAL_MAVEN_REPO_FOLDER}" > /dev/null
fi

export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dsurefire.rerunFailingTestsCount=2"

./build.sh clean install -fae -B -Dts.noSmoke -s "${MAVEN_SETTINGS_XML}" ${TESTSUITE_OPTS}
# Temporary skip testsuite for IBM JDK 8 (due to some keystore issues)
if [ "${jdk}" != "IBM_JDK8" ]; then
  ${BUILD_SCRIPT} 'testsuite'
  # ./integration-tests.sh test -Dts.integration -Ddomain.module -Dcompat.module ${TESTSUITE_OPTS}
fi
