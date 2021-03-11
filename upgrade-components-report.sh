#!/bin/bash
set -eou pipefail

usage() {
  echo "$(basename "${0}") [email] [rule-name] [target-dir] [report-title] [project-code]"
}

runComponentAlignment() {
  java -Dlogger.projectCode="${LOGGER_PROJECT_CODE}" \
       -Dlogger.uri="${LOGGER_URI}" \
       -jar "${CLI}" 'generate-html-report' \
       -c "${CONFIG}" -f "${TARGET}" -o "${REPORT_FILE}"
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

readonly DEBUG=${DEBUG}
readonly TO_ADDRESS="${TO_ADDRESS:-${1}}"
readonly RULE_NAME="${RULE_NAME:-${2}}"

readonly TARGET_DIR=${TARGET_DIR:-'workdir'}
#readonly REPORT_TITLE_DEFAULT_TITLE="$(basename "${TARGET_DIR}")"
readonly REPORT_TITLE="${REPORT_TITLE:-${4}}"
readonly LOGGER_PROJECT_CODE="${LOGGER_PROJECT_CODE:-${5}}"

readonly JBOSS_USER_HOME=${JBOSS_USER_HOME:-'/home/jboss'}
readonly CLI="${PATH_TO_CLI:-/opt/tools/alignment-cli-0.6.jar}"
readonly CONFIG=${CONFIG:-"/opt/tools/dependency-alignment-configs/rules-${RULE_NAME}.json"}
readonly TARGET="${TARGET_DIR}/pom.xml"
readonly REPORT_FILE=${REPORT_FILE:-'report.html'}
readonly FROM_ADDRESS=${FROM_ADDRESS:-'thofman@redhat.com'}
readonly LOGGER_URI=${LOGGER_URI:-'http://component-upgrade-logger-jvm-component-alignment.int.open.paas.redhat.com/api'}

readonly GMAIL_SMTP_PASSWORD_FILE=${GMAIL_SMTP_PASSWORD_FILE:-"${HOME}/.gmail-smtp-password.gpg"}
if [ -e "${GMAIL_SMTP_PASSWORD_FILE}" ]; then
  readonly SMTP_PASSWORD=$(gpg -d "${GMAIL_SMTP_PASSWORD_FILE}" 2> /dev/null)
else
  readonly SMTP_PASSWORD="${SMTP_PASSWORD}"
fi

set -u

if [ -z "${TO_ADDRESS}" ]; then
  echo 'Missing email adress.'
  usage
  exit 1
fi

if [ -z "${RULE_NAME}" ]; then
  echo 'Missing rule name.'
  usage
  exit 2
fi

printConfig "${CONFIG}"

deleteOldReportFile "${REPORT_FILE}"

runComponentAlignment

sendReportByEmail "${REPORT_FILE}"
