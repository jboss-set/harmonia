#!/bin/bash

readonly SCRIPT_NAME='eap-job.sh'
source ./tests/tests-common.sh

readonly INTEGRATION_TESTS_SCRIPT='integration-tests.sh'

setup() {
  export MAVEN_HOME=$(mktemp -d)
  mkdir ${MAVEN_HOME}/bin
  cp "${DUMMY_MVN}" "${MAVEN_HOME}/bin/"
  createDummyJavaCommand
  export JBOSS_FOLDER=$(mktemp -d)
  export WORKSPACE=$(mktemp -d)

  echo 'echo @{@}' > "${WORKSPACE}/${INTEGRATION_TESTS_SCRIPT}"
}

teardown() {
  deleteDummyJavaCommand
  deleteIfExist "${MAVEN_HOME}"
  deleteIfExist "${JBOSS_FOLDER}"
  deleteIfExist "${WORKSPACE}"
  deleteIfExist "${WORKSPACE}/${INTEGRATION_TESTS_SCRIPT}"
  unset MAVEN_HOME
  unset JBOSS_FOLDER

}

@test "Test usage" {
  run "${SCRIPT}" -h
  [ "${status}" -eq 0 ]
  echo ${lines[0]}
  [ "${lines[0]}" = 'eap-job.sh <build|testsuite> [extra-args]' ]
}

@test "Test extra argument with build command" {
  local extra_arg='-Dsome.extra.arg'
  run "${SCRIPT}" 'build' "${extra_arg}"
  [ "${status}" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" = "mvn clean install -fae -s /home/master/settings.xml -B ${extra_arg}" ]
}

@test "Run with default settings.xml" {
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" = 'mvn clean install -fae -s /home/master/settings.xml -B' ]
}

@test "No settings.xml provided" {
  export MAVEN_SETTINGS_XML=''
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" = 'mvn clean install -fae -B' ]
}
