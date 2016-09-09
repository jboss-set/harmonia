#!/bin/bash

readonly RUN_AS=${RUN_AS:-'jboss'}
readonly SCRIPT_TO_RUN=${1}

if [ ! -e "${SCRIPT_TO_RUN}" ]; then
  echo "No such script: ${SCRIPT_TO_RUN}"
  exit 1
fi

su "${RUN_AS}" -c "${SCRIPT_TO_RUN}"
