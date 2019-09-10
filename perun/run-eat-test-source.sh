#!/bin/bash
#NOTE: this is not ideal, it will checkout EAT each time, but for now it will do, plus its thunder, let it
#fry those drives and RAM
set -eo pipefail
log() {
  local mssg="${@}"
  local perun_log_prefix=${PERUN_LOG_PREFIX:-'[PERUN]'}

  echo "${perun_log_prefix} ${mssg}"
}

deleteEATWorkspace() {
  if [[ ! -z "${EAT_WORKSPACE}" ]]; then
    rm -rf "${EAT_WORKSPACE}"
  fi
}
trap deleteEATWorkspace EXIT

readonly EAT_WORKSPACE="${EAT_WORKSPACE:-$(mktemp -d)}"
readonly EAT_GITHUB_REPO="${EAT_GITHUB_REPO:-http://github.com/jboss-set/eap-additional-testsuite}"
readonly EAT_GITHUB_BRANCH="${EAT_GITHUB_BRANCH:-master}"
readonly TEST_NAME="${TEST_NAME}"
readonly EAP_DIST_DIR="${EAP_DIST_DIR:-jboss-eap-7.2}"
readonly JBOSS_FOLDER="${BISECT_WORKSPACE}/dist/target/${EAP_DIST_DIR}"
readonly WORKSPACE="${WORKSPACE}"
readonly GIT_SKIP_BISECT_ERROR_CODE=${GIT_SKIP_BISECT_ERROR_CODE}
readonly EAT_MODE="${EAT_MODE:-eap72x-proposed}"
#switch from harmonia to EAT name
readonly MAVEN_LOCAL_REPOSITORY="${LOCAL_REPO_DIR}"

export JBOSS_FOLDER
export MAVEN_LOCAL_REPOSITORY

#hack JBOSS_VERSION - EAT use 'xpath' which does not always work.
# tail -1 -EAP/EAT may suck more than one if they cross release boundries
POM_FILE=$(find ${MAVEN_LOCAL_REPOSITORY} -name 'jboss-eap-parent*.pom' | tail -1)

if [ ! -e "${POM_FILE}" ]; then
   log "Could not find pom file "
   exit ${GIT_SKIP_BISECT_ERROR_CODE}
fi

export JBOSS_VERSION=$(echo ${POM_FILE} | awk -F/ '{print $NF}' | sed -e 's/.pom//' | sed -e 's/jboss-eap-parent-//')

log "Start EAT testsuite"
#set +u
#export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dtest=${TEST_NAME}"
#set -u
git clone "${EAT_GITHUB_REPO}"  --branch "${EAT_GITHUB_BRANCH}" "${EAT_WORKSPACE}"
cd "${EAT_WORKSPACE}"

export EAT_EXTRA_OPTS="-Dversion.org.wildfly.openssl.wildfly-openssl-macosx-x86_64=1.0.6.Final-redhat-2 -Dtest=${TEST_NAME}"
export HARMONIA_BUILD_SCRIPT_NAME="eat-job.sh"

bash -x ${HARMONIA_SCRIPT} "${EAT_MODE}"
log "Stop EAT testsuite"

