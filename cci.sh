#!/bin/bash
if [ "${BUILD_COMMAND}" = 'build' ]; then
  zip -qr "jboss-eap-src-${GIT_COMMIT:0:7}.zip" "${EAP_SOURCES_FOLDER}"
  cd "${EAP_SOURCES_DIR}" || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"

  # shellcheck disable=SC2068
  build ${@}

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
else
  # unzip artifacts from build job
  find . -maxdepth 1 -name '*.zip' -exec unzip -q {} \;

  TEST_JBOSS_DIST=$(find . -regextype posix-extended -regex '.*jboss-eap-7\.[0-9]+')
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
  # shellcheck disable=SC2068
  testsuite ${@}
fi
