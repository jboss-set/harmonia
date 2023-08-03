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
