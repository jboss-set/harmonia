#!/bin/bash
set -eo pipefail

usage() {
  echo "$(basename "${0}")"
}

log() {
  local mssg="${@}"
  local perun_log_prefix=${PERUN_LOG_PREFIX:-''}

  echo "${perun_log_prefix} ${mssg}"
}

readonly PERUN_LOG_PREFIX=${PERUN_LOG_PREFIX:-'[PERUN]'}
export PERUN_LOG_PREFIX

readonly EAP_GITHUB_REPO="${EAP_GITHUB_REPO:-'git@github.com:jbossas/jboss-eap7.git'}"
readonly EAP_GITHUB_BRANCH="${EAP_GITHUB_BRANCH:-'7.2.x-proposed'}"
readonly BISECT_WORKSPACE="${BISECT_WORKSPACE:-$(mktemp -d)}"
# export to reuse
export BISECT_WORKSPACE
export HARMONIA_FOLDER="${WORKSPACE}/harmonia"
#for EAT and harmonia build script
readonly LOCAL_REPO_DIR=${LOCAL_REPO_DIR:-${WORKSPACE}/maven-local-repository}
export LOCAL_REPO_DIR

deleteBisectWorkspace() {
  if [[ ! -z "${BISECT_WORKSPACE}" ]]; then
    rm -rf "${BISECT_WORKSPACE}"
  fi
  if [[ ! -z "${REPRODUCER_PATCH}" ]]; then
    rm -rf "${REPRODUCER_PATCH}"
  fi
  if [[ ! -z "${INTEGRATION_SH_PATCH}" ]]; then
    rm -rf "${INTEGRATION_SH_PATCH}"
  fi
}
trap deleteBisectWorkspace EXIT


#good revision, we consider current one as bad?
readonly GOOD_REVISION="${GOOD_REVISION}"
if [ -z "${GOOD_REVISION}" ]; then
  log "No good revision provided, aborting."
  exit 1
fi
readonly BAD_REVISION="${BAD_REVISION}"
if [ -z "${BAD_REVISION}" ]; then
  log "No bad revision provided, aborting."
  exit 2
fi

git clone "${EAP_GITHUB_REPO}"  --branch "${EAP_GITHUB_BRANCH}" "${BISECT_WORKSPACE}"
cd "${BISECT_WORKSPACE}"

#revisions that are known to not compile due to split of changes, separated by ','
readonly CORRUPT_REVISIONS="${CORRUPT_REVISIONS}"
#url of a patch file (a diff) containing the changes required to insert
# the reproducer into EAP existing testsuite.
readonly REPRODUCER_PATCH_URL="${REPRODUCER_PATCH_URL}"
readonly GIT_TOKEN="${GIT_TOKEN}"
readonly GIT_UID="${GIT_UID}"
#if [ -z "${REPRODUCER_PATCH_URL}" ]; then
#  log "No URL for the reproducer patch provided, aborting."
#  exit 3
#fi
#test to run from suite, either existing one or one that comes from $TEST_DIFF
readonly TEST_NAME="${TEST_NAME}"
if [ -z "${TEST_NAME}" ]; then
  log "No test name provided, aborting."
  exit 4
fi

set -u

readonly REPRODUCER_PATCH=${PATCH_HOME:-$(mktemp)}
if [[ -n "${GIT_TOKEN}" && -n "${GIT_UID}" && "${REPRODUCER_PATCH_URL}" == *"api.github.com/repos"* ]]; then
  log "Fetching PR as unified diff from '${REPRODUCER_PATCH_URL}'"
  #check if we can access
  GIT_ACCESS_RETURN_CODE=$(curl -u "${GIT_UID}:${GIT_TOKEN}" -H "Accept: application/vnd.github.v3.diff" -o /dev/null -w '%{http_code}\n' -s -LI "${REPRODUCER_PATCH_URL}")

  if [ "${GIT_ACCESS_RETURN_CODE}" == "200" ]; then
    curl -u "${GIT_UID}:${GIT_TOKEN}" -H "Accept: application/vnd.github.v3.diff" -o "${REPRODUCER_PATCH}" "${REPRODUCER_PATCH_URL}"
  else
    log "Could not access reproducer patch, return code '${GIT_ACCESS_RETURN_CODE}'"
    exit 5
  fi

elif [ -n "${REPRODUCER_PATCH_URL}" ]; then
  curl "${REPRODUCER_PATCH_URL}" -o "${REPRODUCER_PATCH}"
else
    log "No reproducer patch URL provided"
fi

if [ -e "${REPRODUCER_PATCH}" ]; then
  export REPRODUCER_PATCH
else
  log 'No reproducer patch'
fi

set +u
readonly INTEGRATION_SH_PATCH=${INTEGRATION_SH_HOME:-$(mktemp)}
if [ -n "${INTEGRATION_SH_PATCH_URL}" ]; then
   curl "${INTEGRATION_SH_PATCH_URL}" -o "${INTEGRATION_SH_PATCH}"
   if [ -e "${INTEGRATION_SH_PATCH}" ]; then
     export INTEGRATION_SH_PATCH
   else
     log "No integration sh patch"
   fi
fi
set -u
git bisect 'start'
git bisect 'bad' "${BAD_REVISION}"
git bisect 'good' "${GOOD_REVISION}"

git bisect run "${WORKSPACE}/run-test.sh"
