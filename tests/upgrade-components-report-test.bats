#!/bin/bash

readonly SCRIPT_NAME='upgrade-components-report.sh'
source ./tests/tests-common.sh

readonly INTEGRATION_TESTS_SCRIPT='integration-tests.sh'

setup() {
  # dummy java cmd, just printing the args
  createDummyCommand 'java'
  createDummyCommand 'mail'
  export PATH=.:${PATH}
  # override env
  export JBOSS_USER_HOME="$(mktemp -d)"
  readonly CLI="${JBOSS_USER_HOME}/alignment-cli.jar"
  touch "${CLI}"
  export REPORT_FILE="$(mktemp)"
  echo "Dummy content" > "${REPORT_FILE}"
  export CONFIG="$(mktemp)"
}

teardown() {
  deleteIfExist './java'
  deleteIfExist './mail'
  deleteIfExist "${REPORT_FILE}"
  deleteIfExist "${CLI}"
  deleteIfExist "${JBOSS_USER_HOME}"
  deleteIfExist "${CONFIG}"
}

run_test_case() {
  local email=${1}
  local rule_name=${2}
  local target_dir=${3}
  local report_title=${4}
  local from_address=${5}

  run "${SCRIPT}" "${email}" "${rule_name}" "${target_dir}" "${report_title}"
  [ "${status}" -eq 0 ]
  [ "${lines[2]}" = "-jar ${CLI} generate-report -c ${CONFIG} -f ${target_dir}/pom.xml -o ${REPORT_FILE}" ]
  [ "${lines[3]}" = "-a ${REPORT_FILE} -s Possible component upgrades report - ${report_title} -r ${from_address} ${email}" ]
}

@test "Test usage" {
  run "${SCRIPT}" -h
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "${SCRIPT_NAME} [email] [rule-name] [target-dir] [report-title]" ]
}

@test "Test missing email" {
  run "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [ "${lines[0]}" = 'Missing email adress.' ]
  [ "${lines[1]}" = "${SCRIPT_NAME} [email] [rule-name] [target-dir] [report-title]" ]
}

@test "Test missing rule name" {
  run "${SCRIPT}" bob@mike.com
  [ "${status}" -eq 2 ]
  [ "${lines[0]}" = 'Missing rule name.'  ]
  [ "${lines[1]}" = "${SCRIPT_NAME} [email] [rule-name] [target-dir] [report-title]" ]
}

@test "Test missing target dir" {
  run "${SCRIPT}" bob@mike.com rule-name
  [ "${status}" -eq 3 ]
  [ "${lines[0]}" = 'Missing target dir.' ]
  [ "${lines[1]}" = "${SCRIPT_NAME} [email] [rule-name] [target-dir] [report-title]" ]
}

@test "Test case: Wildfly Core" {
  local email='rpelisse@redhat.com'
  local rule_name='wildfly-master'
  local target_dir='wildfly-core'
  local report_title='Wildfly Core'
  local from_address='thofman@redhat.com'

  run_test_case "${email}" "${rule_name}" "${target_dir}" "${report_title}" "${from_address}"
}

@test "Test case: Elytron Web" {
  local email='rpelisse@redhat.com'
  local rule_name='elytron-1x'
  local target_dir='elytron-web'
  local report_title='Elytron Web'
  local from_address='thofman@redhat.com'

  run_test_case "${email}" "${rule_name}" "${target_dir}" "${report_title}" "${from_address}"
}

@test "Test case: Wildfly Elytron" {
  local email='jboss-set@redhat.com'
  local rule_name='elytron-1x'
  local target_dir='wildfly-elytron'
  local report_title='Wildfly Elytron'
  local from_address='thofman@redhat.com'

  run_test_case "${email}" "${rule_name}" "${target_dir}" "${report_title}" "${from_address}"
}

@test "Test case: Wildfly Master" {
  local email='jboss-set@redhat.com'
  local rule_name='wildfly-master'
  local target_dir='wildfly'
  local report_title='Wildfly'
  local from_address='thofman@redhat.com'

  run_test_case "${email}" "${rule_name}" "${target_dir}" "${report_title}" "${from_address}"
}

@test "Test case: Override From address" {
  local email='jboss-set@redhat.com'
  local rule_name='wildfly-master'
  local target_dir='wildfly'
  local report_title='Wildfly'
  local from_address='jboss-set@redhat.com'

  export FROM_ADDRESS="${from_address}"

  run_test_case "${email}" "${rule_name}" "${target_dir}" "${report_title}" "${from_address}"
}

