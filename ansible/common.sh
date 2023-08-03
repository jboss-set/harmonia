#!/bin/bash

ANSIBLE_CONFIG=${ANSIBLE_CONFIG:-'/var/jenkins_home/ansible.cfg'}

configureAnsible() {
  local path_to_ansible_cfg=${1}
  local workdir=${2}

  echo -n "Copying ansible.cfg from ${path_to_ansible_cfg} to ${workdir}..."
  if [ -e "${path_to_ansible_cfg}" ]; then
    cp "${path_to_ansible_cfg}" "${workdir}"
    echo Done
  else
    echo " No such file, skip."
  fi
}

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
