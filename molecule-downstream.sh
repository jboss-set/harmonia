#!/bin/bash
set -eo pipefail


readonly PATH_TO_MOLECULE_REQUIREMENTS_FILE=${PATH_TO_MOLECULE_REQUIREMENTS_FILE:-'molecule/requirements.yml'}
readonly PATH_TO_REQUIREMENTS_TEMPLATE=${PATH_TO_REQUIREMENTS_TEMPLATE:-'molecule/.ci_requirements.yml.j2'}

readonly DOWNSTREAM_NS='redhat'

generateRequirementsFromCItemplateIfProvided() {
  local path_to_collection_archive=${1}
  local path_to_requirements_file=${2}
  local path_to_template=${3}

  if [ ! -e "${path_to_template}" ]; then
    echo "Path to template to generate requirements.yml is invalid: ${path_to_template}, aborting."
    exit 4
  fi

  if [ -e "${path_to_collection_archive}" ]; then
    ansible -m template \
            -a "src=${path_to_template} dest=${path_to_requirements_file}" \
            -e path_to_collection="${path_to_collection_archive}" \
            localhost
  else
    echo "Invalid path to collection (does not exists or not a directory): ${path_to_collection_archive}."
    exit 5
  fi
}

copyCollectionFrom() {
  local path_to_collection=${1}
  local workdir=${WORKDIR:-"${2}"}

  if [ -d "${path_to_collection}" ]; then
    rm -rf "${workdir}"/*
    echo -n "Fetching last build from ${path_to_collection}..."
    cp -r "${path_to_collection}"/* "${workdir}"
    cp "${path_to_collection}/.ansible-lint" "${workdir}"
    cp "${path_to_collection}/.yamllint" "${workdir}"
    echo 'Done.'
  else
    echo "Invalid path to collection (does not exists or not a directory): ${path_to_collection}."
    exit 5
  fi
}

if [ -z "${WORKSPACE}" ]; then
  echo "No WORKSPACE env var defined, aborting..."
  exit 1
fi

readonly HARMONIA_HOME=${HARMONIA_HOME:-"${WORKSPACE}/harmonia"}

if [ -z "${WORKDIR}" ]; then
  echo "WORKDIR is not defined, aborting..."
  exit 2
fi

mkdir -p "${WORKDIR}"
cd "${WORKDIR}"
if [ -n "${LAST_SUCCESS_FULL_BUILD_ID}" ]; then
  echo "The LAST_SUCCESSFULL_BUILD_ID provided: ${LAST_SUCCESS_FULL_BUILD_ID}"
  if [ -z "${PARENT_JOB_HOME}" ] ; then
     echo "PARENT_JOB_HOME not provided and required for this kind of build, aborting..."
     exit 3
  fi
  readonly PATH_TO_COLLECTION="${PARENT_JOB_HOME}/builds/${LAST_SUCCESS_FULL_BUILD_ID}/archive/workdir/downstream/${PROJECT_NAME}/"
  if [[ "${JOB_NAME}" =~ .*"-dot".* ]]; then
    echo "${JOB_NAME} will use the latest available collection to run the tests."
    readonly PATH_TO_COLLECTION_ARCHIVE=$(ls -1 "${PATH_TO_COLLECTION}/${DOWNSTREAM_NS}-${PROJECT_NAME}"*.tar.gz)
    echo "Collection archive used: ${PATH_TO_COLLECTION_ARCHIVE}."
    generateRequirementsFromCItemplateIfProvided "${PATH_TO_COLLECTION_ARCHIVE}" \
                                                 "${PATH_TO_MOLECULE_REQUIREMENTS_FILE}" \
                                                 "${PATH_TO_REQUIREMENTS_TEMPLATE}"
  else
    echo "${JOB_NAME} will copy over the collection ${PATH_TO_COLLECTION} and run its molecule tests."
    copyCollectionFrom "${PATH_TO_COLLECTION}"/*
  fi
else
  echo "TODO: a git checkout from gitlab"
  exit 4
fi

"${HARMONIA_HOME}/molecule.sh"
