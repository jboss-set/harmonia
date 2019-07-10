#!/bin/bash

readonly SCRIPT_NAME=${SCRIPT_NAME}

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

setup() {
  export MAVEN_HOME=$(mktemp -d)
  mkdir ${MAVEN_HOME}/bin
  cp "${DUMMY_MVN}" "${MAVEN_HOME}/bin/"
  export JBOSS_FOLDER=$(mktemp -d)
  export WORKSPACE=$(mktemp -d)
}

teardown() {
  deleteIfExist "${MAVEN_HOME}"
  deleteIfExist "${JBOSS_FOLDER}"
  deleteIfExist "${WORKSPACE}"
  unset MAVEN_HOME
  unset JBOSS_FOLDER
}

@test "Run with default settings.xml" {
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "${lines[-1]}" = 'mvn clean install -s /home/jboss/settings.xml -B' ]
}

@test "No settings.xml provided" {
  export MAVEN_SETTINGS_XML=''
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "${lines[-1]}" = 'mvn clean install  -B' ]
}
