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

  echo -n "Create Olympus config setup from ${molecule_source_dir}" to "${molecule_hera_dir}..."
  cp -r "${molecule_source_dir}" "${molecule_hera_dir}"
  echo "Done."

  for file in create.yml destroy.yml
  do
    echo -n  "Deploying ${file} into ${molecule_hera_dir} ..."
    cp "${molecule_hera_driver_dir}/${file}" "${molecule_hera_dir}"
    echo 'Done.'
  done
}

determineExistingScenarioName() {
  local molecule_dir=${1}

  for scenario_name in default standalone
  do
    local scenario_dir=${molecule_dir}/${scenario_name}
    if [ -d "${scenario_dir}" ]; then
      echo "${scenario_dir}"
      return
    fi
  done
}

runMoleculeScenario() {
  local scenario_name=${1:-"${SCENARIO_NAME}"}
  local scenario_driver_name=${2:-"${SCENARIO_DRIVER_NAME}"}

  set +e
  # shellcheck disable=SC2086
  molecule ${MOLECULE_DEBUG} test -s "${scenario_name}" -d "${scenario_driver_name}"
  readonly MOLECULE_RUN_STATUS="${?}"
  set -e
  if [ "${MOLECULE_RUN_STATUS}" -ne 0 ]; then
    echo "MOLECULE_EXIT_CODE: ${MOLECULE_RUN_STATUS}."
  fi
  return ${MOLECULE_RUN_STATUS}
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
readonly WORKDIR=${WORKDIR:-"$(pwd)/workdir"}
readonly MOLECULE_DEBUG=${DEBUG:-'--no-debug'}
readonly SCENARIO_NAME=${1:-'olympus'}
readonly SCENARIO_DRIVER_NAME=${2:-'delegated'}
readonly SCENARIO_DEFAULT_NAME=${SCENARIO_DEFAULT_NAME:-'molecule/default'}

readonly SCENARIO_DEFAULT_DIR="${WORKDIR}/${SCENARIO_DEFAULT_NAME}"
readonly SCENARIO_HERA_BRANCH="${WORKDIR}/molecule/olympus"
readonly SCENARIO_HERA_DRIVER_DIR="${WORKSPACE}/olympus/molecule/olympus/"

molecule --version

deployHeraDriver $(determineExistingScenarioName "${WORKDIR}/molecule") "${SCENARIO_HERA_BRANCH}" "${SCENARIO_HERA_DRIVER_DIR}"


cd "${WORKDIR}" > /dev/null
echo "Running Molecule test on project: ${JOB_NAME}..."
runMoleculeScenario
exit "${MOLECULE_RUN_STATUS}"
