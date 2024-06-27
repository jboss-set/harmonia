#!/bin/bash
set -eo pipefail

readonly PATH_TO_MOLECULE_REQUIREMENTS_FILE=${PATH_TO_MOLECULE_REQUIREMENTS_FILE:-'molecule/requirements.yml'}
readonly PATH_TO_REQUIREMENTS_TEMPLATE=${PATH_TO_REQUIREMENTS_TEMPLATE:-'molecule/.ci_requirements.yml.j2'}
readonly JBOSS_NETWORK_API_CREDENTIAL_FILE=${JBOSS_NETWORK_API_CREDENTIAL_FILE:-'/var/jenkins_home/jboss_network_api.yml'}

dir_path=$(dirname $(realpath "${0}"))
source "${dir_path}/../common.sh"
source "${dir_path}/common.sh"

checkWorkspaceIsDefinedAndExists
checkWorkdirExistsAndSetAsDefault

if [ -n "${LAST_SUCCESS_FULL_BUILD_ID}" ]; then
  echo "The LAST_SUCCESSFULL_BUILD_ID provided: ${LAST_SUCCESS_FULL_BUILD_ID}"
  if [ -z "${PARENT_JOB_HOME}" ] ; then
     echo "PARENT_JOB_HOME not provided and required for this kind of build, aborting..."
     exit 3
  fi
  readonly PATH_TO_COLLECTION="${PARENT_JOB_HOME}/builds/${LAST_SUCCESS_FULL_BUILD_ID}/archive/workdir/downstream/${PROJECT_UPSTREAM_NAME}/"
  if [[ "${JOB_NAME}" =~ .*"-dot".* ]]; then
    echo "${JOB_NAME} will use the latest available collection to run the tests."
    # shellcheck disable=SC2155
    readonly PATH_TO_COLLECTION_ARCHIVE=$(ls -1 "${PATH_TO_COLLECTION}/${DOWNSTREAM_NS}-${PROJECT_UPSTREAM_NAME}"*.tar.gz)
    echo "Collection archive used: ${PATH_TO_COLLECTION_ARCHIVE}."
    generateRequirementsFromCItemplateIfProvided "${PATH_TO_COLLECTION_ARCHIVE}" \
                                                 "${WORKDIR}/${PATH_TO_MOLECULE_REQUIREMENTS_FILE}" \
                                                 "${WORKDIR}/${PATH_TO_REQUIREMENTS_TEMPLATE}"
  else
    echo "${JOB_NAME} will copy over the collection ${PATH_TO_COLLECTION} and run its molecule tests."
    copyCollectionFrom "${PATH_TO_COLLECTION}"
  fi
else
  echo "Can't run job without a LAST_SUCCESS_FULL_BUILD_ID defined."
  exit 4
fi

# shellcheck disable=SC2155
readonly EXTRA_ARGS="${EXTRA_ARGS} $(loadJBossNetworkAPISecrets)"
export EXTRA_ARGS
"${HARMONIA_HOME}/ansible/molecule/molecule.sh"
