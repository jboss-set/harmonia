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
set -u
cd "${WORKDIR}"

downloadProducts() {
  local paths=${1}

  IFS=',' read -ra PATHS_TO_ARCHIVE <<< "${paths}"
  for path_to_archive in "${PATHS_TO_ARCHIVE[@]}"
  do
    "${HARMONIA_HOME}/ansible-fetch-mw-product.sh" "${path_to_archive}" "${path_to_archive##*/}"
  done
}

"${HARMONIA_HOME}/ansible-install-collections.sh"

if [ -z "${PATHS_TO_PRODUCTS_TO_DOWNLOAD}" ]; then
  echo "No PATHS_TO_PRODUCTS_TO_DOWNLOAD provided, aborting."
  exit 1
fi

downloadProducts "${PATHS_TO_PRODUCTS_TO_DOWNLOAD}"

if [ ! -e "${PATH_TO_PLAYBOOK}" ]; then
  echo "Playbook does not exists: ${PATH_TO_PLAYBOOK}."
  ls .
  exit 2
fi

if [ ! -e "${PATH_TO_INVENTORY_FILE}" ]; then
  echo '[all]' >> "${PATH_TO_INVENTORY_FILE}"
  echo 'localhost ansible_connection=local' >> "${PATH_TO_INVENTORY_FILE}"
fi

# shellcheck disable=SC2086
ansible-playbook ${ANSIBLE_VERBOSITY_LEVEL} -i "${PATH_TO_INVENTORY_FILE}" "${PLAYBOOK}"
if [ -e "${VALIDATION_PLAYBOOK}" ]; then
  echo "Validation requires changes upstream. Disabled."
  #ansible-playbook ${ANSIBLE_VERBOSITY_LEVEL} -i "${PATH_TO_INVENTORY_FILE}" "${VALIDATION_PLAYBOOK}"
fi
