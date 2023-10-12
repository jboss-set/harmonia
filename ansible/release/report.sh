#!/bin/bash
set -eo pipefail

checkIfRequiredEnvVarIsDefined() {
  local envVarname=${1}
  local value=${2}

  if [ -z "${value}" ]; then
    echo "Missing required envVar ${envVarname}."
    exit 1
  fi

  if [ "${value}" = 'null' ]; then
    echo "Invalid value (${value}) for ${envVarname}."
    exit 2
  fi
}

checkIfRequiredEnvVarIsDefined 'WORKSPACE' "${WORKSPACE}"
checkIfRequiredEnvVarIsDefined 'JENKINS_URL' "${JENKINS_URL}"

readonly PATH_TO_REPORT=${PATH_TO_REPORT:-"${WORKSPACE}/report.html"}
readonly TEMPLATE=${TEMPLATE:-"${WORKSPACE}/harmonia/ansible/release/report.tmpl.html"}
readonly FULL_RELEASE="${FULL_RELEASE:-'True'}"

readonly COLLECTION_NAME=${COLLECTION_NAME}
readonly RELEASE_NAME=${RELEASE_NAME}
readonly BUILD_CI=${BUILD_CI}
readonly BUILD_JANUS=${BUILD_JANUS}
readonly BUILD_DOWNSTREAM_CI=${BUILD_DOWNSTREAM_CI}
readonly BUILD_DOT=${BUILD_DOT}
readonly BUILD_RUNNER=${BUILD_RUNNER}

checkIfRequiredEnvVarIsDefined 'COLLECTION_NAME' "${COLLECTION_NAME}"
checkIfRequiredEnvVarIsDefined 'BUILD_CI' "${BUILD_CI}"
checkIfRequiredEnvVarIsDefined 'BUILD_JANUS' "${BUILD_JANUS}"
if [ "${FULL_RELEASE}" = 'True' ]; then
    checkIfRequiredEnvVarIsDefined 'BUILD_DOWNSTREAM_CI' "${BUILD_DOWNSTREAM_CI}"
    checkIfRequiredEnvVarIsDefined 'BUILD_DOT' "${BUILD_DOT}"
    checkIfRequiredEnvVarIsDefined 'BUILD_RUNNER' "${BUILD_RUNNER}"
    readonly DISPLAY_FULL_RELEASE="block"
fi

checkIfRequiredEnvVarIsDefined 'BUILD_RELEASE_ARTEFACTS' "${BUILD_RELEASE_ARTEFACTS}"

sed "${TEMPLATE}" \
    -e "s;COLLECTION_NAME;${COLLECTION_NAME};g" \
    -e "s;RELEASE_NAME;${RELEASE_NAME:-'no release name provided'};g" \
    -e "s;BUILD_CI;${BUILD_CI};g" \
    -e "s;JENKINS_URL;${JENKINS_URL};g" \
    -e "s;BUILD_JANUS;${BUILD_JANUS};g" \
    -e "s;BUILD_DOWNSTREAM_CI;${BUILD_DOWNSTREAM_CI};g" \
    -e "s;BUILD_DOT;${BUILD_DOT};g" \
    -e "s;BUILD_RUNNER;${BUILD_RUNNER};g" \
    -e "s;DISPLAY_FULL_RELEASE;${DISPLAY_FULL_RELEASE:-none};g" \
    -e "s;BUILD_RELEASE_ARTEFACTS;${BUILD_RELEASE_ARTEFACTS};g" > "${PATH_TO_REPORT}"
