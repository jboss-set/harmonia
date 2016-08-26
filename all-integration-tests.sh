#!/bin/bash
#
# Run all integration test from Widlfly/EAP
#
# Allow to override the following values:
readonly LOCAL_REPO_DIR=${LOCAL_REPO_DIR:-"${WORKSPACE}/maven-local-repository"}
readonly OLD_RELEASES_FOLDER=${OLD_RELEASES_FOLDER:-'/opt/old-as-releases'}
readonly MEMORY_SETTINGS=${MEMORY_SETTINGS:-'-Xmx1024m -Xms512m -XX:MaxPermSize=256m'}
readonly SUREFIRE_FORKED_PROCESS_TIMEOUT=${SUREFIRE_FORKED_PROCESS_TIMEOUT:-'90000'}
readonly MAVEN_IGNORE_TEST_FAILURE=${MAVEN_IGNORE_TEST_FAILURE:-'false'}
readonly DEFAULT_MAVEN_HOME="$(pwd)/tools/maven"
# and will reuse MAVEN_OPTS and TESTSUITE_OPTS if defined.

echo "JAVA_HOME: ${JAVA_HOME}"
if [ -n "${JAVA_HOME}" ]; then
   export PATH=${JAVA_HOME}/bin:${PATH}
   java -version
fi

if [ -n "${MAVEN_HOME}" ]; then
  echo "No Maven Home defined - setting to default: ${DEFAULT_MAVEN_HOME}"
  export MAVEN_HOME=${DEFAULT_MAVEN_HOME}
  cd $(pwd)/tools
  bash ./download-maven.sh
  cd -
  export PATH=${MAVEN_HOME}/bin:${PATH}
  which mvn
  mvn -version
fi

if [ ! -z "${EXECUTOR_NUMBER}" ]; then
  echo -n "Job run by executor ID ${EXECUTOR_NUMBER} "
fi

if [ ! -z "${WORKSPACE}" ]; then
  echo -n "inside workspace: ${WORKSPACE}"
fi
echo '.'

. /opt/jboss-set-ci-scripts/common_bash.sh
set_ip_addresses
trap "kill_jboss" EXIT INT QUIT TERM
kill_jboss

which java
java -version

which mvn
mvn -version

export MAVEN_OPTS="${MAVEN_OPTS} ${MEMORY_SETTINGS}"
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.repo.local=${LOCAL_REPO_DIR}"

export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dsurefire.forked.process.timeout=${SUREFIRE_FORKED_PROCESS_TIMEOUT}"
export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dskip-download-sources -B"
export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Djboss.test.mixed.domain.dir=${OLD_RELEASES_FOLDER}"
export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dmaven.test.failure.ignore=${MAVEN_IGNORE_TEST_FAILURE}"

cd testsuite
mvn clean
cd ..

chmod +x ./integration-tests.sh
bash -x ./integration-tests.sh -DallTests ${TESTSUITE_OPTS}
