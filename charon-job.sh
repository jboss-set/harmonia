#!/bin/bash
set -eo pipefail

readonly WORKSPACE=${WORKSPACE}
readonly JBOSS_STREAMS_URL='https://github.com/jboss-set/jboss-streams'
readonly STREAMS_FILENAME='streams.json'

set -u

if [ -z "${INPUT}" ]; then
  echo "Required input not provided"
  exit 1
fi

"${WORKSPACE}/configure.sh" "${JBOSS_STREAMS_URL}" "${STREAMS_FILENAME}"
"${WORKSPACE}/report.sh" "config/${INPUT}"
