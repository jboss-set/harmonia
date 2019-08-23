#!/bin/bash
set -e

usage() {

  echo $(basename "${0}") [path-to-alignment-jar]
}

readonly JBOSS_USER_HOME='/home/jboss'
readonly CLI="${1:-${JBOSS_USER_HOME}/alignment-cli-0.3-SNAPSHOT.jar}"
readonly CONFIG="${JBOSS_USER_HOME}/wildfly-18-alignment-config.json"

set -u

ls -l "${CLI}"
cat "${CONFIG}"

java -jar "${CLI}" 'generate-prs' -c "${CONFIG}" -f 'wildfly/pom.xml'

