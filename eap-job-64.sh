#!/bin/bash
#
#
# Build Wildlfy/EAP
#
set -eo pipefail

usage() {
  local -r script_name=$(basename "${0}")
  echo "${script_name} <build|testsuite> [extra-args]"
  echo
  echo "ex: ${script_name} 'testsuite' -Dcustom.args"
  echo
  echo Note that if no arguments is provided, it default to 'build'. To run the testsuite, you need to provide 'testsuite' as a first argument. All arguments beyond this first will be appended to the mvn command line.
  echo
  echo 'Warning: This script also set several mvn args. Please refer to its content before adding some extra maven arguments.'
}

is_dirpath_defined_and_exists() {
  local dir_path=${1}
  local var_name=${2}

  if [ "${dir_path}" = '' ]; then
    echo "Directory path provided by ${var_name} is not set."
    return 1
  fi

  if [ ! -d "${dir_path}" ]; then
    echo "Following dir_path does not exists: ${dir_path}."
    return 2
  fi
}

record_build_properties() {
  readonly PROPERTIES_FILE='umb-build.properties'
  readonly EAP_VERSION=$(grep -r '<full.dist.product.release.version>' "$EAP_SOURCES_DIR/pom.xml" | sed 's/.*>\(.*\)<.*/\1/')

  echo "BUILD_URL=${BUILD_URL}" >> ${PROPERTIES_FILE}
  echo "SERVER_URL=${BUILD_URL}/artifact/jboss-eap-dist-${GIT_COMMIT:0:7}.zip" >> ${PROPERTIES_FILE}
  echo "SOURCE_URL=${BUILD_URL}/artifact/jboss-eap-src-${GIT_COMMIT:0:7}.zip" >> ${PROPERTIES_FILE}
  echo "VERSION=${EAP_VERSION}-${GIT_COMMIT:0:7}" >> ${PROPERTIES_FILE}
  echo "BASE_VERSION=${EAP_VERSION}" >> ${PROPERTIES_FILE}
  echo "BUILD_ID=${BUILD_ID}" >> ${PROPERTIES_FILE}
  echo "SCM_URL=${GIT_URL}" >> ${PROPERTIES_FILE}
  echo "SCM_REVISION=${GIT_COMMIT}" >> ${PROPERTIES_FILE}

  cat ${PROPERTIES_FILE}
}

function get_eap_version() {
    eap_version=$(xmllint pom.xml --xpath "//*[local-name()='project']/*[local-name()='properties']/*[local-name()='jboss.eap.release.version']/text()")
    if [ -z "${eap_version}" ] && [ -f build/src/main/resources/version.txt ]; then
        eap_version=$(cat build/src/main/resources/version.txt | egrep -o '([[:digit:]])\.[[:digit:]]')
    fi
    echo $eap_version;
}

function get_dist_folder() {
    dist_folder="build/target"
    echo "${dist_folder}"
}

BUILD_COMMAND=${1}

if [ "${BUILD_COMMAND}" = '--help' ] || [ "${BUILD_COMMAND}" = '-h' ]; then
  usage
  exit 0
fi

if [ "${BUILD_COMMAND}" != 'build' ] && [ "${BUILD_COMMAND}" != 'testsuite' ]; then
  readonly BUILD_COMMAND='build'
else
  readonly BUILD_COMMAND="${BUILD_COMMAND}"
  shift
fi

readonly MAVEN_VERBOSE=${MAVEN_VERBOSE}

# ensure provided JAVA_HOME, if any, is first in PATH
if [ -n "${JAVA_HOME}" ]; then
  export PATH=${JAVA_HOME}/bin:${PATH}
fi

