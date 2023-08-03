#!/bin/bash
set -eo pipefail

readonly PLAYBOOK=${PLAYBOOK:-'playbooks/playbook.yml'}
readonly VALIDATION_PLAYBOOK=${VALIDATION_PLAYBOOK:-'playbooks/validate.yml'}
readonly PATH_TO_PLAYBOOK=${PATH_TO_PLAYBOOK:-"${WORKDIR}/${PLAYBOOK}"}
readonly PATH_TO_INVENTORY_FILE=${PATH_TO_INVENTORY_FILE:-"${WORKDIR}/inventory"}
readonly ANSIBLE_VERBOSITY_LEVEL=${ANSIBLE_VERBOSITY_LEVEL}
readonly JBOSS_NETWORK_API_CREDENTIAL_FILE=${JBOSS_NETWORK_API_CREDENTIAL_FILE:-'/var/jenkins_home/jboss_network_api.yml'}

set -u

source "$(dirname $(realpath ${0}))/common.sh"

checkWorkdirExistsAndSetAsDefault

configureAnsible "${ANSIBLE_CONFIG}" "${WORKDIR}"

if [ ! -e "${PATH_TO_INVENTORY_FILE}" ]; then
  echo '[all]' >> "${PATH_TO_INVENTORY_FILE}"
  echo 'localhost ansible_connection=local' >> "${PATH_TO_INVENTORY_FILE}"
fi

ansible-playbook --version

echo "Install requirements (dependencies)."
ansibleGalaxyCollectionInstallFromRequirementFile

echo "Install collection from Janus builds."
# TODO

ansible-playbook ${ANSIBLE_VERBOSITY_LEVEL} -i "${PATH_TO_INVENTORY_FILE}" $(loadJBossNetworkAPISecrets) "${PLAYBOOK}"
ansible-playbook ${ANSIBLE_VERBOSITY_LEVEL} -i "${PATH_TO_INVENTORY_FILE}" "${VALIDATION_PLAYBOOK}"
