#!/bin/bash
set -euo pipefail

deployHeraDriver() {
  local molecule_source_dir=${1}
  local molecule_hera_dir=${2}
  local molecule_hera_driver_dir=${3}

  if [ -z "${molecule_source_dir}" ]; then
    echo "No ${molecule_source_dir} provided."
    exit 3
  fi

  echo -n "Create ${SCENARIO_NAME} config setup from ${molecule_source_dir}" to "${molecule_hera_dir}..."
  cp -r "${molecule_source_dir}" "${molecule_hera_dir}"
  echo "Done."

  for file in create.yml destroy.yml
  do
    echo -n  "Deploying ${file} into ${molecule_hera_dir} ..."
    cp "${molecule_hera_driver_dir}/${file}" "${molecule_hera_dir}"
    echo 'Done.'
  done
}

deployHeraDriverInAllScenario() {
  local molecule_dir=${1}
  local molecule_hera_dir=${2}
  local molecule_hera_driver_dir=${3}

  for scenario_name in "${molecule_dir}"/*
  do
    local scenario_dir=${molecule_dir}/$(basename "${scenario_name}")
    echo "DEBUG> ${scenario_dir}"
    if [ -d "${scenario_dir}" ]; then
      deployHeraDriver "${scenario_dir}" "${molecule_hera_dir}" "${molecule_hera_driver_dir}"
    fi
  done
}

runMoleculeScenario() {
  local scenario_driver_name=${1:-"${SCENARIO_DRIVER_NAME}"}

  set +e
  # shellcheck disable=SC2086
  molecule ${MOLECULE_DEBUG} test --all -d "${scenario_driver_name}"
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

install_eris_collection() {
  local eris_home=${1}
  local collection=${2:-'middleware_automation-eris'}
  pwd
  ls .
  cd "${eris_home}"
  rm -f "${collection}"-*.tar.gz
  ansible-galaxy collection build .
  ansible-galaxy collection install "${collection}"-*.tar.gz
  cd -
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
readonly SCENARIO_NAME=${1:-'olympus'}
readonly SCENARIO_DRIVER_NAME=${2:-'delegated'}
readonly SCENARIO_DEFAULT_NAME=${SCENARIO_DEFAULT_NAME:-'molecule/default'}

readonly SCENARIO_DEFAULT_DIR="${WORKDIR}/${SCENARIO_DEFAULT_NAME}"
readonly SCENARIO_HERA_BRANCH="${WORKDIR}/molecule/olympus"
readonly SCENARIO_HERA_DRIVER_DIR="${WORKSPACE}/eris/molecule/olympus/"
readonly PYTHON_REQUIREMENTS_FILE=${PYTHON_REQUIREMENTS_FILE:-'requirements.txt'}
readonly PIP_COMMAND=${PIP_COMMAND:-'pip-3.8'}

installRequirementsIfAny "${WORKDIR}/${PYTHON_REQUIREMENTS_FILE}"

molecule --version

install_eris_collection "${ERIS_HOME}"

deployHeraDriverInAllScenario "${WORKDIR}/molecule" "${SCENARIO_HERA_BRANCH}" "${SCENARIO_HERA_DRIVER_DIR}"

cd "${WORKDIR}" > /dev/null
echo "Running Molecule test on project: ${JOB_NAME}..."
runMoleculeScenario
exit "${MOLECULE_RUN_STATUS}"
