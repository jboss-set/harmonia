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
    echo "Environnement variable ${envVarName} is not defined."
    usage
    exit "${exitCode}"
  else
    if [ -n "${DEBUG}" ]; then
      echo "${envVarName}: ${envVarValue}"
    fi
  fi
}

runComponentAlignment() {
  local target="${TARGET_DIR}/pom.xml"

  local loggerParams=''
  if [ -n "${COMPONENT_UPGRADE_LOGGER}" ]; then
    loggerParams="-Dlogger.projectCode="${LOGGER_PROJECT_CODE}" -Dlogger.uri=${COMPONENT_UPGRADE_LOGGER}"
  fi

  java $loggerParams \
       -jar "${CLI}" 'generate-html-report' \
       -c "${CONFIG}" -f "${target}" -o "${REPORT_FILE}"
}

ifRequestedPrintUsageAndExit() {
  local firstArg=${1}

  if [ "${firstArg}" = '-h' ]; then
    usage
    exit 0
  fi
}

sendReportByEmail() {
  local report_file=${1}

  if [ -e "${report_file}" ] && [ -s "${report_file}" ]; then
    if [ "${USE_SMTP_PASSWORD}" = 0 ]; then
      emailWithSMTP
    else
      emailWithGMail
    fi
  else
    echo "No report generated"
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

deleteOldReportFile() {
  local report_file=${1}

  if [ -e "${REPORT_FILE}" ]; then
    echo "Deleting ${REPORT_FILE}"
    rm "${REPORT_FILE}"
  fi
}

emailWithSMTP() {
  echo Sending a report via the corporate SMTP server.

  mutt -e "set from = '${FROM_ADDRESS}'" \
       -e "set smtp_url = '${SMTP_URL}'" \
       -e 'set content_type=text/html' \
       -s "Possible component upgrades report - ${REPORT_TITLE}" \
       "${TO_ADDRESS}" < "${REPORT_FILE}"
}

emailWithGMail() {
  echo Sending a report via the Gmail SMTP server.

  # disable debugging if enabled, to avoid revealing password when debugging is enabled
  local debug=0;
  if [[ $- =~ x ]]; then debug=1; set +x; fi

  # print the mutt command without a password for debugging purposes
  echo mutt -e 'set content_type = text/html' \
       -e "set smtp_url = 'smtps://${FROM_ADDRESS}@smtp.gmail.com:465'" \
       -e "set smtp_pass = '***'" \
       -e "set ssl_starttls = yes" \
       -e "set ssl_force_tls = yes" \
       -s "Possible component upgrades report - ${REPORT_TITLE}" \
       "${TO_ADDRESS}" \< "${REPORT_FILE}"
  
  mutt -e 'set content_type = text/html' \
       -e "set smtp_url = 'smtps://${FROM_ADDRESS}@smtp.gmail.com:465'" \
       -e "set smtp_pass = '$(unpackSmtpPassword)'" \
       -e "set ssl_starttls = yes" \
       -e "set ssl_force_tls = yes" \
       -s "Possible component upgrades report - ${REPORT_TITLE}" \
       "${TO_ADDRESS}" < "${REPORT_FILE}"

  # reset debugging
  [[ $debug == 1 ]] && set -x
}

unpackSmtpPassword() {
  gpg -d "${GMAIL_SMTP_PASSWORD_FILE}" 2> /dev/null
}

set +u
ifRequestedPrintUsageAndExit "${1}"

readonly DEBUG=${DEBUG:-true}
readonly TARGET_DIR=${TARGET_DIR:-'.'}
readonly COMPONENT_ALIGNMENT_HOME=${COMPONENT_ALIGNMENT_HOME:-'/opt/tools/component-alignment'}
readonly CLI=${PATH_TO_CLI:-"${COMPONENT_ALIGNMENT_HOME}/alignment-cli-0.7.jar"}
readonly JOBS_SETTINGS=${JOBS_SETTINGS:-'/opt/tools/component-alignment-config-template.csv'}
readonly REPORT_FILE=${REPORT_FILE:-'report.html'}
readonly FROM_ADDRESS=${FROM_ADDRESS:-'thofman@redhat.com'}
readonly COMPONENT_UPGRADE_LOGGER=${COMPONENT_UPGRADE_LOGGER:-''}

readonly GMAIL_SMTP_PASSWORD_FILE=${GMAIL_SMTP_PASSWORD_FILE:-"${HOME}/.gmail-smtp-password.gpg"}
if [ -e "${GMAIL_SMTP_PASSWORD_FILE}" ]; then
  readonly USE_SMTP_PASSWORD=1
else
  readonly USE_SMTP_PASSWORD=0
fi

if [ ! -e "${JOBS_SETTINGS}" ]; then
  echo "Invalid set up, missing jobs settings file: ${JOBS_SETTINGS}."
  exit 1
fi

readonly JOB_NAME=${JOB_NAME}
if [ -z "${JOB_NAME}" ]; then
  echo "No JOB_NAME provided - aborting".
  usage
  exit 2
else
  readonly JOB_CONFIG=$(grep -e "^${JOB_NAME}," "${JOBS_SETTINGS}")
fi

readonly RULE_NAME=$(echo "${JOB_CONFIG}" | cut -f2 -d, )
readonly REPORT_TITLE=$( echo "${JOB_CONFIG}" | cut -f3 -d, )
readonly LOGGER_PROJECT_CODE=$(echo "${JOB_CONFIG}" | cut -f4 -d, )

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

deleteOldReportFile "${REPORT_FILE}"

runComponentAlignment

sendReportByEmail "${REPORT_FILE}"
