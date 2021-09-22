#!/bin/bash
set -eo pipefail
if [ "${BUILD_COMMAND}" = 'build' ]; then
  # shellcheck disable=SC2068
  build ${@}
else
  # shellcheck disable=SC2068
  testsuite ${@}
fi
