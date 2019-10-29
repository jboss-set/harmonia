#!/bin/bash
set -e

usage() {
  echo "$(basename "${0}") [email] [rule-name] [target-dir] [report-title]"
}

deleteOldReportFile() {
  if [ -e "${REPORT_FILE}" ]; then
    echo "Deleting ${REPORT_FILE}"
    rm "${REPORT_FILE}"
  fi
}

readonly EMAIL="${1}"

if [ -z "${EMAIL}" ]; then
  echo 'Missing email adress.'
  usage
  exit 1
fi

if [ "${EMAIL}" = '-h' ]; then
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

readonly JBOSS_USER_HOME=${JBOSS_USER_HOME:-'/home/jboss'}
readonly CLI="${JBOSS_USER_HOME}/alignment-cli.jar"
readonly CONFIG=${CONFIG:-"${JBOSS_USER_HOME}/dependency-alignment-configs/rules-${RULE_NAME}.json"}
readonly TARGET="${TARGET_DIR}/pom.xml"
readonly REPORT_FILE=${REPORT_FILE:-'report.txt'}
readonly FROM_ADDRESS=${FROM_ADDRESS:-'thofman@redhat.com'}

set -u

if [ ! -e "${CLI}" ]; then
  echo "CLI jar does not exists: ${CLI}"
  exit 4
fi

echo '==== REPORT CONFIGURATION ==='
cat "${CONFIG}"
echo '===='

deleteOldReportFile

java -jar "${CLI}" 'generate-report' -c "${CONFIG}" -f "${TARGET}" -o "${REPORT_FILE}"

if [ -e "${REPORT_FILE}" ] && [ -s "${REPORT_FILE}" ]; then
    mail -s "Possible component upgrades report - ${REPORT_TITLE}" -r "${FROM_ADDRESS}" "${EMAIL}" < "${REPORT_FILE}"
else
    echo "No report generated"
fi

