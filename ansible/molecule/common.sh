#!/bin/bash
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
    rm -rf "${workdir:?}"/*
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
