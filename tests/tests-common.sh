#!/bin/bash

debugBatsTest() {

  for i in "${!lines[@]}"
  do
    echo "${lines[${i}]}"
  done
  echo "${status}"
}

deleteIfExist() {
  local file=${1}

  if [ -n "${file}" -a -e "${file}" ]; then
    rm -rf "${file}"
  fi
}

setupDummyCommandHomeDir() {

  readonly DUMMY_COMMAND_DIR=${DUMMY_COMMAND_DIR:-$(mktemp -d)}
  export DUMMY_COMMAND_DIR
  #trap "deleteIfExist ${DUMMY_COMMAND_DIR}" EXIT
  export PATH=${DUMMY_COMMAND_DIR}:${PATH}

}

setupDummyMvn() {
  export DUMMY_MVN=${DUMMY_MVN:-"$(pwd)/tests/mvn"}
  export PATH=${DUMMY_MVN}:${PATH}
}

createDummyCommand() {
  local command=${1}

  if [ -z "${command}" ]; then
    echo "No command provided - abort."
    exit 1
  fi
  local path_to_command="${DUMMY_COMMAND_DIR}/${command}"

  echo 'echo ${@}' > "${path_to_command}"
  chmod +x "${path_to_command}"
 # trap "deleteIfExist ${path_to_command}" EXIT
}

createDummyJavaCommand() {
  createDummyCommand 'java'
  # this part is specific to component upgrade
  if [ -n "${REPORT_FILE}" ]; then
    echo 'echo "Dummy content" > ${REPORT_FILE}' >> "${command}"
  fi
}

setupDummyCommandHomeDir
createDummyJavaCommand
setupDummyMvn

if [ -z "${SCRIPT_NAME}" ]; then
  echo "No script name provided."
  exit 1
fi

readonly SCRIPT_HOME=${SCRIPT_HOME:-$(pwd)}
readonly SCRIPT="${SCRIPT_HOME}/${SCRIPT_NAME}"

if [ ! -d "${SCRIPT_HOME}" ]; then
  echo "Invalid home for ${SCRIPT_NAME}: ${SCRIPT_HOME}."
  exit 2
fi

if [ ! -e "${SCRIPT}" ]; then
  echo "Invalid path to script: ${SCRIPT}."
  exit 3
fi
