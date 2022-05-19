#!/bin/bash
set -ueo pipefail

source /opt/tools/smtp-settings.sh

usage() {
  echo
  echo Usage:
  echo
  echo Create following mandatory env variables:
  echo '* TARGET_DIR - path to maven project directory which should be analyzed'
  echo '* JOB_NAME - id which will be used to lookup a job configuration in the settings CSV file'
  echo '* TO_ADDRESS - an email address to send the report to'
  echo
  echo Optional env variables:
  echo '* JOBS_SETTINGS - path to job settings CSV file'
  echo '* CONFIG - path to JSON configuration file with upgrade rules'
  echo
  echo "$(basename "${0}")"
}

checkEnvVar() {
  local envVarName=${1}
  local envVarValue=${2}
  local exitCode=${3}

  if [ -z "${envVarValue}" ]; then
    echo "Environment variable ${envVarName} is not defined."
    usage
    exit "${exitCode}"
  else
    if [ -n "${DEBUG}" ]; then
      echo "${envVarName}: ${envVarValue}"
    fi
  fi
}

runComponentAlignment() {
  set -x

  local target="${TARGET_DIR}/pom.xml"

  local jvmParams=''
  if [ -n "${COMPONENT_UPGRADE_LOGGER}" ]; then
    jvmParams="${jvmParams} -Dlogger.projectCode=${LOGGER_PROJECT_CODE} -Dlogger.uri=${COMPONENT_UPGRADE_LOGGER}"
  fi

  $JAVA_HOME/bin/java ${jvmParams} \
       -jar "${CLI}" 'send-html-report' \
       -c "${CONFIG}" \
       -f "${target}" \
       --email-smtp-host "${SMTP_HOST}" \
       --email-smtp-port "${SMTP_PORT}" \
       --email-subject "Possible component upgrades report - ${REPORT_TITLE}" \
       --email-from "${FROM_ADDRESS}" \
       --email-to "${TO_ADDRESS}"
}

ifRequestedPrintUsageAndExit() {
  local firstArg=${1}

  if [ "${firstArg}" = '-h' ]; then
    usage
    exit 0
  fi
}

printConfig() {
  local config_file=${1}

  if [ -n "${DEBUG}" ]; then
    echo '==== REPORT CONFIGURATION ==='
    cat "${config_file}"
    echo '===='
  fi
}

set +u
ifRequestedPrintUsageAndExit "${1}"

readonly DEBUG=${DEBUG:-true}
readonly TARGET_DIR=${TARGET_DIR:-'.'}
readonly COMPONENT_ALIGNMENT_HOME=${COMPONENT_ALIGNMENT_HOME:-'/opt/tools/component-alignment'}
readonly CLI=${PATH_TO_CLI:-"${COMPONENT_ALIGNMENT_HOME}/alignment-cli.jar"}
readonly FROM_ADDRESS=${FROM_ADDRESS:-'thofman@redhat.com'}
readonly COMPONENT_UPGRADE_LOGGER=${COMPONENT_UPGRADE_LOGGER:-''}
readonly JAVA_HOME=${JAVA_HOME:-'/opt/oracle/java'}

if [ -z "${JOB_NAME}" ]; then
  echo "No JOB_NAME provided - aborting".
  usage
  exit 2
fi

readonly CONFIG_HOME=${CONFIG_HOME:-"${COMPONENT_ALIGNMENT_HOME}/dependency-alignment-configs/"}
readonly CONFIG=${CONFIG:-"${CONFIG_HOME}/rules-${RULE_NAME}.json"}

if [ ! -e "${CONFIG}" ]; then
  echo "No such file: ${CONFIG} - abort"
  usage
  exit 3
fi

set -u

checkEnvVar 'TO_ADDRESS' "${TO_ADDRESS}" '2'
checkEnvVar 'RULE_NAME' "${RULE_NAME}" '3'
checkEnvVar 'REPORT_TITLE' "${REPORT_TITLE}" '4'
checkEnvVar 'LOGGER_PROJECT_CODE' "${LOGGER_PROJECT_CODE}" '5'

printConfig "${CONFIG}"

runComponentAlignment
