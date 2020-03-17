#!/bin/bash

readonly DOCKER_CMD=${DOCKER_CMD:-'/usr/bin/docker'}
readonly ROOT_CMD_FOR_DOCKER_CONTAINER=${ROOT_CMD_FOR_DOCKER_CONTAINER:-'/bin/bash'}
readonly DOCKER_IMAGE=${DOCKER_IMAGE:-'rhel6-jenkins-shared-slave'}
readonly WORKSPACE_MOUNT_POINT=${WORKSPACE_MOUNT_POINT:-'/work/'}

docker_cmd() {
  local cmd=${1}
  "${DOCKER_CMD}" "${cmd}" "${CONTAINER_ID}"
}

containerExists() {
  "${DOCKER_CMD}" ps -q -f "ID=${CONTAINER_ID}" | wc -l
}

killContainer() {

  docker_cmd 'stop'
  sleep 1
  if [ "$(containerExists)" -gt 0 ]; then
    docker_cmd 'kill'
  fi
  sleep 1
   docker_cmd 'rm'
}

cleanUpContainer() {
  # shellcheck disable=SC2166
  if [ -z "${KEEP_CONTAINER}" -a -n "${CONTAINER_ID}" -a "$(containerExists)" -gt 0 ]; then
    killContainer
  fi

}

readonly REAL_WORKSPACE=${WORKSPACE}
export WORKSPACE=${WORKSPACE_MOUNT_POINT}

readonly CONTAINER_ID=$("${DOCKER_CMD}" run -e MAVEN_SETTINGS_XML="${MAVEN_SETTINGS_XML}" -e MAVEN_HOME="${MAVEN_HOME}" -v "${REAL_WORKSPACE}:${WORKSPACE_MOUNT_POINT}:rw"  -v '/opt:/opt:ro' -v '/home/jboss:/home/jboss:ro' -tdi --privileged "${DOCKER_IMAGE}" "${ROOT_CMD_FOR_DOCKER_CONTAINER}")
trap cleanUpContainer EXIT
docker exec -t "${CONTAINER_ID}" "${PATH_TO_SCRIPT}"
