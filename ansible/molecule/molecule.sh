#!/bin/bash
set -eo pipefail
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

echo "REDHAT_PRODUCT_DOWNLOAD_CLIENT_ID_ENV_VAR=${REDHAT_PRODUCT_DOWNLOAD_CLIENT_ID_ENV_VAR}"
echo "REDHAT_PRODUCT_DOWNLOAD_CLIENT_SECRET_ENV_VAR=${REDHAT_PRODUCT_DOWNLOAD_CLIENT_SECRET_ENV_VAR}"

printEnv
echo "Running Molecule test on project: ${JOB_NAME}..."
set +u
runMoleculeScenario "${SCENARIO_NAME}" "${SCENARIO_DRIVER_NAME}" "${EXTRA_ARGS}"
set -u
exit "${MOLECULE_RUN_STATUS}"
