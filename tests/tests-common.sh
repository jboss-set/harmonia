#!/bin/bash

if [ -z "${SCRIPT_NAME}" ]; then
  echo "No script name provided."
  exit 1
fi

readonly SCRIPT_HOME=${SCRIPT_HOME:-$(pwd)}
# ensure dummy 'mvn' command is on the path
export DUMMY_MVN=${DUMMY_MVN:-"$(pwd)/tests/mvn"}
export PATH=${DUMMY_MVN}:${PATH}

readonly SCRIPT="${SCRIPT_HOME}/${SCRIPT_NAME}"

if [ ! -d "${SCRIPT_HOME}" ]; then
  echo "Invalid home for ${SCRIPT_NAME}: ${SCRIPT_HOME}."
  exit 2
fi

if [ ! -e "${SCRIPT}" ]; then
  echo "Invalid path to script: ${SCRIPT}."
  exit 3
fi

deleteIfExist() {
  local file=${1}

  if [ -n "${file}" -a -e "${file}" ]; then
    rm -rf "${file}"
  fi
}

createDummyCommand() {
  local command=${1}
  echo 'echo ${@}' > "${command}"
  chmod +x "${command}"
  export PATH=${PATH}:$(pwd)/${command}
}

deleteDummyCommand() {
  local command=${1}
  deleteIfExist "${command}"
}

createDummyJavaCommand() {
  createDummyCommand 'java'
  # this part is specific to component upgrade
  if [ -n "${REPORT_FILE}" ]; then
    echo 'echo "Dummy content" > ${REPORT_FILE}' >> "${command}"
  fi
}

deleteDummyJavaCommand() {
  deleteIfExist './java'
}

createDummyBackgroundCommand() {
  local command=${1}
  echo '#! /bin/bash' > "${command}"
  echo "echo \"${command} \${@}\"" >> "${command}"
  # simple sleep 20 waits until end of sleep before being killed
  echo 'for i in `seq 1 20`; do sleep 1; done' >> "${command}"
  echo 'echo done' >> "${command}"
  chmod +x "${command}"
}
