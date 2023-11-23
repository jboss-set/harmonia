#!/bin/bash
set -eo pipefail

source "$(dirname $(realpath ${0}))/common.sh"

readonly PLAYBOOK=${PLAYBOOK:-"${DOWNSTREAM_NS}.${PROJECT_NAME}.playbook"}
readonly VALIDATION_PLAYBOOK=${VALIDATION_PLAYBOOK:-"${DOWNSTREAM_NS}.${PROJECT_NAME}.validate"}
readonly PATH_TO_PLAYBOOK=${PATH_TO_PLAYBOOK:-"${WORKDIR}/${PLAYBOOK}"}
readonly PATH_TO_INVENTORY_FILE=${PATH_TO_INVENTORY_FILE:-"${WORKDIR}/inventory"}
readonly ANSIBLE_VERBOSITY_LEVEL=${ANSIBLE_VERBOSITY_LEVEL}
readonly JBOSS_NETWORK_API_CREDENTIAL_FILE=${JBOSS_NETWORK_API_CREDENTIAL_FILE:-'/var/jenkins_home/jboss_network_api.yml'}
readonly INVENTORY_LOCALHOST='localhost ansible_connection=local'

set -u

addEntryToInventoryFile() {
  local section=${1}
  local content=${2}

  echo "${section}"
  echo "${content}"
  echo ""
}

checkWorkdirExistsAndSetAsDefault

configureAnsible "${ANSIBLE_CONFIG}" "${WORKDIR}"

if [ ! -e "${PATH_TO_INVENTORY_FILE}" ]; then
  for entry in '[all]' '[zookeepers]' '[brokers]'
  do
    addEntryToInventoryFile "${entry}" "${INVENTORY_LOCALHOST}" >> "${PATH_TO_INVENTORY_FILE}"
  done
fi

ansible-playbook --version

echo "Install requirements (dependencies)."
ansibleGalaxyCollectionInstallFromRequirementFile

echo "Install collection from Janus builds."
path_to_builds=${JENKINS_JOBS_DIR}/ansible-janus-${PROJECT_NAME}/builds
last_build_id=$(getLastBuildId "${path_to_builds}")
path_to_collection_archive=$(getPathToCollectionTarball "${path_to_builds}/${last_build_id}/archive/workdir/downstream/" "${PROJECT_NAME}")
ansibleGalaxyCollectionInstall "${path_to_collection_archive}"

echo ${PLAYBOOK}/${VALIDATION_PLAYBOOK}

ansible-playbook ${ANSIBLE_VERBOSITY_LEVEL} -i "${PATH_TO_INVENTORY_FILE}" $(loadJBossNetworkAPISecrets) "${PLAYBOOK}"
ansible-playbook ${ANSIBLE_VERBOSITY_LEVEL} -i "${PATH_TO_INVENTORY_FILE}" "${VALIDATION_PLAYBOOK}"
