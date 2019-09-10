#!/bin/bash

readonly PERUN="$(pwd)/perun.sh"
readonly PERUN_LOG_PREFIX=${PERUN_LOG_PREFIX:-'[PERUN]'}
# override command such as git
export PATH=$(pwd)/tests:${PATH}


deleteIfExist() {
  local file=${1}

  if [ -n "${file}" -a -e "${file}" ]; then
    rm -rf "${file}"
  fi

}

setup() {
  export BISECT_WORKSPACE=$(mktemp -d)
}

teardown() {
  deleteIfExist "${BISECT_WORKSPACE}"
}

@test "Missing Good revision" {
  run ${PERUN}
  [ "${status}" -eq 1 ]
  [[ ${output} == "${PERUN_LOG_PREFIX} No good revision provided, aborting." ]]
}

@test "Missing Bad revision" {
  export GOOD_REVISION='1'
  run ${PERUN}
  [ "${status}" -eq 2 ]
  [[ ${output} == "${PERUN_LOG_PREFIX} No bad revision provided, aborting." ]]
}

@test "Missing reproducer URL" {
  export GOOD_REVISION='1'
  export BAD_REVISION='2'
  run ${PERUN}
  [ "${status}" -eq 3 ]
  [[ ${output} == "${PERUN_LOG_PREFIX} No URL for the reproducer patch provided, aborting." ]]
}

@test "Missing Testname" {
  export GOOD_REVISION='1'
  export BAD_REVISION='2'
  export REPRODUCER_PATCH_URL='3'

  run ${PERUN}
  [ "${status}" -eq 4 ]
  [[ ${output} == "${PERUN_LOG_PREFIX} No test name provided, aborting." ]]
}
