#!/bin/bash

# E1. unknown action

readonly SCRIPT_NAME='eap-installer.sh'
source ./tests/tests-common.sh

setup() {
  export MAVEN_HOME=$(mktemp -d)
  mkdir ${MAVEN_HOME}/bin
  cp "${DUMMY_MVN}" "${MAVEN_HOME}/bin/"

  createDummyBackgroundCommand 'Xvfb'
  export PATH=.:${PATH}
}

teardown() {
    deleteIfExist "${MAVEN_HOME}"
    deleteIfExist 'mvn-repo'
    deleteIfExist 'mvn-repo.zip'
    deleteIfExist 'Xvfb'
    deleteIfExist 'jboss-eap-installer-7.4.0.Beta-redhat-SNAPSHOT.jar'
    deleteIfExist 'jboss-eap-7.4.0-installer.jar'
}

create_dummy_repo() {
    mkdir 'mvn-repo'
    touch 'mvn-repo/dummy'
    zip -r 'mvn-repo.zip' 'mvn-repo'
    deleteIfExist 'mvn-repo'
}

@test "Build izpack" {
    run "${SCRIPT}" 'izpack'

    [ $status -eq 0 ]
    [ "${lines[${#lines[@]}-1]}" = "mvn -Dmaven.repo.local=mvn-repo clean install" ]
    [ -d 'mvn-repo' ]
    [ -f 'mvn-repo.zip' ]
}

@test "Build commons" {
    create_dummy_repo

    run "${SCRIPT}" 'commons'

    [ $status -eq 0 ]
    [ "${lines[${#lines[@]}-1]}" = "mvn -Dmaven.repo.local=mvn-repo clean install" ]
    [ -d 'mvn-repo' ]
    [ -f 'mvn-repo/dummy' ] # verify zip was unpacked
    [ -f 'mvn-repo.zip' ]
}

@test "Build installer" {
    create_dummy_repo

    run "${SCRIPT}" 'installer'

    [ $status -eq 0 ]
    [ "${lines[${#lines[@]}-1]}" = "mvn -Dmaven.repo.local=mvn-repo clean install" ]
    [ -d 'mvn-repo' ]
    [ -f 'mvn-repo/dummy' ] # verify zip was unpacked
    [ -f 'mvn-repo.zip' ]
}

@test "Run testsuite" {
    # add wait to the dummy mvn command to give dummy Xvfb a chance to log it's execution
    echo "#! /bin/bash" > "${MAVEN_HOME}/bin/mvn"
    echo "sleep 1" >> "${MAVEN_HOME}/bin/mvn"
    echo 'echo "mvn ${@}" >&2' >> "${MAVEN_HOME}/bin/mvn"
    # create dummy installer jar
    touch "jboss-eap-installer-7.4.0.Beta-redhat-SNAPSHOT.jar"

    run "${SCRIPT}" 'testsuite'
    
    [ $status -eq 0 ]
    [ "${lines[${#lines[@]}-2]}" = 'Xvfb :1' ]
    [ "${lines[${#lines[@]}-1]}" = "mvn clean test -B -Deap.installer=jboss-eap-7.4.0-installer.jar -Deap.install.timeout=1000 -Deap.start.timeout=120 -Deap.stop.timeout=20 -fn -fae -Dtests.gui.functional -Dgui.test.timeout=1000" ]
}

@test "Unknown action causes error" {
    run "${SCRIPT}" 'something'

for l in "${lines[@]}"
    do
        echo $l
    done
    [ $status -eq 2 ]
}

@test "No action causes error" {
    run "${SCRIPT}"

    [ $status -eq 2 ]
}