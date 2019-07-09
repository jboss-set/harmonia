#!/bin/bash

readonly RUN_EAT_HOME=${RUN_EAT_HOME:-$(pwd)}
# ensure dummy 'mvn' command is on the path
export PATH=$(pwd)/tests:${PATH}

readonly RUN_EAT="${RUN_EAT_HOME}/eat-job.sh"

if [ ! -d "${RUN_EAT_HOME}" ]; then
  echo "Invalid home for ${RUN_EAT}: ${RUN_EAT_HOME}."
  exit 1
fi

if [ ! -e "${RUN_EAT}" ]; then
  echo "Invalid path to EAT run script: ${RUN_EAT}."
  exit 2
fi

deleteIfExist() {
  local file=${1}

  if [ -n "${file}" -a -e "${file}" ]; then
    rm -rf "${file}"
  fi

}

setup() {
  export MAVEN_HOME=$(mktemp -d)
  export JBOSS_FOLDER=$(mktemp -d)
  export JBOSS_VERSION='7.6'
  export JBOSS_CODE='eap72x'
}

teardown() {
  deleteIfExist "${MAVEN_HOME}"
  deleteIfExist "${JBOSS_FOLDER}"
  unset MAVEN_HOME
  unset JBOSS_FOLDER
  unset JBOSS_VERSION
  unset JBOSS_CODE
}

@test "Missing JBoss version code" {
  run "${RUN_EAT}"
  [ "${status}" -eq 1 ]
  [[ ${output} == *"Missing JBOSS_VERSION_CODE (eap7, eap64,...)."* ]]
}

@test "No Maven Home provided" {
  export MAVEN_HOME=""
  run "${RUN_EAT}" "${JBOSS_CODE}"
  [ "${status}" -eq 2 ]
  [  "${output}" = 'No MAVEN_HOME has been defined.' ]
}

@test "Maven Home provided is not a directory" {
  rm -rf ${MAVEN_HOME}
  export MAVEN_HOME=$(mktemp)
  run "${RUN_EAT}" "${JBOSS_CODE}"
  [ "${status}" -eq 4 ]
  [ "${output}" = "Provided MAVEN_HOME is not a directory: ${MAVEN_HOME}" ]
}

@test "Maven Home provided does not exist" {
  export MAVEN_HOME="$(mktemp).not.exist"
  run "${RUN_EAT}" "${JBOSS_CODE}"
  [ "${status}" -eq 3 ]
  [ "${output}" = "Provided MAVEN_HOME does not exist: ${MAVEN_HOME}" ]
  rm -rf "${MAVEN_HOME%.not.exist}"
}

@test "Simple run" {
  echo "FOLDER:${JBOSS_FOLDER}, MVN_HOME:${MAVEN_HOME}."
  run "${RUN_EAT}" "${JBOSS_CODE}"
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "Runing EAT on JBoss server: ${JBOSS_FOLDER} - using extra opts: " ]
  [ "${lines[1]}" = "mvn clean install -D${JBOSS_CODE} -Dstandalone" ]
}

@test "Simple run with customized setting.xml" {
  export SETTINGS_XML="$(mktemp --suffix .xml)"
  run "${RUN_EAT}" "${JBOSS_CODE}"
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "Runing EAT on JBoss server: ${JBOSS_FOLDER} - using extra opts: " ]
  [ "${lines[1]}" = "mvn clean install -D${JBOSS_CODE} -Dstandalone -s ${SETTINGS_XML}" ]
  rm -rf "${SETTINGS_XML}"
}

@test "Simple run with extra opts" {
  export EAT_EXTRA_OPTS='-Dnative'
  run "${RUN_EAT}" "${JBOSS_CODE}"
  echo "${lines[1]}"
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "Runing EAT on JBoss server: ${JBOSS_FOLDER} - using extra opts: ${EAT_EXTRA_OPTS}" ]
  [ "${lines[1]}" = "mvn clean install -D${JBOSS_CODE} -Dstandalone ${EAT_EXTRA_OPTS}" ]
  rm -rf "${SETTINGS_XML}"
}
