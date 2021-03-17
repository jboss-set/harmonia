#!/bin/bash

readonly MVN_REPO='mvn-repo'
readonly MVN_REPO_ZIP='mvn-repo.zip'

if [ -z "${MAVEN_HOME}" ] || [ ! -e "${MAVEN_HOME}/bin/mvn" ]; then
    echo "No maven defined"
    exit 1
fi

readonly MAVEN_BIN_DIR=${MAVEN_HOME}/bin
echo "Adding ${MAVEN_BIN_DIR} to PATH:${PATH}."
export PATH=${MAVEN_BIN_DIR}:${PATH}

if [ $# -ne 1 ]; then
     echo "eap-installer needs action. Allowed values are [testsuite installer commons izpack]"
     exit 2
fi

readonly ACTION=$1
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

    BUILD_OPS="${BUILD_OPTS} -Dmaven.repo.local=${MVN_REPO}"
    if [ "${ACTION}" = 'installer' ] && [ ! -z "${EAP_QUICKSTART_LINK}" ]; then
        BUILD_OPTS="${BUILD_OPTS} -Deap.quickstarts.link=${EAP_QUICKSTART_LINK}"
    fi
    mvn ${BUILD_OPTS} clean install

    zip -rq "${MVN_REPO_ZIP}" "${MVN_REPO}"
else
    Xvfb :1 &
    XVFB_PID=$!
    trap "kill -9 ${XVFB_PID}" EXIT

    readonly ORIGINAL_JARS=( *.jar )
    # check if just one
    readonly VERSION=$(echo ${ORIGINAL_JARS[0]} | sed -r "s/.*([0-9]+\.[0-9]+\.[0-9]).*/\1/")
    readonly INSTALLER=jboss-eap-${VERSION}-installer.jar
    mv "${ORIGINAL_JARS[0]}" "${INSTALLER}"
    
    
    export MAVEN_OPTS="-Xms1968m -Xmx1968m -XX:MaxPermSize=256m"
    export DISPLAY=:1
    export INSTALL_TIMEOUT=600

    BUILD_OPTS="${BUILD_OPTS} -Deap.install.timeout=1000 -Deap.start.timeout=120 -Deap.stop.timeout=20 -fn -fae -Dtests.gui.functional -Dgui.test.timeout=1000"
    mvn clean test -B -Deap.installer="${INSTALLER}" ${BUILD_OPTS}
fi
