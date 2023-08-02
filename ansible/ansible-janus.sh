#!/bin/bash
set -eo pipefail


if [ ! -d "${WORKDIR}" ]; then
  echo "WORKDIR ${WORKDIR} does not exists or is not a directory."
  exit 1
fi

cd "${WORKDIR}"

ansible-galaxy collection build .
ansible-galaxy collection install *.tar.gz

if [ "${PLAYBOOK}" == 'playbooks/janus.yml' ]; then
  ansible-playbook middleware_automation.janus.janus
else
  ansible-playbook middleware_automation.janus.${PROJECT_NAME}
fi
