#!/bin/bash

readonly EAP_SOURCES_FOLDER=${EAP_SOURCES_FOLDER:-"eap-sources"}
readonly EAP_SOURCES_DIR=${EAP_SOURCES_DIR:-"${WORKSPACE}/${EAP_SOURCES_FOLDER}"}

if [ "${BUILD_COMMAND}" = 'build' ]; then
  build_command
else
  check_if_old_releases_exists
  testsuite_command
fi
