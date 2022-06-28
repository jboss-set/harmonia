#!/bin/bash
set -euo pipefail

if [ ! -d "${WORKDIR}" ]; then
  echo "WORKDIR ${WORKDIR} does not exists or is not a directory."
  exit 1
fi

cd "${WORKDIR}"
set +u
./ansible-install-collections.sh

set +u
./molecule.sh