readonly GIT_SKIP_BISECT_ERROR_CODE=${GIT_SKIP_BISECT_ERROR_CODE:-'125'}
readonly EAP_SOURCES_DIR=${EAP_SOURCES_DIR:-"${WORKSPACE}"}
readonly MAVEN_SETTINGS_XML=${MAVEN_SETTINGS_XML-'/home/master/settings.xml'}
readonly MEMORY_SETTINGS=${MEMORY_SETTINGS:-''}
readonly LOCAL_REPO_DIR=${LOCAL_REPO_DIR:-${WORKSPACE}/maven-local-repository}
export BUILD_OPTS=${BUILD_OPTS:-'-Drelease'}
readonly MAVEN_WAGON_HTTP_POOL=${WAGON_HTTP_POOL:-'false'}
readonly MAVEN_WAGON_HTTP_MAX_PER_ROUTE=${MAVEN_WAGON_HTTP_MAX_PER_ROUTE:-'3'}
readonly SUREFIRE_FORKED_PROCESS_TIMEOUT=${SUREFIRE_FORKED_PROCESS_TIMEOUT:-'90000'}
readonly FAIL_AT_THE_END=${FAIL_AT_THE_END:-'-fae'}
readonly RERUN_FAILING_TESTS=${RERUN_FAILING_TESTS:-'0'}

readonly OLD_RELEASES_FOLDER=${OLD_RELEASES_FOLDER:-/opt/old-as-releases}

readonly FOLDER_DOES_NOT_EXIST_ERROR_CODE='3'
readonly ZIP_WORKSPACE=${ZIP_WORKSPACE:-'false'}

if [ -n "${EXECUTOR_NUMBER}" ]; then
  echo -n "Job run by executor ID ${EXECUTOR_NUMBER} "
fi

if [ -n "${WORKSPACE}" ]; then
  echo -n "inside workspace: ${WORKSPACE}"
fi
echo '.'

if [ -z "${MAVEN_HOME}" ] || [ ! -e "${MAVEN_HOME}/bin/mvn" ]; then
    echo "No Maven Home defined - setting to default: ${DEFAULT_MAVEN_HOME}"
    export MAVEN_HOME=${DEFAULT_MAVEN_HOME}
    if [ ! -d  "${DEFAULT_MAVEN_HOME}" ]; then
      echo "No maven install found (${DEFAULT_MAVEN_HOME}) - downloading one:"
      cd "$(pwd)/tools" || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
      MAVEN_HOME="$(pwd)/maven"
      export MAVEN_HOME
      export PATH=${MAVEN_HOME}/bin:${PATH}
      bash ./download-maven.sh
      chmod +x ./*/bin/*
      cd - || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
    fi

    command -v mvn
    mvn -version
fi

readonly MAVEN_BIN_DIR=${MAVEN_HOME}/bin
echo "Adding ${MAVEN_BIN_DIR} to PATH:${PATH}."
export PATH=${MAVEN_BIN_DIR}:${PATH}

command -v java
java -version
# shellcheck disable=SC2181
if [ "${?}" -ne 0 ]; then
   echo "No JVM provided - aborting..."
   exit 1
fi

mkdir -p "${LOCAL_REPO_DIR}"

export MAVEN_OPTS="${MAVEN_OPTS} ${MEMORY_SETTINGS}"
# workaround wagon isseu - https://projects.engineering.redhat.com/browse/SET-20
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.wagon.http.pool=${MAVEN_WAGON_HTTP_POOL}"
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.wagon.httpconnectionManager.maxPerRoute=${MAVEN_WAGON_HTTP_MAX_PER_ROUTE}"
# using project's maven repository
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.repo.local=${LOCAL_REPO_DIR}"

if [ -n "${MAVEN_SETTINGS_XML}" ] && [ "${MAVEN_SETTINGS_XML}" != "none" ]; then
  readonly MAVEN_SETTINGS_XML_OPTION="-s ${MAVEN_SETTINGS_XML}"
else
  readonly MAVEN_SETTINGS_XML_OPTION=''
fi

unset JBOSS_HOME
if [ "${BUILD_COMMAND}" = 'build' ]; then

  if [ -n "${IS_CCI}" ]; then
    zip -qr "jboss-eap-src-${GIT_COMMIT:0:7}.zip" "${EAP_SOURCES_FOLDER}"
    cd "${EAP_SOURCES_DIR}" || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
  fi

  # configure product repository URL used by tests
  export BUILD_OPTS="${BUILD_OPTS} -Dorg.jboss.model.test.maven.repository.urls=http://download.lab.bos.redhat.com/brewroot/repos/jb-eap-6.4-rhel-6-build/latest/maven/,https://repository.jboss.org/nexus/content/repositories/releases/"

  # shellcheck disable=SC2086,SC2068
  echo mvn clean install -Dts.skipTests=true ${MAVEN_VERBOSE}  "${FAIL_AT_THE_END}" ${MAVEN_SETTINGS_XML_OPTION} -B ${BUILD_OPTS} ${@}
  # shellcheck disable=SC2086,SC2068
  mvn clean install -Dts.skipTests=true ${MAVEN_VERBOSE}  "${FAIL_AT_THE_END}" ${MAVEN_SETTINGS_XML_OPTION} -B ${BUILD_OPTS} ${@}
  status=${?}
  if [ "${status}" -ne 0 ]; then
    echo "Compilation failed"
    exit "${GIT_SKIP_BISECT_ERROR_CODE}"
  fi

  if [ "${ZIP_WORKSPACE}" == "true" ]; then
    zip -x "${HARMONIA_FOLDER}" -x \*.zip -qr 'workspace.zip' "${WORKSPACE}"
  fi

  if [ -n "${IS_CCI}" ]; then
    readonly EAP_DIST_DIR=$(get_dist_folder)
    echo "Using ${EAP_DIST_DIR}"

    cd "${EAP_DIST_DIR}" || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
    zip -qr "${WORKSPACE}/jboss-eap-dist-${GIT_COMMIT:0:7}.zip" jboss-eap-*/
    cd "${LOCAL_REPO_DIR}/.." || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
    zip -qr "${WORKSPACE}/jboss-eap-maven-artifacts-${GIT_COMMIT:0:7}.zip" "maven-local-repository"


    cd "${WORKSPACE}"

    record_build_properties
  fi
