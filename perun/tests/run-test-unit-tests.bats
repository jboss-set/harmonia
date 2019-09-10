#!/bin/bash

readonly RUN_TEST="$(pwd)/run-test.sh"
readonly PERUN_LOG_PREFIX=${PERUN_LOG_PREFIX:-'[PERUN]'}
export PERUN_LOG_PREFIX
# override command such as git
export PATH=$(pwd):${PATH}


deleteIfExist() {
  local file=${1}

  if [ -n "${file}" -a -e "${file}" ]; then
    rm -rf "${file}"
  fi

}

setup() {
  export BISECT_WORKSPACE=$(mktemp -d)
  export HARMONIA_SCRIPT='/opt/jboss-set-ci-scripts/harmonia-eap-build'
}

teardown() {
  deleteIfExist "${BISECT_WORKSPACE}"
}

@test "Missing HARMONIA_SCRIPT" {
  run ${RUN_TEST}
  [ "${status}" -eq 1 ]
  [[ ${output} == "${PERUN_LOG_PREFIX} Invalid path to Harmonia script provided: ${HARMONIA_SCRIPT}. Aborting." ]]
}

