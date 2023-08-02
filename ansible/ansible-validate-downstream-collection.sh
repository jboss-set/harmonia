#!/bin/bash
set -eo pipefail

if [ ! -d "${WORKDIR}" ]; then
  echo "WORKDIR ${WORKDIR} does not exists or is not a directory."
  exit 1
fi
readonly HARMONIA_HOME=${HARMONIA_HOME:-"${WORKSPACE}/harmonia"}
readonly PLAYBOOK=${PLAYBOOK:-'playbooks/playbook.yml'}
readonly VALIDATION_PLAYBOOK=${VALIDATION_PLAYBOOK:-'playbooks/validate.yml'}
readonly PATH_TO_PLAYBOOK=${PATH_TO_PLAYBOOK:-"${WORKDIR}/${PLAYBOOK}"}
readonly PATH_TO_INVENTORY_FILE=${PATH_TO_INVENTORY_FILE:-"${WORKDIR}/inventory"}
readonly ANSIBLE_VERBOSITY_LEVEL=${ANSIBLE_VERBOSITY_LEVEL}
readonly PATH_TO_ARCHIVE_DIR=${PATH_TO_ARCHIVE_DIR:-'/opt'}
readonly PRODUCT_VERSION=${PRODUCT_VERSION:-'5.6.0'}
readonly PATHS_TO_PRODUCTS_TO_DOWNLOAD=${PATHS_TO_PRODUCTS_TO_DOWNLOAD}
readonly COLLECTIONS_REQ=${COLLECTIONS_REQ:-'requirements.yml'}
readonly JBOSS_NETWORK_API_CREDENTIAL_FILE=${JBOSS_NETWORK_API_CREDENTIAL_FILE:-'/var/jenkins_home/jboss_network_api.yml'}

loadJBossNetworkAPISecrets() {
  if [ -e "${JBOSS_NETWORK_API_CREDENTIAL_FILE}" ]; then
    # extra spaces in front of -e is to prevent its interpretation as an arg of echo
    echo '   -e' rhn_username="$(readValueFromFile 'rhn_username' ${JBOSS_NETWORK_API_CREDENTIAL_FILE})" -e rhn_password="$(readValueFromFile 'rhn_password' ${JBOSS_NETWORK_API_CREDENTIAL_FILE}) -e omit_rhn_output=false"
  fi
}

readValueFromFile() {
  local field=${1}
  local file=${2}
  local sep=${3:-':'}

  grep -e "${field}" "${file}" | cut "-d${sep}" -f2 | sed -e 's;^ *;;'
}

set -u
cd "${WORKDIR}"

"${HARMONIA_HOME}/ansible-install-collections.sh"

if [ -z "${PATHS_TO_PRODUCTS_TO_DOWNLOAD}" ]; then
  echo "No PATHS_TO_PRODUCTS_TO_DOWNLOAD provided, aborting."
  exit 1
fi

if [ ! -e "${PATH_TO_PLAYBOOK}" ]; then
  echo "Playbook does not exists: ${PATH_TO_PLAYBOOK}."
  ls .
  exit 2
fi

if [ ! -e "${PATH_TO_INVENTORY_FILE}" ]; then
  echo '[all]' >> "${PATH_TO_INVENTORY_FILE}"
  echo 'localhost ansible_connection=local' >> "${PATH_TO_INVENTORY_FILE}"
fi

ansible-playbook --version
# shellcheck disable=SC2086
if [ -e "${COLLECTIONS_REQ}" ]; then
  ansible-galaxy collection install -r "${COLLECTIONS_REQ}"
fi
ansible-playbook ${ANSIBLE_VERBOSITY_LEVEL} -i "${PATH_TO_INVENTORY_FILE}" $(loadJBossNetworkAPISecrets) "${PLAYBOOK}"
if [ -e "${VALIDATION_PLAYBOOK}" ]; then
  ansible-playbook ${ANSIBLE_VERBOSITY_LEVEL} -i "${PATH_TO_INVENTORY_FILE}" "${VALIDATION_PLAYBOOK}"
fi
