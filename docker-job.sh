if [ ! -z "${WORKSPACE}" ]; then
  echo -n "inside workspace: ${WORKSPACE}"
fi
echo '.'

readonly DOCKER_IMAGE=${DOCKER_IMAGE:-'rhel6-jenkins-shared-slave'}

readonly CONTAINER_ID=$(docker run -d -v "${WORKSPACE}:/workspace"  -v "${MAVEN_HOME}:/maven_home" -v $(pwd):/job_home "${DOCKER_IMAGE}")

if [ "${?}" -ne 0 ]; then
  echo 'Failed to create container.'
  # just in case container is somehow running
  docker stop ${CONTAINER_ID}
  exit 1
fi

trap "docker stop ${CONTAINER_ID}" EXIT INT QUIT TERM
docker exec "${CONTAINER_ID}" /bin/bash /job_home/job-run.sh
status=${?}
docker stop "${CONTAINER_ID}"
exit "${status}"


