#!/bin/bash

readonly EAP_SOURCES_DIR=${EAP_SOURCES_DIR:-"${WORKSPACE}"}
readonly MAVEN_SETTINGS_XML=${MAVEN_SETTINGS_XML-'/home/master/settings.xml'}

if [ "${BUILD_COMMAND}" = 'build' ]; then

  zip -qr "jboss-eap-src-${GIT_COMMIT:0:7}.zip" "${EAP_SOURCES_FOLDER}"
  cd "${EAP_SOURCES_DIR}" || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
  build_command

  # on a 7.4 build, EAP_DIST_DIR would be defined in the vars/7.4.sh file, thus overriding the default
  readonly EAP_DIST_DIR=${EAP_DIST_DIR:-"${EAP_SOURCES_DIR}//dist/target"}
  # when we drop jobs <= 7.3, we can invert this logic, default becomes /ee-dist/target

  cd "${EAP_DIST_DIR}" || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
  zip -qr "${WORKSPACE}/jboss-eap-dist-${GIT_COMMIT:0:7}.zip" jboss-eap-*/
  cd "${LOCAL_REPO_DIR}/.." || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
  zip -qr "${WORKSPACE}/jboss-eap-maven-artifacts-${GIT_COMMIT:0:7}.zip" "maven-local-repository"

  cd "${WORKSPACE}"

  record_build_properties
else
  check_if_old_releases_exists

  # unzip artifacts from build job
  find . -maxdepth 1 -name '*.zip' -exec unzip -q {} \;

  TEST_JBOSS_DIST=$(find . -regextype posix-extended -regex '.*jboss-eap-7\.[0-9]+')
  if [ -z "$TEST_JBOSS_DIST" ]; then
    echo "No EAP distribution to be tested"
    exit 2
  else
    export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Djboss.dist=${WORKSPACE}/${TEST_JBOSS_DIST}"
  fi

  if [ "${ip}" == "ipv6" ];
  then
    export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dipv6"
  fi
  testsuite_command
fi
