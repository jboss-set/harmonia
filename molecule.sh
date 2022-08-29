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

runMoleculeScenario() {
  local scenario_name=${1:-"${SCENARIO_NAME}"}
  local scenario_driver_name=${2:-"${SCENARIO_DRIVER_NAME}"}

  set +e
  if [ "${scenario_name}" != '--all' ]; then
    for scenario in $(echo ${scenario_name} | sed -e 's;,;\n;g')
    do
      # shellcheck disable=SC2086
      molecule ${MOLECULE_DEBUG} test -s "${scenario}" -d "${scenario_driver_name}"
    done
  else
   # shellcheck disable=SC2086
    molecule ${MOLECULE_DEBUG} test "${scenario_name}" -d "${scenario_driver_name}"
  fi
  readonly MOLECULE_RUN_STATUS="${?}"

  set -e
  if [ "${MOLECULE_RUN_STATUS}" -ne 0 ]; then
    echo "MOLECULE_EXIT_CODE: ${MOLECULE_RUN_STATUS}."
  fi
  return ${MOLECULE_RUN_STATUS}
}

installRequirementsIfAny() {
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

configureAnsible() {
  local path_to_ansible_cfg=${1}
  local workdir=${2}

  if [ -e "${path_to_ansible_cfg}" ]; then
    cp "${path_to_ansible_cfg}" "${workdir}"
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
readonly MOLECULE_DEBUG=${DEBUG:-'--no-debug'}
readonly SCENARIO_NAME=${SCENARIO_NAME:-'--all'}
readonly SCENARIO_DRIVER_NAME=${2:-'delegated'}

readonly SCENARIO_HERA_DRIVER_DIR="${WORKSPACE}/eris/molecule/olympus/"
readonly ANSIBLE_CONFIG=${ANSIBLE_CONFIG:-'/var/jenkins_home/ansible.cfg'}
readonly PYTHON_REQUIREMENTS_FILE=${PYTHON_REQUIREMENTS_FILE:-'requirements.txt'}
readonly PIP_COMMAND=${PIP_COMMAND:-'pip-3.8'}

installRequirementsIfAny "${WORKDIR}/${PYTHON_REQUIREMENTS_FILE}"

configureAnsible "${ANSIBLE_CONFIG}" "${WORKDIR}"

molecule --version

installErisCollection "${ERIS_HOME}"

# shellcheck disable=SC2231
for scenario in ${WORKDIR}/molecule/*
do
  if [ -d "${scenario}" ]; then
    deployHeraDriver "${scenario}" "${SCENARIO_HERA_DRIVER_DIR}"
  fi
done

set -x
cd "${WORKDIR}" > /dev/null
printEnv
echo "Running Molecule test on project: ${JOB_NAME}..."
runMoleculeScenario
exit "${MOLECULE_RUN_STATUS}"
