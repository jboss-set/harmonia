#!/bin/bash
set -euo pipefail


readonly HARMONIA_HOME=${HARMONIA_HOME:-'harmonia'}

if [ ! -d "${WORKDIR}" ]; then
  echo "WORKDIR ${WORKDIR} does not exists or is not a directory."
  exit 1
fi

cd "${WORKDIR}"
set +u
${HARMONIA_HOME}/ansible-install-collections.sh
${HARMONIA_HOME}/molecule.sh
