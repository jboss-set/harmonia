#!/bin/bash
set -eo pipefail
log() {
  local mssg="${@}"
  local perun_log_prefix=${PERUN_LOG_PREFIX:-'[PERUN]'}

  echo "${perun_log_prefix} ${mssg}"
}

set +e
which patch > /dev/null
if [ "${?}" -ne 0 ]; then
  log "This script requires 'patch' command, but command is missing. Aborting."
fi
set -e


readonly PERUN_LOG_PREFIX=${PERUN_LOG_PREFIX:-'[PERUN]'}
readonly GIT_SKIP_BISECT_ERROR_CODE=${GIT_SKIP_BISECT_ERROR_CODE:-'125'}
readonly TEST_NAME="${TEST_NAME}"
readonly HARMONIA_SCRIPT="${HARMONIA_SCRIPT:-'/opt/jboss-set-ci-scripts/harmonia-eap-build'}"
readonly CURRENT_REVISION=$(git rev-parse HEAD)
readonly SCRIPT_PATH=${0%/*}
readonly TEST_RUN_SCRIPT="${TEST_RUN_SCRIPT:-run-eap-test-source.sh}"

if [ ! -e "${HARMONIA_SCRIPT}" ]; then
  log "Invalid path to Harmonia script provided: ${HARMONIA_SCRIPT}. Aborting."
  exit 1
fi

if [[ $CORRUPT_REVISIONS == *"${CURRENT_REVISION}"* ]]; then
  log "Current revision \"${CURRENT_REVISION}\" is in corrupt list, skipping."
  exit "${GIT_SKIP_BISECT_ERROR_CODE}"
fi

set -u


if [ -z "${TEST_NAME}" ]; then
  log "No TEST_NAME provided."
  exit 1
fi

log "Building ..."
#TODO: determine why conditional substitution does not work
#set +u
#export BUILD_OPTS=${BUILD_OPTS:'-DskipTests'}
#set -u
export BUILD_OPTS="-DskipTests"
bash -x ${HARMONIA_SCRIPT}

log "Done."
bash -x ${SCRIPT_PATH}/${TEST_RUN_SCRIPT}
#exit $?
