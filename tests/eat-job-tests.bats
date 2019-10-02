#!/bin/bash

readonly SCRIPT_NAME='eat-job.sh'
source ./tests/tests-common.sh

setup() {
  export MAVEN_HOME=$(mktemp -d)
  mkdir -p "${MAVEN_HOME}/bin"
  cp "${DUMMY_MVN}" "${MAVEN_HOME}/bin/"
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
  run "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ ${output} == *"Missing JBOSS_VERSION_CODE (eap7, eap64,...)."* ]]
}

@test "No Maven Home provided" {
  export MAVEN_HOME=""
  run "${SCRIPT}" "${JBOSS_CODE}"
  [ "${status}" -eq 2 ]
  [  "${output}" = 'No MAVEN_HOME has been defined.' ]
}

@test "Maven Home provided is not a directory" {
  rm -rf ${MAVEN_HOME}
  export MAVEN_HOME=$(mktemp)
  run "${SCRIPT}" "${JBOSS_CODE}"
  [ "${status}" -eq 4 ]
  [ "${output}" = "Provided MAVEN_HOME is not a directory: ${MAVEN_HOME}" ]
}

@test "Maven Home provided does not exist" {
  export MAVEN_HOME="$(mktemp).not.exist"
  run "${SCRIPT}" "${JBOSS_CODE}"
  [ "${status}" -eq 3 ]
  [ "${output}" = "Provided MAVEN_HOME does not exist: ${MAVEN_HOME}" ]
  rm -rf "${MAVEN_HOME%.not.exist}"
}

@test "Simple run" {
  export MAVEN_SETTINGS_XML=''
  run "${SCRIPT}" "${JBOSS_CODE}"
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "Runing EAT on JBoss server: ${JBOSS_FOLDER} - using extra opts: " ]
  [ "${lines[1]}" = "mvn clean install -D${JBOSS_CODE} -Dstandalone" ]
}

@test "Simple run with customized setting.xml" {
  export MAVEN_SETTINGS_XML="$(mktemp --suffix .xml)"
  run "${SCRIPT}" "${JBOSS_CODE}"
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "Runing EAT on JBoss server: ${JBOSS_FOLDER} - using extra opts: " ]
  [ "${lines[1]}" = "mvn clean install -D${JBOSS_CODE} -Dstandalone -s ${MAVEN_SETTINGS_XML-}" ]
  rm -rf "${SETTINGS_XML}"
}

@test "Simple run with extra opts" {
  export MAVEN_SETTINGS_XML=''
  export EAT_EXTRA_OPTS='-Dnative'
  run "${SCRIPT}" "${JBOSS_CODE}"
  echo "${lines[1]}"
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "Runing EAT on JBoss server: ${JBOSS_FOLDER} - using extra opts: ${EAT_EXTRA_OPTS}" ]
  [ "${lines[1]}" = "mvn clean install -D${JBOSS_CODE} -Dstandalone ${EAT_EXTRA_OPTS}" ]
  rm -rf "${SETTINGS_XML}"
}
