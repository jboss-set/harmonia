#!/bin/bash
set -ex

usage() {
  echo "$(basename "${0}") [email] [rule-name] [target-dir] [report-title] [project-code]"
}

readonly TO_ADDRESS="${1}"

if [ -z "${TO_ADDRESS}" ]; then
  echo 'Missing email adress.'
  usage
  exit 1
fi

if [ "${1}" = '-h' ]; then
  usage
  exit 0
fi

readonly RULE_NAME="${2}"

if [ -z "${RULE_NAME}" ]; then
  echo 'Missing rule name.'
  usage
  exit 2
fi

readonly TARGET_DIR="${3}"

if [ -z "${TARGET_DIR}" ]; then
  echo 'Missing target dir.'
  usage
  exit 3
fi

readonly REPORT_TITLE="${4:-$(basename "${TARGET_DIR}")}"
readonly LOGGER_PROJECT_CODE="${5}"

readonly JBOSS_USER_HOME=${JBOSS_USER_HOME:-'/home/jboss'}
readonly CLI="${JBOSS_USER_HOME}/alignment-cli.jar"
readonly CONFIG=${CONFIG:-"${JBOSS_USER_HOME}/dependency-alignment-configs/rules-${RULE_NAME}.json"}
readonly TARGET="${TARGET_DIR}/pom.xml"
readonly REPORT_FILE=${REPORT_FILE:-'report.html'}
readonly FROM_ADDRESS=${FROM_ADDRESS:-'thofman@redhat.com'}
readonly LOGGER_URI=${LOGGER_URI:-'http://component-upgrade-logger-jvm-component-alignment.int.open.paas.redhat.com/api'}

readonly SMTP_PASSWORD=`gpg -d ~/.gmail-smtp-password.gpg 2> /dev/null`

set -u

if [ ! -e "${CLI}" ]; then
  echo "CLI jar does not exists: ${CLI}"
  exit 4
fi

echo '==== REPORT CONFIGURATION ==='
cat "${CONFIG}"
echo '===='

# delete old report file
if [ -e "${REPORT_FILE}" ]; then
  echo "Deleting ${REPORT_FILE}"
  rm "${REPORT_FILE}"
fi

java -Dlogger.projectCode="${LOGGER_PROJECT_CODE}" \
     -Dlogger.uri="${LOGGER_URI}" \
     -jar "${CLI}" 'generate-html-report' \
     -c "${CONFIG}" -f "${TARGET}" -o "${REPORT_FILE}"

if [ -e "${REPORT_FILE}" ] && [ -s "${REPORT_FILE}" ]; then
    mutt -e 'set content_type = text/html' \
         -e "set from = '${FROM_ADDRESS}'" \
         -e "set smtp_url = 'smtps://${FROM_ADDRESS}@smtp.gmail.com:465'" \
         -e "set smtp_pass = '${SMTP_PASSWORD}'" \
         -e "set ssl_starttls = yes" \
         -e "set ssl_force_tls = yes" \
         -s "Possible component upgrades report - ${REPORT_TITLE}" \
         "${TO_ADDRESS}" < "${REPORT_FILE}"
else
    echo "No report generated"
fi

