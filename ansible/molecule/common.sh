#!/bin/bash

source "$(dirname $(realpath "${0}"))/../common.sh"

HERA_HOME=${HERA_HOME:-"${WORKSPACE}/hera"}
export HERA_HOME
ERIS_HOME=${ERIS_HOME:-"${WORKSPACE}/eris"}
export ERIS_HOME

MOLECULE_DEBUG=${MOLECULE_DEBUG:-'--no-debug'}
MOLECULE_KEEP_CACHE=${MOLECULE_KEEP_CACHE:-''}

determineMoleculeVersion() {
  echo "$(molecule --version | head -1 | sed -e 's/using python .*$//' -e 's/^molecule *//' -e 's/ //g' | grep -e '4' | wc -l )"
}

determineMoleculeSlaveImage() {
  if [ "$(determineMoleculeVersion)" -eq 1 ]; then
    echo "localhost/molecule-slave"
  else
    echo "localhost/molecule-slave-9"
  fi

}

determineMoleculeDriverName() {

  if [ "$(determineMoleculeVersion)" -eq 1 ]; then
    echo "delegated"
  else
    echo "default"
  fi
}

readonly HARMONIA_MOLECULE_DEFAULT_DRIVER_NAME=$(determineMoleculeDriverName)
echo "DEBUG> ${HARMONIA_MOLECULE_DEFAULT_DRIVER_NAME}"
readonly HERA_MOLECULE_SLAVE_IMAGE=$(determineMoleculeSlaveImage)
export HERA_MOLECULE_SLAVE_IMAGE

deployHeraDriver() {
  local molecule_source_dir=${1}
  local molecule_hera_driver_dir=${2:-"${WORKSPACE}/eris/molecule/olympus/"}

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
   molecule ${MOLECULE_DEBUG} test ${config_scenario} ${scenario_driver_name} -- --ssh-extra-args="-o StrictHostKeyChecking=no" ${extra_args}
}

executeRequestedScenarios() {
  local scenario_name=${1}
  local scenario_driver_name=${2}
  local extra_args=${3}

  declare -A scenarios_status
  # shellcheck disable=SC2001
  for scenario in $(echo "${scenario_name}" | sed -e 's;,;\n;g')
  do
    # shellcheck disable=SC2086
    runMolecule "-s ${scenario}" "-d ${scenario_driver_name}" "${extra_args}"
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
  local scenario_driver_name=${2:-"${HARMONIA_MOLECULE_DEFAULT_DRIVER_NAME}"}
  local extra_args=${3:-"${EXTRA_ARGS}"}

  set +e
  MOLECULE_RUN_STATUS=0
  if [ "${scenario_name}" != '--all' ]; then
    executeRequestedScenarios "${scenario_name}" "${scenario_driver_name}" "${extra_args}"
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

useScenarioNameIfExists() {
  local scenario_name=${1}
  local workdir=${2}

  if [ -d "${workdir}/molecule/${scenario_name}" ]; then
    echo "${scenario_name}"
  fi
}

installErisCollection() {
  local eris_home=${1:-"${ERIS_HOME}"}
  local collection=${2:-'middleware_automation-eris'}

  cd "${eris_home}"
  rm -f "${collection}"-*.tar.gz
  ansible-galaxy collection build .
  ansible-galaxy collection install "${collection}"-*.tar.gz
  cd -
}

cleanMoleculeCache() {
  local path_to_cache=${1:-"${HOME}/.cache/molecule/${JOB_NAME}"}

  if [ -z "${MOLECULE_KEEP_CACHE}" ]; then
    if [ -e "${path_to_cache}" ]; then # just to avoid running rm -rf on an invalid path...
      rm -rf "${path_to_cache}"
    fi
  fi
}

generateRequirementsFromCItemplateIfProvided() {
  local path_to_collection_archive=${1}
  local path_to_requirements_file=${2}
  local path_to_template=${3}

  if [ ! -e "${path_to_template}" ]; then
    echo "Path to template to generate requirements.yml is invalid: ${path_to_template}, aborting."
    exit 4
  fi

  if [ -e "${path_to_collection_archive}" ]; then
    ansible -m template \
            -a "src=${path_to_template} dest=${path_to_requirements_file}" \
            -e path_to_collection="${path_to_collection_archive}" \
            localhost
  else
    echo "Invalid path to collection (does not exists or not a directory): ${path_to_collection_archive}."
    exit 5
  fi
}

copyCollectionFrom() {
  local path_to_collection=${1}
  local workdir=${WORKDIR:-"${2}"}

  if [ -d "${path_to_collection}" ]; then
    rm -rf "${workdir:?}"/*
    echo -n "Fetching last build from ${path_to_collection}..."
    cp -r "${path_to_collection}"/* "${workdir}"
    cp "${path_to_collection}/.ansible-lint" "${workdir}"
    cp "${path_to_collection}/.yamllint" "${workdir}"
    echo 'Done.'
  else
    echo "Invalid path to collection (does not exists or not a directory): ${path_to_collection}."
    exit 5
  fi
}
