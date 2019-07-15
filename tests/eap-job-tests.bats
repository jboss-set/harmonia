#!/bin/bash

readonly SCRIPT_NAME='eap-job.sh'
source ./tests/tests-common.sh

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
  [ "${lines[-1]}" = 'mvn clean install -B' ]
}
