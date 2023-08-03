#!/bin/bash
set -euo pipefail

deployHeraDriver() {
  local molecule_source_dir=${1}
  local molecule_hera_driver_dir=${2}

  if [ -z "${molecule_source_dir}" ]; then
    echo "No ${molecule_source_dir} provided."
    exit 3
  fi

  for file in create.yml destroy.yml
  do
    echo -n  "Deploying ${file} into ${molecule_source_dir} ..."
    cp "${molecule_hera_driver_dir}/${file}" "${molecule_source_dir}/"
    echo 'Done.'
  done
}

runMolecule() {
  local config_scenario=${1}
  local scenario_driver_name=${2}
  local extra_args=${3}

   # shellcheck disable=SC2086
   molecule ${MOLECULE_DEBUG} test ${config_scenario} ${scenario_driver_name} -- --ssh-extra-args="-o StrictHostKeyChecking=no" "${extra_args}"
}

executeRequestedScenarios() {
  local scenario_name=${1}
  local scenario_driver_name=${2}

  declare -A scenarios_status
  # shellcheck disable=SC2001
  for scenario in $(echo "${scenario_name}" | sed -e 's;,;\n;g')
  do

    # shellcheck disable=SC2086
    runMolecule "-s ${scenario}" "-d ${scenario_driver_name}" -- "${extra_args}"
    scenarios_status["${scenario}"]=${?}
  done
  export MOLECULE_RUN_STATUS="$(echo "${scenarios_status[@]}" | grep -e 1 -c)"
  printScenariosThatFailed
}

printScenariosThatFailed() {
  for scenario in "${!scenarios_status[@]}"
  do
    scenario_status=${scenarios_status["${scenario}"]}
    if [ "${scenario_status}" -ne 0 ]; then
      echo "ERROR: Scenario: ${scenario} failed with status code: ${scenario_status}."
    fi
  done
}

runMoleculeScenario() {
  local scenario_name=${1:-"${SCENARIO_NAME}"}
  local scenario_driver_name=${2:-"${SCENARIO_DRIVER_NAME}"}
  local extra_args=${3:-"${EXTRA_ARGS}"}

  set +e
  MOLECULE_RUN_STATUS=0
  if [ "${scenario_name}" != '--all' ]; then
    executeRequestedScenarios "${scenario_name}" "${scenario_driver_name}" -- ${extra_args}
  else
    echo "DEBUG> molecule ${MOLECULE_DEBUG} test "${scenario_name}" -d "${scenario_driver_name}" -- ${extra_args}"
    # shellcheck disable=SC2086
    molecule ${MOLECULE_DEBUG} test "${scenario_name}" -d "${scenario_driver_name}" -- ${extra_args}
    MOLECULE_RUN_STATUS="${?}"
  fi
  readonly MOLECULE_RUN_STATUS

  set -e
  if [ "${MOLECULE_RUN_STATUS}" -ne 0 ]; then
    echo "MOLECULE_EXIT_CODE: ${MOLECULE_RUN_STATUS}."
  fi
  return ${MOLECULE_RUN_STATUS}
}

installPythonRequirementsIfAny() {
  local requirementsFile=${1}

  if [ -n "${requirementsFile}" ]; then
    echo "Checks if ${requirementsFile} exists..."
    if [ -e "${requirementsFile}" ]; then
      echo 'It does, performing required installations.'
      echo "Install Python dependencies provided in ${requirementsFile}:"
      "${PIP_COMMAND}" install --user -r "${requirementsFile}"
      echo 'Done.'
    else
      echo 'File does not exists. Skipping.'
    fi
  fi
}

installAnsibleDependencyIfAny() {
  local requirements_yml=${1}

  if [ -e "${requirements_yml}" ]; then
    ansible-galaxy collection install -r "${requirements_yml}"
  fi
}

configureAnsible() {
  local path_to_ansible_cfg=${1}
  local workdir=${2}

  echo -n "Copying ansible.cfg from ${path_to_ansible_cfg} to ${workdir}..."
  if [ -e "${path_to_ansible_cfg}" ]; then
    cp "${path_to_ansible_cfg}" "${workdir}"
    echo Done
  else
    echo " No such file, skip."
  fi
}

