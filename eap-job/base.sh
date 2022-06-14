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

check_java() {
  # ensure provided JAVA_HOME, if any, is first in PATH
  if [ -n "${JAVA_HOME}" ]; then
    export PATH=${JAVA_HOME}/bin:${PATH}
  fi

  command -v java
  java -version
  # shellcheck disable=SC2181
  if [ "${?}" -ne 0 ]; then
     echo "No JVM provided - aborting..."
     exit 1
  fi
}

configure_mvn_home() {
  if [ -z "${MAVEN_HOME}" ] || [ ! -e "${MAVEN_HOME}/bin/mvn" ]; then
    echo "No Maven Home defined - setting to default: ${DEFAULT_MAVEN_HOME}"
    export MAVEN_HOME=${DEFAULT_MAVEN_HOME}
    if [ ! -d  "${DEFAULT_MAVEN_HOME}" ]; then
      echo "No maven install found (${DEFAULT_MAVEN_HOME}) - downloading one:"
      cd "$(pwd)/tools" || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
      MAVEN_HOME="$(pwd)/maven"
      export MAVEN_HOME
      bash ./download-maven.sh
      chmod +x ./*/bin/*
      cd - || exit "${FOLDER_DOES_NOT_EXIST_ERROR_CODE}"
      readonly IS_MAVEN_LOCAL=${IS_MAVEN_LOCAL:-'true'}
      export IS_MAVEN_LOCAL
    fi
  fi
  configure_mvn_vbe_if_required
  
  #export PATH="${MAVEN_HOME}"/bin:"${PATH}"
  readonly MAVEN_BIN_DIR="${MAVEN_HOME}"/bin
  export MAVEN_BIN_DIR
  echo "Adding ${MAVEN_BIN_DIR} to PATH:${PATH}."
  export PATH="${MAVEN_BIN_DIR}":"${PATH}"

  command -v mvn
  mvn -version
  # shellcheck disable=SC2181
  if [ "${?}" -ne 0 ]; then
    echo "No MVN provided - aborting..."
    exit 2
  fi
}

configure_mvn_vbe_if_required(){
  if [ -n "${VBE_EXTENSION}" ]; then
	  	#copy, into local, if its dwn, dont copy, just alter
	  	echo "------------------ SETTING UP Version Bump Extension ------------------"
	  	readonly PARENT_JOB_DIR=${PARENT_JOB_DIR:-'/parent_job'}
	  	VBE_JAR=$(ls "${PARENT_JOB_DIR}/target/*-extension-*[^sources].jar")
		echo "VBE_JAR: ${VBE_JAR}"
	
		if [ -z "${IS_MAVEN_LOCAL}" ]; then
			#Not local, we need one
			mkdir "$(pwd)/maven"
			cp -r "$MAVEN_HOME"/* "$(pwd)/maven"
			readonly MAVEN_HOME="$(pwd)/maven"
			export MAVEN_HOME
		fi
		mkdir -p "$MAVEN_HOME/lib/ext"
		cp "$VBE_JAR" "$MAVEN_HOME/lib/ext/"
		if [ -n "${VBE_CHANNELS}" ]; then
	            export MAVEN_OPTS="${MAVEN_OPTS} -Dvbe.channels=${VBE_CHANNELS}"
		fi
		if [ -n "${VBE_LOG_FILE}" ]; then
	            export MAVEN_OPTS="${MAVEN_OPTS} -Dvbe.log.file=${VBE_LOG_FILE}"
		fi
		if [ -n "${VBE_REPOSITORY_NAMES}" ]; then
	            export MAVEN_OPTS="${MAVEN_OPTS} -Dvbe.repository.names=${VBE_REPOSITORY_NAMES}"
		fi
		echo "------------------ DONE SETTING UP Version Bump Extension ------------------"
	else
		readonly MAVEN_HOME="${MAVEN_HOME}"
		export MAVEN_HOME
  fi
}

configure_mvn_opts() {
  if [ -n "${LOCAL_REPO_DIR}" ]; then
    mkdir -p "${LOCAL_REPO_DIR}"
  fi
  export MAVEN_OPTS="${MAVEN_OPTS} ${MEMORY_SETTINGS}"
  # workaround wagon issue - https://projects.engineering.redhat.com/browse/SET-20
  export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.wagon.http.pool=${MAVEN_WAGON_HTTP_POOL}"
  export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.wagon.httpconnectionManager.maxPerRoute=${MAVEN_WAGON_HTTP_MAX_PER_ROUTE}"
  # using project's maven repository
  export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.repo.local=${LOCAL_REPO_DIR}"
}

configure_mvn_settings() {
  if [ -n "${MAVEN_SETTINGS_XML}" ]; then
    readonly MAVEN_SETTINGS_XML_OPTION="-s ${MAVEN_SETTINGS_XML}"
  else
    readonly MAVEN_SETTINGS_XML_OPTION=''
  fi
  export MAVEN_SETTINGS_XML_OPTION
}

build() {

  # shellcheck disable=SC2086,SC2068
  echo mvn clean install ${MAVEN_VERBOSE}  "${FAIL_AT_THE_END}" ${MAVEN_SETTINGS_XML_OPTION} -B ${BUILD_OPTS} ${@}
  # shellcheck disable=SC2086,SC2068
  mvn clean install ${MAVEN_VERBOSE}  "${FAIL_AT_THE_END}" ${MAVEN_SETTINGS_XML_OPTION} -B ${BUILD_OPTS} ${@}
  status=${?}
  if [ "${status}" -ne 0 ]; then
    echo "Compilation failed"
    exit "${GIT_SKIP_BISECT_ERROR_CODE}"
  fi

  if [ -n "${ZIP_WORKSPACE}" ]; then
    zip -x "${HARMONIA_FOLDER}" -x \*.zip -qr 'workspace.zip' "${WORKSPACE}"
  fi
}

testsuite() {

  if ! is_dirpath_defined_and_exists "${OLD_RELEASES_FOLDER}" 'OLD_RELEASES_FOLDER'; then
    echo "Invalid directory for old_releases: ${OLD_RELEASES_FOLDER}. Testsuite will fails to run, aborting."
    exit 3
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

  # shellcheck disable=SC2086,SC2068
  bash -x ./integration-tests.sh "${TEST_TO_RUN}" ${MAVEN_VERBOSE} "${FAIL_AT_THE_END}" ${TESTSUITE_OPTS} ${@}
  exit "${?}"
}

record_build_properties() {
  readonly PROPERTIES_FILE='umb-build.properties'
  # shellcheck disable=SC2155
  readonly EAP_VERSION=$(grep -r '<full.dist.product.release.version>' "$EAP_SOURCES_DIR/pom.xml" | sed 's/.*>\(.*\)<.*/\1/')

  # shellcheck disable=SC2129
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

function get_dist_folder() {
    dist_folder="ee-dist/target"
    eap_version=$(xmllint pom.xml --xpath "//*[local-name()='project']/*[local-name()='properties']/*[local-name()='jboss.eap.release.version']/text()")
    if [ -n "${eap_version}" ]; then
        major="${eap_version%.*}"
        minor="${eap_version##*.}"
        if [ -n "${major}" ] && [ "${major}" = "7" ]; then
            if [ -n "${minor}" ] && [ "${minor}" -lt "4" ]; then
                dist_folder="dist/target"
            else
                dist_folder="ee-dist/target"
            fi
        elif [ "${major}" = "8" ]; then
            dist_folder="ee-dist/target"
        else
            echo "Unsupported major version: ${major}"
            exit 1
        fi
    else
        # TODO: verify we're building WFLY
        dist_folder="ee-dist/target"
    fi

    grep -q expansion.pack.release.version pom.xml
    # shellcheck disable=SC2181
    if [ "${?}" -eq 0 ]; then
        dist_folder="dist/target"
    fi

    echo "${dist_folder}"
}

setup() {
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
  readonly GIT_SKIP_BISECT_ERROR_CODE=${GIT_SKIP_BISECT_ERROR_CODE:-'125'}

  readonly LOCAL_REPO_DIR=${LOCAL_REPO_DIR:-${WORKSPACE}/maven-local-repository}
  readonly MEMORY_SETTINGS=${MEMORY_SETTINGS:-'-Xmx2048m -Xms1024m'}

  readonly BUILD_OPTS=${BUILD_OPTS:-'-Drelease'}

  readonly MAVEN_WAGON_HTTP_POOL=${WAGON_HTTP_POOL:-'false'}
  readonly MAVEN_WAGON_HTTP_MAX_PER_ROUTE=${MAVEN_WAGON_HTTP_MAX_PER_ROUTE:-'3'}
  readonly SUREFIRE_FORKED_PROCESS_TIMEOUT=${SUREFIRE_FORKED_PROCESS_TIMEOUT:-'90000'}
  readonly FAIL_AT_THE_END=${FAIL_AT_THE_END:-'-fae'}
  readonly RERUN_FAILING_TESTS=${RERUN_FAILING_TESTS:-'0'}

  readonly OLD_RELEASES_FOLDER=${OLD_RELEASES_FOLDER:-/opt/old-as-releases}

  readonly FOLDER_DOES_NOT_EXIST_ERROR_CODE='3'
  readonly ZIP_WORKSPACE=${ZIP_WORKSPACE:-'false'}

  # use PARAMS to account for shift
  readonly PARAMS=${@}

  if [ -n "${EXECUTOR_NUMBER}" ]; then
    echo -n "Job run by executor ID ${EXECUTOR_NUMBER} "
  fi

  if [ -n "${WORKSPACE}" ]; then
    echo -n "inside workspace: ${WORKSPACE}"
  fi
  echo '.'

  check_java
  configure_mvn_home
  configure_mvn_opts
  configure_mvn_settings
}

pre_build() {
  :
}

post_build() {
  :
}

pre_test() {
  :
}

do_run() {
  if [ "${BUILD_COMMAND}" = 'build' ]; then
    pre_build

    # shellcheck disable=SC2068
    build ${PARAMS}

    post_build
  else
    pre_test

    # shellcheck disable=SC2068
    testsuite ${PARAMS}
  fi
}
