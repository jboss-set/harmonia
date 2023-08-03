#!/bin/bash
set -eo pipefail

source "$(dirname $(realpath ${0}))/common.sh"

checkWorkdirExistsAndSetAsDefault

ansible-galaxy collection build .
ansible-galaxy collection install *.tar.gz

if [ "${PLAYBOOK}" == 'playbooks/janus.yml' ]; then
  ansible-playbook middleware_automation.janus.janus
else
  ansible-playbook middleware_automation.janus.${PROJECT_NAME}
fi
