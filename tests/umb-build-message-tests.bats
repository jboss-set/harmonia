#!/bin/bash

readonly SCRIPT_NAME='umb-build-message.sh'
source ./tests/tests-common.sh

teardown() {
    deleteIfExist "message_body.json"
    deleteIfExist "MESSAGE.txt"
}

setDefaultProperties() {
    export SERVER_URL="http://foo.bar/server"
    export BUILD_ID=1234
    export BUILD_URL="http://foo.bar/build"
    export SCM_URL="http.scm.foo.bar"
    export SCM_REVISION="abcdef"
    export RELEASE_NAME="7.1"
    export RELEASE_STREAM="7.1.x"
    export RELEASE_TYPE="test"
    export VERSION="7.1.2"
    export BASE_VERSION="7.1.1"
}

@test "Create json file" {
    setDefaultProperties

    run ${SCRIPT}

    [ ${status} -eq 0 ]
    [ -f "message_body.json" ]
}

@test "Test created json has correct build data" {
    setDefaultProperties

    run ${SCRIPT}

    [ ${status} -eq 0 ]
    [ $(jq .release.bits.server.url message_body.json) = '"http://foo.bar/server"' ]
    [ $(jq '.release.bits.server."build-id"' message_body.json) = '"1234"' ]
}

@test "Fail run if any properties are missing" {
    setDefaultProperties
    unset RELEASE_NAME

    run ${SCRIPT}
    [ ${status} -eq 2 ]
    [ "${lines[0]}" = 'Required properties are not found: RELEASE_NAME' ]
}

@test "List all missing properties" {
    setDefaultProperties
    unset RELEASE_NAME
    unset SCM_URL

    run ${SCRIPT}
    [ ${status} -eq 2 ]
    echo ${lines[0]}
    [ "${lines[0]}" = 'Required properties are not found: SCM_URL RELEASE_NAME' ]
}