#!/bin/bash
set -eo pipefail

copyCollectionFrom() {
  local path_to_collection=${1}
  local workdir=${WORKDIR:-"${2}"}

  if [ -d "${path_to_collection}" ]; then
    echo -n "Fetching last build from ${path_to_collection}..."
    cp -r "${path_to_collection}"/* "${workdir}"
    cp "${path_to_collection}/.ansible-lint" "${workdir}"
    cp "${path_to_collection}/.yamllint" "${workdir}"
    echo 'Done.'
  else
    echo "Invalid path to collection (does not exists or not a directory): ${path_to_collection}."
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
  echo "The LAST_SUCCESSFULL_BUILD_ID provied: ${LAST_SUCCESS_FULL_BUILD_ID}"
  if [ -z "${PARENT_JOB_HOME}" ] ; then
     echo "PARENT_JOB_HOME not provided and required for this kind of build, aborting..."
     exit 3
  fi
  copyCollectionFrom "${PARENT_JOB_HOME}/builds/${LAST_SUCCESS_FULL_BUILD_ID}/archive/workdir/downstream"/*
else
  echo "TODO: a git checkout from gitlab"
  exit 4
fi

"${HARMONIA_HOME}/molecule.sh"
