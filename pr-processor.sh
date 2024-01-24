#!/bin/bash
set -eo pipefail

readonly PULL_REQUEST_PROCESSOR_HOME=${PULL_REQUEST_PROCESSOR_HOME}

readonly APHRODITE_CONFIG=${APHRODITE_CONFIG:-'/opt/tools/aphrodite.json'}
readonly PATH_TO_JAR=${PATH_TO_JAR:-"${PULL_REQUEST_PROCESSOR_HOME}/pull-processor-${VERSION}.jar"}
readonly PR_PROCESSOR_WRITE_MODE=${PR_PROCESSOR_WRITE_MODE:-'true'}
readonly PR_PROCESSOR_HTML_REPORT="${WORKSPACE}/report.html"
readonly CACHE_NAME=${CACHE_NAME:-'github-cache'}
readonly CACHE_SIZE=${CACHE_SIZE:-'20'}
readonly PATH=${JAVA_HOME}/bin:${PATH}

declare -a ACTIVES_STREAMS
ACTIVES_STREAMS[0]='jboss-eap-7.3.z[wildfly-wildfly,wildfly-wildfly-core]'
ACTIVES_STREAMS[1]='jboss-eap-7.4.z[wildfly-wildfly,wildfly-wildfly-core]'

set -u

if [ -z "${PULL_REQUEST_PROCESSOR_HOME}" ]; then
  echo "PULL_REQUEST_PROCESSOR_HOME is not defined - abort."
  exit 1
fi

if [ ! -d "${PULL_REQUEST_PROCESSOR_HOME}" ]; then
  echo "PULL_REQUEST_PROCESSOR_HOME is not a directory (${PULL_REQUEST_PROCESSOR_HOME}) - abort."
  exit 2
fi

if [ -z "${APHRODITE_CONFIG}" ]; then
  echo "APHRODITE_CONFIG is not defined - abort."
  exit 3
fi

if [ ! -e "${APHRODITE_CONFIG}" ]; then
  echo "APHRODITE_CONFIG does not exist (${APHRODITE_CONFIG}) abort."
  exit 4
fi

if [ -d "${APHRODITE_CONFIG}" ]; then
  echo "APHRODITE_CONFIG is a directory: ${APHRODITE_CONFIG} - abort."
  exit 5
fi

if [ ! -e "${PATH_TO_JAR}" ]; then
  echo "Missing Pull Processor JAR (${PATH_TO_JAR}) - abort."
  exit 6
fi

if [ -z "${JAVA_HOME}" ]; then
  echo "No JAVA_HOME has been defined - abort"
  exit 7
fi



java -jar \
     -Daphrodite.config="${APHRODITE_CONFIG}" \
     -DcacheDir="${PULL_REQUEST_PROCESSOR_HOME}/cache" \
     -DcacheName="${CACHE_NAME}" \
     -DcacheSize="${CACHE_SIZE}" \
     "${PATH_TO_JAR}" \
         -s "${ACTIVES_STREAMS[@]}" \
         -p "${ACTIVES_STREAMS[@]}" \
         -f "${PR_PROCESSOR_HTML_REPORT}" \
         -w "${PR_PROCESSOR_WRITE_MODE}"
