if [ ! -z "${EXECUTOR_NUMBER}" ]; then
  echo -n "Job run by executor ID ${EXECUTOR_NUMBER} "
fi

if [ ! -z "${WORKSPACE}" ]; then
  echo -n "inside workspace: ${WORKSPACE}"
fi
echo '.'

. /opt/jboss-set-ci-scripts/common_bash.sh
set_ip_addresses
kill_jboss

which java
java -version

LOCAL_REPO_DIR=$WORKSPACE/maven-local-repository

export MAVEN_OPTS="-Xmx1024m -Xms512m -XX:MaxPermSize=256m"
if [ ! -z "${EXECUTOR_NUMBER}" ]; then
  readonly SUBNET_ID=$(expr ${EXECUTOR_NUMBER} + 1)
  TESTSUITE_OPTS="-Dnode0=127.0.${SUBNET_ID}.1 -Dnode1=127.0.${SUBNET_ID}.2"
fi
TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dsurefire.forked.process.timeout=90000"
TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dskip-download-sources -B"
TESTSUITE_OPTS="${TESTSUITE_OPTS} -Djboss.test.mixed.domain.dir=/opt/old-as-releases"
TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dmaven.test.failure.ignore=false"

export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.repo.local=${LOCAL_REPO_DIR}"


cd testsuite
chmod +x ../tools/maven/bin/mvn
../tools/maven/bin/mvn clean
cd ..

chmod +x ./integration-tests.sh
bash -x ./integration-tests.sh -DallTests ${TESTSUITE_OPTS}
