#!/bin/bash
set -eo pipefail

if [ ! -d "${WORKDIR}" ]; then
  echo "WORKDIR ${WORKDIR} does not exists or is not a directory."
  exit 1
fi
readonly HARMONIA_HOME=${HARMONIA_HOME:-"${WORKSPACE}/harmonia"}
readonly PLAYBOOK=${PLAYBOOK:-'playbooks/playbook.yml'}
readonly PATH_TO_PLAYBOOK=${PATH_TO_PLAYBOOK:-"${WORKDIR}/${PLAYBOOK}"}
readonly PATH_TO_INVENTORY_FILE=${PATH_TO_INVENTORY_FILE:-"${WORKDIR}/inventory"}
readonly PLAYBOOK_VARS_FILE=${PLAYBOOK_VARS_FILE:-$(mktemp)}
readonly ANSIBLE_VERBOSITY=${ANSIBLE_VERBOSITY}

set -u
cd "${WORKDIR}"

${HARMONIA_HOME}/ansible-install-collections.sh

echo "tomcat_home: '$(mktemp)'" >> "${PLAYBOOK_VARS_FILE}"

if [ ! -e "${PATH_TO_PLAYBOOK}" ]; then
  echo "Playbook does not exists: ${PATH_TO_PLAYBOOK}."
  ls .
  exit 1
fi

if [ ! -e "${PATH_TO_INVENTORY_FILE}" ]; then
  echo '[all]' >> "${PATH_TO_INVENTORY_FILE}"
  echo 'localhost ansible_connection=local' >> "${PATH_TO_INVENTORY_FILE}"
fi


#  shellcheck disable=SC2086
ansible-playbook -i "${PATH_TO_INVENTORY_FILE}" -e @${PLAYBOOK_VARS_FILE} ${ANSIBLE_VERBOSITY} "${PLAYBOOK}"
