cd $(dirname ${0})

export JAVA_HOME=/java
export PATH=${JAVA_HOME}/bin:${PATH}

readonly LOCAL_REPO_DIR=/workspace/maven-local-repository

bash -x /opt/jboss-set-ci-scripts/eap-63-testsuite.sh
