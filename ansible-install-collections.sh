#!/bin/bash
set -eo pipefail

if [ ! -d "${WORKDIR}" ]; then
  echo "WORKDIR ${WORKDIR} does not exists or is not a directory."
  exit 1
fi

readonly COLLECTIONS_TO_INSTALL=${COLLECTIONS_TO_INSTALL}
readonly PROJECT_NAME=${PROJECT_NAME}
readonly SYSTEM_REQ=${SYSTEM_REQ:-'requirements.txt'}
readonly COLLECTIONS_REQ=${COLLECTIONS_REQ:-'requirements.yml'}
readonly ANSIBLE_VERBOSITY=${ANSIBLE_VERBOSITY:-''}
readonly JENKINS_JOBS_DIR=${JENKINS_JOB_DIR:-'/jenkins_jobs'}

set -u
cd "${WORKDIR}"

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
      path_to_collection_archive=$(get_path_to_collection_tarball "${path_to_builds}/${last_build_id}/archive/workdir/downstream/" "${collection_to_install}")
      ansible-galaxy collection install "${path_to_collection_archive}"
    done
  fi
}

install_collections

readonly PATH_TO_BUILDS_PROJECT_NAME="${JENKINS_JOBS_DIR}/ansible-janus-${PROJECT_NAME}/builds/"
if [ ! -d "${PATH_TO_BUILDS_PROJECT_NAME}" ]; then
  echo "No such build folder: ${PATH_TO_BUILDS_PROJECT_NAME}"
  ls -1d "${JENKINS_JOBS_DIR}"
  exit 5
fi
# shellcheck disable=SC2155
readonly LAST_SUCCESSFUL_BUILD_ID_PROJECT_NAME=$(get_last_build_id "${PATH_TO_BUILDS_PROJECT_NAME}")
readonly PROJECT_NAME_HOME="${PATH_TO_BUILDS_PROJECT_NAME}/${LAST_SUCCESSFUL_BUILD_ID_PROJECT_NAME}/archive/workdir/downstream/"

# shellcheck disable=SC2155
readonly PATH_TO_COLLECTION_ARCHIVE=$(get_path_to_collection_tarball "${PROJECT_NAME_HOME}" "${PROJECT_NAME}")
tar -xf "${PATH_TO_COLLECTION_ARCHIVE}" -C "${WORKDIR}"

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
