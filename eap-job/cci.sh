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

  if [ "$EAP_DIST_DIR" == "ee-dist/target" ]; then
    # hack to make the tests pass in internal-only IPv6 env - see SET-505
    # pre-run the ClientCompatibilityUnitTestCase to download the depedencies using IPv4.
    # the test is then run again using IPv6 without the need to reach outside the IPv6 network
    echo "Pre build of tests"
    cd "${EAP_SOURCES_DIR}/testsuite/integration/basic"
    mvn clean install "-Dtest=ClientCompatibilityUnitTestCase" ${TESTSUITE_OPTS}
    cd "${WORKDIR}"
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
