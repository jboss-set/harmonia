#!/bin/bash
set -eo pipefail
log() {
  local mssg="${@}"
  local perun_log_prefix=${PERUN_LOG_PREFIX:-'[PERUN]'}

  echo "${perun_log_prefix} ${mssg}"
}

cleanPatch() {
  if [ -e "${REPRODUCER_PATCH}" ]; then
    log 'Cleaning up after test patch ...'
    patch -p1 -i "${REPRODUCER_PATCH}" -R --verbose
  fi

  if [ -e "${INTEGRATION_SH_PATCH}" ]; then
    log 'Cleaning up after integration patch ...'
    patch -p1 -i "${INTEGRATION_SH_PATCH}" -R --verbose
  fi
}

trap cleanPatch EXIT

readonly REPRODUCER_PATCH="${REPRODUCER_PATCH}"
readonly INTEGRATION_SH_PATCH="${INTEGRATION_SH_PATCH}"
readonly TEST_NAME="${TEST_NAME}"

log "Running testsuite ..."
set +u
export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dtest=${TEST_NAME}"
set -u

if [ -e "${INTEGRATION_SH_PATCH}" ]; then
  log "Patching integration script...."
  patch -p1 -i "${INTEGRATION_SH_PATCH}" --verbose
else
  log "No integration.sh patch file provided, skipping"
  exit 1
fi

if [ -e "${REPRODUCER_PATCH}" ]; then
  log "Patching tests...."
  patch -p1 -i "${REPRODUCER_PATCH}" --verbose
else
  log "No tests patch file provided, skipping"
fi

# TODO if patch fails, we need to skip test and print a message that the test is not compatible with the revision skipped
log "Start EAP testsuite"
bash -x ${HARMONIA_SCRIPT} 'testsuite'
#CODE=$?
log "Stop EAP testsuite"
#exit $CODE