else
  if ! is_dirpath_defined_and_exists "${OLD_RELEASES_FOLDER}" 'OLD_RELEASES_FOLDER'; then
    echo "Invalid directory for old_releases: ${OLD_RELEASES_FOLDER}. Testsuite will fails to run, aborting."
    exit 3
  fi

  if [ -n "${IS_CCI}" ]; then
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
  fi

  unset JBOSS_HOME
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dsurefire.forked.process.timeout=${SUREFIRE_FORKED_PROCESS_TIMEOUT}"
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dskip-download-sources -B"
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Djboss.test.mixed.domain.dir=${OLD_RELEASES_FOLDER}"
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dmaven.test.failure.ignore=${MAVEN_IGNORE_TEST_FAILURE}"
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dsurefire.rerunFailingTestsCount=${RERUN_FAILING_TESTS}"
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dsurefire.memory.args=-Xmx1024m"

  export TESTSUITE_OPTS="${TESTSUITE_OPTS} ${MAVEN_SETTINGS_XML_OPTION}"

  export TEST_TO_RUN=${TEST_TO_RUN:-'-DallTests'}
  cd "${EAP_SOURCES_DIR}/testsuite" || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
  mvn clean
  cd ..

  # with EAP 6.4, let maven 3.2 be downloaded to the tools/maven/ directory, which is a hardcoded path in the integration-tests.sh script
  bash -x ./tools/download-maven.sh

  # define this var so that integration-tests.sh doesn't use its hardcoded default value
  export MVN_ARGS="-DsomeNoneEmptyValue"

  # configure product repository URL used by integration tests
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dorg.jboss.model.test.eap.repourl=http://download.lab.bos.redhat.com/brewroot/repos/jb-eap-6.4-rhel-6-build/latest/maven/"

  # shellcheck disable=SC2086,SC2068
  bash -x ./integration-tests.sh "${TEST_TO_RUN}" ${MAVEN_VERBOSE} "${FAIL_AT_THE_END}" ${TESTSUITE_OPTS} ${@}
  exit "${?}"
fi
