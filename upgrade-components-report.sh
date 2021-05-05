#!/bin/bash
set -eou pipefail

usage() {
  echo "$(basename "${0}") [email] [rule-name] [target-dir] [report-title] [project-code]"
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

  java -Dlogger.projectCode="${LOGGER_PROJECT_CODE}" \
       -Dlogger.uri="${COMPONENT_UPGRADE_LOGGER}" \
       -jar "${CLI}" 'generate-html-report' \
       -c "${CONFIG}" -f "${target}/" -o "${REPORT_FILE}"
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

  if [ -n "${SMTP_PASSWORD}" ]; then
    if [ -e "${report_file}" ] && [ -s "${report_file}" ]; then
      if [ -z "${SMTP_PASSWORD}" ]; then
        emailWithSMTP
      else
        emailWithGMail
      fi
    else
      echo "No report generated"
    fi
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
    mutt -e "set from = '${FROM_ADDRESS}'" \
         -e 'set content_type=text/html' \
         -s "Possible component upgrades report - ${REPORT_TITLE}" \
         "${TO_ADDRESS}" < "${REPORT_FILE}"
}

emailWithGMail() {
    mutt -e 'set content_type = text/html' \
         -e "set smtp_url = 'smtps://${FROM_ADDRESS}@smtp.gmail.com:465'" \
         -e "set smtp_pass = '${SMTP_PASSWORD}'" \
         -e "set ssl_starttls = yes" \
         -e "set ssl_force_tls = yes" \
         -s "Possible component upgrades report - ${REPORT_TITLE}" \
         "${TO_ADDRESS}" < "${REPORT_FILE}"
}

set +u
ifRequestedPrintUsageAndExit "${1}"

readonly DEBUG=${DEBUG:-true}
readonly TARGET_DIR=${TARGET_DIR:-'.'}
readonly CLI=${PATH_TO_CLI:-'/opt/tools/component_alignment/alignment-cli-0.7.jar'}
readonly JOBS_SETTINGS=${JOBS_SETTINGS:-'/opt/tools/component-alignment-config-template.csv'}
readonly REPORT_FILE=${REPORT_FILE:-'report.html'}
readonly FROM_ADDRESS=${FROM_ADDRESS:-'thofman@redhat.com'}
readonly COMPONENT_UPGRADE_LOGGER=${COMPONENT_UPGRADE_LOGGER:-''}

readonly GMAIL_SMTP_PASSWORD_FILE=${GMAIL_SMTP_PASSWORD_FILE:-"${HOME}/.gmail-smtp-password.gpg"}
if [ -e "${GMAIL_SMTP_PASSWORD_FILE}" ]; then
  readonly SMTP_PASSWORD=$(gpg -d "${GMAIL_SMTP_PASSWORD_FILE}" 2> /dev/null)
else
  readonly SMTP_PASSWORD="${SMTP_PASSWORD}"
fi

if [ ! -e "${JOBS_SETTINGS}" ]; then
  echo "Invalid set up, missing jobs settings file: ${JOBS_SETTINGS}."
  exit 1
fi

readonly JOB_NAME=${JOB_NAME}
if [ -z "${JOB_NAME}" ]; then
  echo "No JOB_NAME provided - aborting".
  exit 2
else
  readonly JOB_CONFIG=$(grep -e "^${JOB_NAME}," "${JOBS_SETTINGS}")
fi

readonly RULE_NAME=$(echo "${JOB_CONFIG}" | cut -f2 -d, )
readonly REPORT_TITLE=$( echo "${JOB_CONFIG}" | cut -f3 -d, )
readonly LOGGER_PROJECT_CODE=$(echo "${JOB_CONFIG}" | cut -f3 -d, )

readonly CONFIG_HOME=${CONFIG_HOME:-'/opt/tools/component_alignment/dependency-alignment-configs'}
readonly CONFIG=${CONFIG:-"${CONFIG_HOME}/rules-${RULE_NAME}.json"}

if [ ! -e "${CONFIG}" ]; then
  echo "No such file: ${CONFIG} - abort"
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
