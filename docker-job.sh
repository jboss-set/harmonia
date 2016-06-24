if [ -z "${WORKSPACE}" ]; then
  echo "No WORKSPACE defined - is this script running inside Jenkins ? If not, set the WORKSPACE value."
  exit 1
fi

if [ -z "${MAVEN_HOME}" ]; then
  echo "No MAVEN_HOME defined, this is required to run the build."
  exit 2
fi

if [ -z "${JAVA_HOME}" ]; then
  echo "JAVA_HOME if not set - this is required for the build to run."
  exit 3
else
  echo "JAVA_HOME:${JAVA_HOME}"
fi

readonly DOCKER_IMAGE=${DOCKER_IMAGE:-'rhel6-jenkins-shared-slave'}

readonly CONTAINER_ID=$(docker run -d -v "${WORKSPACE}:/workspace"  -v "${MAVEN_HOME}:/maven_home" -v "${JAVA_HOME}:/java" -v $(pwd):/job_home "${DOCKER_IMAGE}")

if [ "${?}" -ne 0 ]; then
  echo 'Failed to create container.'
  # just in case container is somehow running
  docker stop ${CONTAINER_ID}
  exit 1
fi

if [ -z "${CONTAINER_ID}" ]; then
  echo "No container - aborting"
  exit 2
fi

trap "docker stop ${CONTAINER_ID}" EXIT INT QUIT TERM
docker exec "${CONTAINER_ID}" /bin/bash /job_home/job-run.sh
status=${?}
docker stop "${CONTAINER_ID}"
exit "${status}"
