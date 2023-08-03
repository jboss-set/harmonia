#!/bin/bash
set -eo pipefail

readonly PLAYBOOK=${PLAYBOOK:-'playbooks/playbook.yml'}
readonly PATH_TO_PLAYBOOK=${PATH_TO_PLAYBOOK:-"${WORKDIR}/${PLAYBOOK}"}
readonly SYSTEM_REQ=${SYSTEM_REQ:-'requirements.txt'}
readonly ANSIBLE_VERBOSITY=${ANSIBLE_VERBOSITY:-''}

set -u

source "$(dirname $(realpath ${0}))/common.sh"

checkWorkdirExistsAndSetAsDefault

if [ ! -e "${PATH_TO_PLAYBOOK}" ]; then
  echo "Playbook does not exits: ${PATH_TO_PLAYBOOK}."
  ls "${WORKDIR}/playbooks"
  exit 2
fi

ansibleGalaxyCollectionInstallFromRequirementFile

ansible-playbook ${ANSIBLE_VERBOSITY} "${PLAYBOOK}"
