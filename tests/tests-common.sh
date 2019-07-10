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
