#!/bin/bash
set -eo pipefail

if [ ! -d "${WORKDIR}" ]; then
  echo "WORKDIR ${WORKDIR} does not exists or is not a directory."
  exit 1
fi

readonly PLAYBOOK=${PLAYBOOK:-'playbooks/playbook.yml'}
readonly PATH_TO_PLAYBOOK=${PATH_TO_PLAYBOOK:-"${WORKDIR}/${PLAYBOOK}"}
readonly SYSTEM_REQ=${SYSTEM_REQ:-'requirements.txt'}
readonly COLLECTIONS_REQ=${COLLECTIONS_REQ:-'requirements.yml'}
readonly ANSIBLE_VERBOSITY=${ANSIBLE_VERBOSITY:-''}

set -u
cd "${WORKDIR}"

if [ ! -e "${PATH_TO_PLAYBOOK}" ]; then
  echo "Playbook does not exits: ${PATH_TO_PLAYBOOK}."
  ls "${WORKDIR}/playbooks"
  exit 2
fi

if [ -e "${COLLECTIONS_REQ}" ]; then
  ansible-galaxy collection install -r "${COLLECTIONS_REQ}"
fi

ansible-playbook ${ANSIBLE_VERBOSITY} "${PLAYBOOK}"