useScenarioNameIfExists() {
  local scenario_name=${1}
  local workdir=${2}

  if [ -d "${workdir}/molecule/${scenario_name}" ]; then
    echo "${scenario_name}"
  fi
}

installErisCollection() {
  local eris_home=${1}
  local collection=${2:-'middleware_automation-eris'}

  cd "${eris_home}"
  rm -f "${collection}"-*.tar.gz
  ansible-galaxy collection build .
  ansible-galaxy collection install "${collection}"-*.tar.gz
  cd -
}

printEnv() {
  set +u
  if [ -n "${HERA_DEBUG}" ]; then
    echo ==========
    env
    echo ==========
  fi
  set -u
}

cleanMoleculeCache() {
  local path_to_cache=${1}

  if [ -z "${MOLECULE_KEEP_CACHE}" ]; then
    if [ -e "${path_to_cache}" ]; then # just to avoid running rm -rf on an invalid path...
      rm -rf "${path_to_cache}"
    fi
  fi
}

setRequiredEnvVars() {
  export ANSIBLE_HOST_KEY_CHECKING='False'
}

readonly WORKSPACE=${WORKSPACE}

if [ -z "${WORKSPACE}" ]; then
  echo "WORKSPACE is undefined, aborting."
  exit 1
fi

if [ ! -d "${WORKSPACE}" ]; then
  echo "WORKSPACE is not a directory, aborting."
  exit 2
fi

readonly HERA_HOME=${HERA_HOME:-"${WORKSPACE}/hera"}
export HERA_HOME
readonly ERIS_HOME=${ERIS_HOME:-"${WORKSPACE}/eris"}
export ERIS_HOME

readonly WORKDIR=${WORKDIR:-"$(pwd)/workdir"}
readonly MOLECULE_DEBUG=${MOLECULE_DEBUG:-'--no-debug'}
readonly SCENARIO_NAME=${SCENARIO_NAME:-'--all'}
readonly SCENARIO_DRIVER_NAME=${2:-'delegated'}

readonly SCENARIO_HERA_DRIVER_DIR="${WORKSPACE}/eris/molecule/olympus/"
readonly ANSIBLE_CONFIG=${ANSIBLE_CONFIG:-'/var/jenkins_home/ansible.cfg'}
readonly PYTHON_REQUIREMENTS_FILE=${PYTHON_REQUIREMENTS_FILE:-'requirements.txt'}
readonly ANSIBLE_REQUIREMENTS_FILE=${ANSIBLE_REQUIREMENTS_FILE:-'requirements.yml'}
readonly PIP_COMMAND=${PIP_COMMAND:-'pip-3.8'}

readonly MOLECULE_CACHE_ROOT=${MOLECULE_CACHE_ROOT:-"${HOME}/.cache/molecule/"}
readonly MOLECULE_KEEP_CACHE=${MOLECULE_KEEP_CACHE:-''}

cleanMoleculeCache "${MOLECULE_CACHE_ROOT}/${JOB_NAME}"

installPythonRequirementsIfAny "${WORKDIR}/${PYTHON_REQUIREMENTS_FILE}"

configureAnsible "${ANSIBLE_CONFIG}" "${WORKDIR}"

installAnsibleDependencyIfAny "${ANSIBLE_REQUIREMENTS_FILE}"

molecule --version

installErisCollection "${ERIS_HOME}"

setRequiredEnvVars
# shellcheck disable=SC2231
for scenario in ${WORKDIR}/molecule/*
do
  if [ -d "${scenario}" ]; then
    deployHeraDriver "${scenario}" "${SCENARIO_HERA_DRIVER_DIR}"
  fi
done

cd "${WORKDIR}" > /dev/null
printEnv
echo "Running Molecule test on project: ${JOB_NAME}..."
set +u
runMoleculeScenario "${SCENARIO_NAME}" "${SCENARIO_DRIVER_NAME}" "${EXTRA_ARGS}"
set -u
exit "${MOLECULE_RUN_STATUS}"
