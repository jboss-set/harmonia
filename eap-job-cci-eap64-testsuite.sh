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
export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dorg.jboss.model.test.jbossdeveloper.repourl=https://repository.jboss.org/"
export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dorg.jboss.model.test.eap.repourl=http://download.lab.bos.redhat.com/brewroot/repos/jb-eap-6.4-rhel-6-build/latest/maven/"

./build.sh clean install -fae -B -Dts.noSmoke -s "${MAVEN_SETTINGS_XML}" ${TESTSUITE_OPTS}
status_code=${?}
# Temporary skip testsuite for IBM JDK 8 (due to some keystore issues)
if [ "${jdk}" != "IBM_JDK8" ]; then
  readonly CONSOLE_LOG="${CONSOLE_LOG:-$(mktemp)}"
  ${BUILD_SCRIPT} 'testsuite' 2>&1 | tee "${CONSOLE_LOG}"
  status_code=${?}
  set +e
  grep "${CONSOLE_LOG}" -q \
      -e 'VM crash or System.exit called?' \
      -e 'JBAS013486' \
      -e 'Could not start container' \
      -e 'java.util.concurrent.CancellationException: Operation was cancelled'
  if [ "${?}" -eq 0 ]; then
    status_code=99
  fi
  rm "${CONSOLE_LOG}"
fi
exit "${status_code}"
