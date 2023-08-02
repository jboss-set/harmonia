#!/bin/bash
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
