#!/bin/bash
readonly SCRIPT_NAME='pr-processor.sh'
source ./tests/tests-common.sh


readonly USAGE_OUTPUT='[email] [rule-name] [target-dir] [report-title] [project-code]'

setup() {
  export PULL_REQUEST_PROCESSOR_HOME="$(mktemp -d)"
  export APHRODITE_CONFIG="$(mktemp)"

  export PATH=.:${PATH}
  # override env
  export CLI_HOME="$(mktemp -d)"
  export PATH_TO_JAR="${CLI_HOME}/pr-processor.jar"
  touch "${PATH_TO_JAR}"
}

teardown() {
  deleteIfExist "${PULL_REQUEST_PROCESSOR_HOME}"
  deleteIfExist "${PATH_TO_JAR}"
  deleteIfExist "${CLI_HOME}"
  deleteIfExist "${APHRODITE_CONFIG}"
}

@test "Undefined PULL_REQUEST_PROCESSOR_HOME" {
  unset PULL_REQUEST_PROCESSOR_HOME

  run "${SCRIPT}"
  [ "${status}" -eq 1 ]
}

@test "PULL_REQUEST_PROCESSOR_HOME does not exist" {
  export PULL_REQUEST_PROCESSOR_HOME="/do/not/exist"

  run "${SCRIPT}"
  [ "${status}" -eq 2 ]
}

@test "PULL_REQUEST_PROCESSOR_HOME not a directory" {
  export PULL_REQUEST_PROCESSOR_HOME="$(mktemp)"

  run "${SCRIPT}"
  [ "${status}" -eq 2 ]
  rm -f "${PULL_REQUEST_PROCESSOR_HOME}"
}

@test "Undefined APHRODITE_CONFIG" {
  unset APHRODITE_CONFIG

  run "${SCRIPT}"
  [ "${status}" -eq 4 ]
}

@test "APHRODITE_CONFIG does not exist" {
  export APHRODITE_CONFIG="/do/not/exist"

  run "${SCRIPT}"
  [ "${status}" -eq 4 ]
}

@test "APHRODITE_CONFIG is a directory" {
  export APHRODITE_CONFIG="$(mktemp -d)"

  run "${SCRIPT}"
  [ "${status}" -eq 5 ]
  rmdir "${APHRODITE_CONFIG}"
}

@test "Simple working test case" {
  local expected_streams='-s jboss-eap-7.2.z[wildfly-wildfly,wildfly-wildfly-core] jboss-eap-7.3.z[wildfly-wildfly,wildfly-wildfly-core] -p jboss-eap-7.2.z[wildfly-wildfly,wildfly-wildfly-core] jboss-eap-7.3.z[wildfly-wildfly,wildfly-wildfly-core]'
  local expected_result="java -jar -Daphrodite.config=${APHRODITE_CONFIG} -DcacheDir=${PULL_REQUEST_PROCESSOR_HOME}/cache -DcacheName=github-cache -DcacheSize=20 ${PATH_TO_JAR} ${expected_streams} -f /report.html -w false"

  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  echo exp: ${expected_result}
  echo ${lines[0]}
  [ "${lines[0]}" = "${expected_result}" ]
}
