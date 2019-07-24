#!/bin/bash
#
#
# Build Wildlfy/EAP
#

usage() {
  local script_name=$(basename ${0})
  echo "${script_name} <build|testsuite> [extra-args]"
  echo
  echo "ex: ${script_name} 'testsuite' -Dcustom.args"
  echo
  echo Note that if no arguments is provided, it default to 'build'. To run the testsuite, you need to provide 'testsuite' as a first argument. All arguments beyond this first will be appended to the mvn command line.
  echo
  echo 'Warning: This script also set several mvn args. Please refer to its content before adding some extra maven arguments.'
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

# ensure provided JAVA_HOME, if any, is first in PATH
if [ ! -z "${JAVA_HOME}" ]; then
  export PATH=${JAVA_HOME}/bin:${PATH}
fi

readonly GIT_SKIP_BISECT_ERROR_CODE=${GIT_SKIP_BISECT_ERROR_CODE:-'125'}

readonly LOCAL_REPO_DIR=${LOCAL_REPO_DIR:-${WORKSPACE}/maven-local-repository}
readonly MEMORY_SETTINGS=${MEMORY_SETTINGS:-'-Xmx1024m -Xms512m -XX:MaxPermSize=256m'}

readonly MAVEN_SETTINGS_XML=${MAVEN_SETTINGS_XML-'/home/master/settings.xml'}
readonly MAVEN_WAGON_HTTP_POOL=${WAGON_HTTP_POOL:-'false'}
readonly MAVEN_WAGON_HTTP_MAX_PER_ROUTE=${MAVEN_WAGON_HTTP_MAX_PER_ROUTE:-'3'}

readonly OLD_RELEASES_FOLDER=${OLD_RELEASES_FOLDER:-/opt/old-as-releases}

if [ ! -z "${EXECUTOR_NUMBER}" ]; then
  echo -n "Job run by executor ID ${EXECUTOR_NUMBER} "
fi

if [ ! -z "${WORKSPACE}" ]; then
  echo -n "inside workspace: ${WORKSPACE}"
fi
echo '.'


if [ -z "${MAVEN_HOME}" ] || [ ! -e "${MAVEN_HOME}/bin/mvn" ]; then
    echo "No Maven Home defined - setting to default: ${DEFAULT_MAVEN_HOME}"
    export MAVEN_HOME=${DEFAULT_MAVEN_HOME}
    if [ ! -d  "${DEFAULT_MAVEN_HOME}" ]; then
      echo "No maven install found (${DEFAULT_MAVEN_HOME}) - downloading one:"
      cd $(pwd)/tools
      export MAVEN_HOME=$(pwd)
      bash ./download-maven.sh
      chmod +x */bin/*
      cd -
    fi

    which mvn
    mvn -version
fi

readonly MAVEN_BIN_DIR=${MAVEN_HOME}/bin
echo "Adding ${MAVEN_BIN_DIR} to PATH:${PATH}."
export PATH=${MAVEN_BIN_DIR}:${PATH}

which java
java -version
if [ "${?}" -ne 0 ]; then
   echo "No JVM provided - aborting..."
   exit 1
fi

which mvn
mvn -version
if [ "${?}" -ne 0 ]; then
   echo "No MVN provided - aborting..."
   exit 2
fi

mkdir -p "${LOCAL_REPO_DIR}"

export MAVEN_OPTS="${MAVEN_OPTS} ${MEMORY_SETTINGS}"
# workaround wagon isseu - https://projects.engineering.redhat.com/browse/SET-20
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.wagon.http.pool=${MAVEN_WAGON_HTTP_POOL}"
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.wagon.httpconnectionManager.maxPerRoute=${MAVEN_WAGON_HTTP_MAX_PER_ROUTE}"
# using project's maven repository
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.repo.local=${LOCAL_REPO_DIR}"

if [ ! -z "${MAVEN_SETTINGS_XML}" ]; then
  readonly MAVEN_SETTINGS_XML_OPTION="-s ${MAVEN_SETTINGS_XML}"
else
  readonly MAVEN_SETTINGS_XML_OPTION=''
fi

unset JBOSS_HOME
if [ "${BUILD_COMMAND}" = 'build' ]; then
  mvn clean install ${MAVEN_SETTINGS_XML_OPTION} -B ${BUILD_OPTS} ${@}
  status=${?}
  if [ "${status}" -ne 0 ]; then
    echo "Compilation failed"
    exit "${GIT_SKIP_BISECT_ERROR_CODE}"
  fi
else
  unset JBOSS_HOME
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dsurefire.forked.process.timeout=${SUREFIRE_FORKED_PROCESS_TIMEOUT}"
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dskip-download-sources -B"
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Djboss.test.mixed.domain.dir=${OLD_RELEASES_FOLDER}"
  export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dmaven.test.failure.ignore=${MAVEN_IGNORE_TEST_FAILURE}"

  export TESTSUITE_OPTS="${TESTSUITE_OPTS} ${MAVEN_SETTINGS_XML_OPTION}"
  cd testsuite
  mvn clean
  cd ..

  bash -x ./integration-tests.sh -DallTests -fae ${TESTSUITE_OPTS} ${@}
  exit "${?}"
fi
