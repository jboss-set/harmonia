#!/bin/bash
set -eo pipefail

get_vbe_jar() {
  readonly PARENT_JOB_DIR=${PARENT_JOB_DIR:-'/parent_job'}
  echo "$(ls "${PARENT_JOB_DIR}"/target/jboss-set-version-bump-extension-*[^sc].jar)"
}

full_path="$(realpath $0)"
dir_path="$(dirname $full_path)"
source "${dir_path}/base.sh"

readonly EAP_SOURCES_DIR=${EAP_SOURCES_DIR:-"${WORKSPACE}"}

readonly MAVEN_SETTINGS_XML=${MAVEN_SETTINGS_XML-'/home/master/settings.xml'}

setup ${@}
do_run ${PARAMS}
