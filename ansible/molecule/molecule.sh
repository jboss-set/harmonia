#!/bin/bash
set -euo pipefail


readonly HERA_HOME=${HERA_HOME:-"${WORKSPACE}/hera"}
export HERA_HOME
readonly ERIS_HOME=${ERIS_HOME:-"${WORKSPACE}/eris"}
export ERIS_HOME

readonly WORKDIR=${WORKDIR:-"$(pwd)/workdir"}
readonly WORKSPACE=${WORKSPACE}
readonly SCENARIO_NAME=${SCENARIO_NAME:-'--all'}
readonly SCENARIO_DRIVER_NAME=${2:-'delegated'}

readonly SCENARIO_HERA_DRIVER_DIR="${WORKSPACE}/eris/molecule/olympus/"

readonly MOLECULE_CACHE_ROOT=${MOLECULE_CACHE_ROOT:-"${HOME}/.cache/molecule/"}

source "$(dirname $(realpath ${0}))/common.sh"

checkWorkspaceIsDefinedAndExists

checkWorkdirExistsAndSetAsDefault

cleanMoleculeCache "${MOLECULE_CACHE_ROOT}/${JOB_NAME}"

installPythonRequirementsIfAny "${WORKDIR}/${PYTHON_REQUIREMENTS_FILE}"

configureAnsible "${ANSIBLE_CONFIG}" "${WORKDIR}"

ansibleGalaxyCollectionInstallFromRequirementFile

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
