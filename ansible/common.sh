#!/bin/bash

WORKDIR=${WORKDIR:-"$(pwd)/workdir"}
WORKSPACE=${WORKSPACE}
ANSIBLE_CONFIG=${ANSIBLE_CONFIG:-'/var/jenkins_home/ansible.cfg'}
COLLECTIONS_REQ=${COLLECTIONS_REQ:-'requirements.yml'}
PYTHON_REQUIREMENTS_FILE=${PYTHON_REQUIREMENTS_FILE:-'requirements.txt'}
PIP_COMMAND=${PIP_COMMAND:-'pip-3.8'}
DOWNSTREAM_NS=${DOWNSTREAM_NS:-'redhat'}
JENKINS_JOBS_DIR=${JENKINS_JOB_DIR:-'/jenkins_jobs'}
HARMONIA_HOME=${HARMONIA_HOME:-"${WORKSPACE}/harmonia"}

configureAnsible() {
  local path_to_ansible_cfg=${1:-"${ANSIBLE_CONFIG}"}
  local workdir=${2:-"${WORKDIR}"}

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

ansibleGalaxyCollectionInstall() {
    local args=${@}

    ansible-galaxy collection install --force ${args}
}


ansibleGalaxyCollectionInstallFromRequirementFile() {
  local path_to_req=${1:-"${COLLECTIONS_REQ}"}

  # shellcheck disable=SC2086
  if [ -e "${path_to_req}" ]; then
    ansibleGalaxyCollectionInstall -r "${path_to_req}"
  fi
}

ansibleGalaxyCollectionInstallByName() {
  local collectionName=${1}
  local exitStatus=${2:-'1'}

  if [ -z "${collectionName}" ]; then
    echo "Collection name can't be empty."
    exit ${exitStatus}
  fi
  ansibleGalaxyCollectionInstall ${1}
}

installPythonRequirementsIfAny() {
  local requirementsFile=${1:-"${WORKDIR}/${PYTHON_REQUIREMENTS_FILE}"}

  if [ -n "${requirementsFile}" ]; then
    echo "Checks if ${requirementsFile} exists..."
    if [ -e "${requirementsFile}" ]; then
      echo 'It does, performing required installations.'
      echo "Install Python dependencies provided in ${requirementsFile}:"
      "${PIP_COMMAND}" install --user -r "${requirementsFile}"
      echo 'Done.'
    else
      echo 'File does not exists. Skipping.'
    fi
  fi
}

printEnv() {
  set +u
  if [ -n "${HERA_DEBUG}" ]; then
    echo ==========
    env
    echo ==========
  fi
  set -u
}

setRequiredEnvVars() {
  export ANSIBLE_HOST_KEY_CHECKING='False'
}

checkWorkdirExistsAndSetAsDefault() {
  local exitStatus=${1:-'1'}
  if [ ! -d "${WORKDIR}" ]; then
    echo "WORKDIR ${WORKDIR} does not exists or is not a directory."
    exit "${exitStatus}"
  fi
  cd "${WORKDIR}"
}

checkWorkspaceIsDefinedAndExists() {
    local workspace=${1:-"${WORKSPACE}"}
    local exitUndefined=${2:-'1'}
    local exitNotDir=${3:-'2'}

    if [ -z "${workspace}" ]; then
      echo "workspace is undefined, aborting."
      exit "${exitUndefined}"
    fi

    if [ ! -d "${workspace}" ]; then
      echo "workspace is not a directory, aborting."
      exit "${exitNotDir}"
    fi
}

get_last_build_id() {
  local path_to_permalinks="${1}/permalinks"

  if [ -z "${path_to_permalinks}" ]; then
    echo "No permalinks file: ${path_to_permalinks}." 1>&2
    exit 1
  fi

  # shellcheck disable=SC2155
  local last_build_id=$(grep -e 'lastSuccessfulBuild' "${path_to_permalinks}" | cut -f2 -d\ )
  if [ -z "${last_build_id}" ]; then
    echo "Could not retrieved the id of the last successful build for ${last_build_id}." 1>&2
    exit 3
  fi
  echo "${last_build_id}"
}

get_path_to_collection_tarball() {
  local collection_home=${1}
  local collection_name=${2}
  local collection_namespace=${3:-'redhat'}
  local tarball_extension=${4:-'tar.gz'}

  path_to_tarball=$(ls "${collection_home}/${collection_name}/${collection_namespace}-${collection_name}"*."${tarball_extension}")
  if [ ! -e "${path_to_tarball}" ]; then
    ls -1 "${collection_home}/${collection_name}/" 1>&2
    echo "Path to archive does not exits: ${path_to_tarball}." 1>&2
    exit 1
  fi
  echo "${path_to_tarball}"
}
