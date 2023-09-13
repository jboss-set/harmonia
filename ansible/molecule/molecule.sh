#!/bin/bash
set -euo pipefail
source "$(dirname $(realpath ${0}))/common.sh"

readonly SCENARIO_NAME=${SCENARIO_NAME:-'--all'}

checkWorkspaceIsDefinedAndExists

checkWorkdirExistsAndSetAsDefault

cleanMoleculeCache

installPythonRequirementsIfAny

configureAnsible

ansibleGalaxyCollectionFromAllRequirementsFile

molecule --version

installErisCollection

setRequiredEnvVars
# shellcheck disable=SC2231
for scenario in ${WORKDIR}/molecule/*
do
  if [ -d "${scenario}" ]; then
    deployHeraDriver "${scenario}"
  fi
done

# shellcheck disable=SC2155
readonly EXTRA_ARGS="$(loadJBossNetworkAPISecrets)"
export EXTRA_ARGS

printEnv
echo "Running Molecule test on project: ${JOB_NAME}..."
set +u
runMoleculeScenario "${SCENARIO_NAME}" "${SCENARIO_DRIVER_NAME}" "${EXTRA_ARGS}"
set -u
exit "${MOLECULE_RUN_STATUS}"
