#!/bin/bash

readonly MVN_REPO=${MVN_REPO:-'mvn-repo'}
readonly MVN_REPO_ZIP=${MVN_REPO_ZIP:-'mvn-repo.zip'}

verify_maven() {
  if [ -z "${MAVEN_HOME}" ]; then
   echo 'MAVEN_HOME variable not set'
   return 1
  fi
  if [ ! -d "${MAVEN_HOME}" ] || [ ! -d "${MAVEN_HOME}/bin" ]; then
    echo "${MAVEN_HOME}/bin is not a directory"
    return 1
  fi
  if [ ! -e "${MAVEN_HOME}/bin/mvn" ] || [ ! -x "${MAVEN_HOME}/bin/mvn" ]; then
    echo "${MAVEN_HOME}/bin/mvn is not present or is not executable"
    return 1
  fi

  return 0
}

if ! verify_maven; then
    echo 'Maven is required to run the build. Please see above'
    exit 1
fi

readonly MAVEN_BIN_DIR="${MAVEN_HOME}/bin"
echo "Adding ${MAVEN_BIN_DIR} to PATH:${PATH}."
export PATH=${MAVEN_BIN_DIR}:${PATH}

if [ $# -ne 1 ]; then
     echo "eap-installer needs action. Allowed values are [testsuite installer commons izpack]"
     exit 2
fi

readonly ACTION="${1}"
if [ "${ACTION}" != 'testsuite' ] && [ "${ACTION}" != 'installer' ] &&
    [ "${ACTION}" != 'izpack' ] && [ "${ACTION}" != 'commons' ]; then
    echo "Unknown action: ${ACTION}"
    exit 2
fi

if [ "${ACTION}" != 'testsuite' ]; then
    if [ "${ACTION}" = 'izpack' ]; then
        mkdir "${MVN_REPO}"
    else 
        unzip "${MVN_REPO_ZIP}"
    fi

    BUILD_OPTS="${BUILD_OPTS} -Dmaven.repo.local=${MVN_REPO}"
    if [ "${ACTION}" = 'installer' ] && [ -n "${EAP_QUICKSTART_LINK}" ]; then
        BUILD_OPTS="${BUILD_OPTS} -Deap.quickstarts.link=${EAP_QUICKSTART_LINK}"
    fi
    # shellcheck disable=SC2086
    # BUILD_OPTS has to be interpreted as multiple parameters
    mvn ${BUILD_OPTS} clean install

    zip -rq "${MVN_REPO_ZIP}" "${MVN_REPO}"
else
    Xvfb :1 &
    XVFB_PID=$!
    # shellcheck disable=SC2064
    # evaluate XVFB_PID now rather then when called
    trap "kill -9 ${XVFB_PID}" EXIT

    readonly ORIGINAL_JARS=( *.jar )
    # check if just one
    readonly VERSION=$(echo "${ORIGINAL_JARS[0]}" | sed -r "s/.*([0-9]+\.[0-9]+\.[0-9]).*/\1/")
    readonly INSTALLER="jboss-eap-${VERSION}-installer.jar"
    mv "${ORIGINAL_JARS[0]}" "${INSTALLER}"
    
    
    export MAVEN_OPTS="-Xms1968m -Xmx1968m -XX:MaxPermSize=256m"
    export DISPLAY=:1
    export INSTALL_TIMEOUT=600

    BUILD_OPTS="${BUILD_OPTS} -Deap.install.timeout=1000 -Deap.start.timeout=120 -Deap.stop.timeout=20 -fn -fae -Dtests.gui.functional -Dgui.test.timeout=1000"
    # shellcheck disable=SC2086
    # BUILD_OPTS has to be interpreted as multiple parameters
    mvn clean test -B -Deap.installer="${INSTALLER}" ${BUILD_OPTS}
fi
