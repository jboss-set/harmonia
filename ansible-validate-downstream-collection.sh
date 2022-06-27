#!/bin/bash
set -eo pipefail

if [ ! -d "${WORKDIR}" ]; then
  echo "WORKDIR ${WORKDIR} does not exists or is not a directory."
  exit 1
fi

readonly COLLECTIONS_TO_INSTALL=${COLLECTIONS_TO_INSTALL}
readonly COLLECTION_TO_VALIDATE=${COLLECTION_TO_VALIDATE}
readonly PLAYBOOK=${PLAYBOOK:-'playbooks/playbook.yml'}
readonly PATH_TO_PLAYBOOK=${PATH_TO_PLAYBOOK:-"${WORKDIR}/${PLAYBOOK}"}
readonly SYSTEM_REQ=${SYSTEM_REQ:-'requirements.txt'}
readonly COLLECTIONS_REQ=${COLLECTIONS_REQ:-'requirements.yml'}
readonly ANSIBLE_VERBOSITY=${ANSIBLE_VERBOSITY:-''}
readonly JENKINS_JOBS_DIR=${JENKINS_JOB_DIR:-'/var/jenkins_home/jobs/'}

set -u
cd "${WORKDIR}"

get_last_build_id() {
  local path_to_permalinks="${1}/permalinks"

  if [ -z "${path_to_permalinks}" ]; then
    echo "No permalinks file: ${path_to_permalinks}." 1>&2
    exit 1
  fi

  last_build_id=$(grep "${path_to_builds}/lastSuccessfulBuild" -e 'permalinks' | cut -f2 -d\ )
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

  path_to_tarball="${collection_home}/${collection_name}/${collection_namespace}-${collection_name}*.tgz"
  if [ ! -e "${path_to_tarball}" ]; then
    echo "Pass to archive does not exits: ${path_to_tarball}." 1>&2
    exit 1
  fi
}

install_collections() {

  if [ -n "${COLLECTIONS_TO_INSTALL}" ]; then
    IFS=','
    read -r -a collections_to_install_array <<< "${COLLECTIONS_TO_INSTALL}"
    for collection_to_install in "${collections_to_install_array[@]}"
    do
      path_to_builds=${JENKINS_JOBS_DIR}/ansible-janus-${collection_to_install}/builds
      if [ ! -d "${path_to_builds}" ]; then
        echo "Invalid path to collection job: ${path_to_builds}."
        exit 2
      fi
      last_build_id=$(get_last_build_id "${path_to_builds}")
      path_to_collection_archive=$(get_path_to_collection_tarball "${path_to_builds}/archive/workdir/downstream/" "${collection_to_install}")
      ansible-galaxy collection install "${path_to_collection_archive}"
    done
  fi
}

install_collections

readonly PATH_TO_BUILDS_COLLECTION_TO_VALIDATE="${JENKINS_JOBS_DIR}/ansible-janus-${COLLECTION_TO_VALIDATE}/builds/"
if [ ! -d "${PATH_TO_BUILDS_COLLECTION_TO_VALIDATE}" ]; then
  echo "No such build folder: ${PATH_TO_BUILDS_COLLECTION_TO_VALIDATE}"
  exit 5
fi
# shellcheck disable=SC2155
readonly LAST_SUCCESSFUL_BUILD_ID_COLLECTION_TO_VALIDATE=$(get_last_build_id "${PATH_TO_BUILDS_COLLECTION_TO_VALIDATE}")
readonly COLLECTION_TO_VALIDATE_HOME="${PATH_TO_BUILDS_COLLECTION_TO_VALIDATE}/${LAST_SUCCESSFUL_BUILD_ID_COLLECTION_TO_VALIDATE}/archive/workdir/downstream/"

# shellcheck disable=SC2155
readonly PATH_TO_COLLECTION_ARCHIVE=$(get_path_to_collection_tarball "${COLLECTION_TO_VALIDATE_HOME}" "${COLLECTION_TO_VALIDATE}")
tar -xf "${PATH_TO_COLLECTION_ARCHIVE}" -C "${WORKDIR}"

if [ ! -e "${PATH_TO_PLAYBOOK}" ]; then
  echo "Playbook does not exists: ${PATH_TO_PLAYBOOK}."
  ls .
  exit 2
fi

#if [ -e "${SYSTEM_REQ}" ]; then
#  cat "${SYSTEM_REQ}" | \
#  while
#    read package
#  do
#    command "${package}" 2> /dev/null
#  done
#fi

if [ -e "${COLLECTIONS_REQ}" ]; then
  ansible-galaxy collection install -r "${COLLECTIONS_REQ}"
fi

#  shellcheck disable=SC2086
ansible-playbook ${ANSIBLE_VERBOSITY} "${PLAYBOOK}"
