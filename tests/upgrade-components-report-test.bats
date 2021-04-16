#!/bin/bash
readonly SCRIPT_NAME='upgrade-components-report.sh'
source ./tests/tests-common.sh

readonly USAGE_OUTPUT='[email] [rule-name] [target-dir] [report-title] [project-code]'
readonly MAIL_COMMAND='mutt'

createDummyJavaCommand() {
  # created dummy command creates a report file and prints arguments to stdout
  local command="java"
  echo 'echo ${@}' > "${command}"
  echo 'echo "Dummy content" > ${REPORT_FILE}' >> "${command}"
  chmod +x "${command}"
}

setup() {
  export REPORT_FILE="$(mktemp)"
  export CONFIG="$(mktemp)"

  # dummy java cmd, just printing the args
  createDummyJavaCommand
  createDummyCommand "${MAIL_COMMAND}"
  export PATH=.:${PATH}
  # override env
  export JBOSS_USER_HOME="$(mktemp -d)"
  readonly CLI="${JBOSS_USER_HOME}/alignment-cli.jar"
  touch "${CLI}"
}

teardown() {
  deleteIfExist './java'
  deleteIfExist "${MAIL_COMMAND}"
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
  local project_code=${6}

  export LOGGER_URI='URI'
  local expected_result="-Dlogger.projectCode=${project_code} -Dlogger.uri=${LOGGER_URI} -jar ${CLI} generate-html-report -c ${CONFIG} -f ${target_dir}/pom.xml -o ${REPORT_FILE}"
  run "${SCRIPT}" "${email}" "${rule_name}" "${target_dir}" "${report_title}" "${project_code}"
  echo "${lines[1]}"
  echo "${expected_result}"
  [ "${status}" -eq 0 ]
  [ "${lines[1]}" = "${expected_result}" ]
}

@test "Test usage" {
  run "${SCRIPT}" -h
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "${SCRIPT_NAME} ${USAGE_OUTPUT}" ]
}

@test "Test missing email" {
  run "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [ "${lines[0]}" = 'Missing email adress.' ]
  [ "${lines[1]}" = "${SCRIPT_NAME} ${USAGE_OUTPUT}" ]
}

@test "Test missing rule name" {
  run "${SCRIPT}" bob@mike.com
  [ "${status}" -eq 2 ]
  [ "${lines[0]}" = 'Missing rule name.'  ]
  [ "${lines[1]}" = "${SCRIPT_NAME} ${USAGE_OUTPUT}" ]
}

@test "Test missing target dir" {
  run "${SCRIPT}" bob@mike.com rule-name
  [ "${status}" -eq 3 ]
  [ "${lines[0]}" = 'Missing target dir.' ]
  [ "${lines[1]}" = "${SCRIPT_NAME} ${USAGE_OUTPUT}" ]
}

@test "Test case: Wildfly Core" {
  local email='rpelisse@redhat.com'
  local rule_name='wildfly-master'
  local target_dir='wildfly-core'
  local report_title='Wildfly Core'
  local from_address='thofman@redhat.com'
  local project_code='project-code'

  run_test_case "${email}" "${rule_name}" "${target_dir}" "${report_title}" "${from_address}" "${project_code}"
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

