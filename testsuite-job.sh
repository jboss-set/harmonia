/home/jboss/jenkins_workspace/jobs/eap-6.4.x-proposed-build/lastSuccessful/archive
readonly JENKINS_HOME=${JENKINS_HOME:-'/home/jboss/jenkins_workspace/'}
readonly JENKINS_URL=${1}
readonly JOB_NAME=${2}
readonly JENKINS_USERNAME=${3}
readonly JENKINS_PASSWORD=${4}
readonly UPSTREAM_BUILD_URL=${5}

if [ -z "${JENKINS_USERNAME}" ]; then
  echo "Missing JENKINS_USERNAME"
  exit 1
fi

if [ -z "${JENKINS_PASSWORD}" ]; then
  echo "Missing JENKINS_PASSWORD"
  exit 2
fi

if [ -z "${UPSTREAM_BUILD_URL}"  ]; then
  rsync -Avrz "${JENKINS_HOME}/jobs/${JOB_NAME}/lastSuccessful/archive/*" .
else

  if [ -z "${JENKINS_URL}" ] ; then
    echo "Missing JENKINS_URL"
    exit 3
  fi

  if [ -z "${JOB_NAME}" ] ; then
    echo "Missing JOB_NAME"
    exit 4
  fi

  ARCHIVE_URL="${UPSTREAM_BUILD_URL}/artifact/*zip*/archive.zip"

  archive=$(mktemp)
  wget --auth-no-challenge --user "${JENKINS_USERNAME}" --password "${JENKINS_PASSWORD}" -nv "${ARCHIVE_URL}" -O "${archive}"
  unzip -q "${archive}" -d archive
  rm "${archive}"
  cd archive
  mv * ..
fi

. /opt/jboss-set-ci-scripts/common_bash.sh
set_ip_addresses
kill_jboss

which java
java -version

LOCAL_REPO_DIR=$WORKSPACE/maven-local-repository

export MAVEN_OPTS="-Xmx1024m -Xms512m -XX:MaxPermSize=256m"
TESTSUITE_OPTS="-Dnode0=127.0.1.1 -Dnode1=127.0.2.1"
TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dsurefire.forked.process.timeout=90000"
TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dskip-download-sources -B"
TESTSUITE_OPTS="${TESTSUITE_OPTS} -Djboss.test.mixed.domain.dir=/opt/old-as-releases"
TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dmaven.test.failure.ignore=true"

export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.repo.local=${LOCAL_REPO_DIR}"


cd testsuite
chmod +x ../tools/maven/bin/mvn
../tools/maven/bin/mvn clean
cd ..

chmod +x ./integration-tests.sh
./integration-tests.sh -DallTests ${TESTSUITE_OPTS}
