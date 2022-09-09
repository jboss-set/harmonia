#!/bin/bash

full_path="$(realpath $0)"
dir_path="$(dirname $full_path)"
source "${dir_path}/base.sh"

get_vbe_jar() {
  echo "$(ls jboss-set-version-bump-extension-*[^sc].jar)"
}

pre_build() {
  zip -qr "jboss-eap-src-${GIT_COMMIT:0:7}.zip" "${EAP_SOURCES_FOLDER}"
  cd "${EAP_SOURCES_DIR}" || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
}

post_build() {
  if [ -n "${ZIP_WORKSPACE}" ]; then
    zip -x "${HARMONIA_FOLDER}" -x \*.zip -qr 'workspace.zip' "${WORKSPACE}"
  fi

  # shellcheck disable=SC2155
  readonly EAP_DIST_DIR=$(get_dist_folder)
  echo "Using ${EAP_DIST_DIR}"

  cd "${EAP_DIST_DIR}" || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
  zip -qr "${WORKSPACE}/jboss-eap-dist-${GIT_COMMIT:0:7}.zip" jboss-eap-*/
  cd "${LOCAL_REPO_DIR}/.." || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
  zip -qr "${WORKSPACE}/jboss-eap-maven-artifacts-${GIT_COMMIT:0:7}.zip" "maven-local-repository"

  cd "${WORKSPACE}" || exit 1
  record_build_properties
}

pre_test() {
  # unzip artifacts from build job
  find . -maxdepth 1 -name '*.zip' -exec unzip -q {} \;

  TEST_JBOSS_DIST=$(find . -regextype posix-extended -regex '.*jboss-eap-[7-8]\.[0-9]+')
  if [ -z "$TEST_JBOSS_DIST" ]; then
    echo "No EAP distribution to be tested"
    exit 2
  else
    export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Djboss.dist=${WORKSPACE}/${TEST_JBOSS_DIST}"
  fi

  # shellcheck disable=SC2154
  if [ "${ip}" == "ipv6" ];
  then
    export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dipv6"
  fi
}

# no default settings.xml on CCI
readonly EAP_SOURCES_FOLDER=${EAP_SOURCES_FOLDER:-"eap-sources"}
readonly EAP_SOURCES_DIR=${EAP_SOURCES_DIR:-"${WORKSPACE}/${EAP_SOURCES_FOLDER}"}

setup ${@}
do_run ${PARAMS}
