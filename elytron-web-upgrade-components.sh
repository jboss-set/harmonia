#!/bin/bash
set -e

usage() {
  echo $(basename "${0}") [email-addresses]
}

readonly JBOSS_USER_HOME='/home/jboss'
readonly CLI="${JBOSS_USER_HOME}/alignment-cli.jar"
readonly CONFIG="${JBOSS_USER_HOME}/dependency-alignment-configs/rules-elytron-1x.json"
readonly TARGET="elytron-web/pom.xml"
readonly EMAIL="${1}"

set -u

ls -l "${CLI}"
cat "${CONFIG}"

java -jar "${CLI}" 'generate-report' -c "${CONFIG}" -f "${TARGET}" -o 'report.txt'

cat 'report.txt' | mail -s 'Possible component upgrades report - Elytron Web' "${EMAIL}"

