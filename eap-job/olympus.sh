#!/bin/bash
set -eo pipefail

full_path="$(realpath $0)"
dir_path="$(dirname $full_path)"
source "${dir_path}/base.sh"

readonly EAP_SOURCES_DIR=${EAP_SOURCES_DIR:-"${WORKSPACE}"}

readonly MAVEN_SETTINGS_XML=${MAVEN_SETTINGS_XML-'/home/master/settings.xml'}

setup ${@}
do_run ${PARAMS}
