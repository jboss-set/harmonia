#!/bin/bash
#
#
# Run Cryo: https://github.com/jboss-set/cryo,
# a git bisect implementation based on github pull requests
#
set -eox pipefail

readonly PARENT_JOB_DIR=${PARENT_JOB_DIR:-'/parent_job'}
readonly APHRODITE_CONFIG=${APHRODITE_CONFIG:-'/opt/tools/aphrodite.json'}
readonly MAVEN_LOCAL_REPO=${MAVEN_LOCAL_REPO:-${WORKSPACE}/maven-local-repository}

export MEMORY_SETTINGS=${MEMORY_SETTINGS:-'-Xmx2048m -Xms1024m -XX:MaxPermSize=512m'}
export MAVEN_SETTINGS_XML=${MAVEN_SETTINGS_XML:-'/opt/tools/settings.xml'}

export MAVEN_OPTS="${MAVEN_OPTS} ${MEMORY_SETTINGS}"
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.wagon.http.ssl.insecure=true -Dhttps.protocols=TLSv1.2 -Dmaven.repo.local=${MAVEN_LOCAL_REPO}"
export MAVEN_OPTS="${MAVEN_OPTS} -Dskip-download-sources -DskipSources -Dmaven.source.skip -Dsource.skip -Dproject.src.skip"

readonly PARAMS_FILE=${PARAMS_FILE:-${WORKSPACE}/../cryo-params.sh}
if [ -f "${PARAMS_FILE}" ]; then
  . "${PARAMS_FILE}"
fi

if [ -n "${MAVEN_HOME}" ]; then
  export PATH=${MAVEN_HOME}/bin:${PATH}
fi

readonly ARCHIVE_LAST=${ARCHIVE_LAST:-''}
# cryo.jar arguments
readonly INCLUDE_LIST=${INCLUDE_LIST:-''}
readonly EXCLUDE_LIST=${EXCLUDE_LIST:-''}
readonly SUFFIX=${SUFFIX:-'.future'}
readonly DRY_RUN=${DRY_RUN:-'true'}
readonly FLIP=${FLIP:-'true'}
readonly CHECK_STATE=${CHECK_STATE:-''}
readonly FAST_LOGGING=${FAST_LOGGING:-''}
# shellcheck disable=SC2016
readonly MAVEN_ARGS=${MAVEN_ARGS:-"-Dmaven.wagon.http.ssl.insecure=true,-Dhttps.protocols=TLSv1.2,-Dnorpm,-Dskip-download-sources,-DskipSources,-Dmaven.source.skip,-Dsource.skip,-Dproject.src.skip"}

# scripts:
CRYO_COMMAND_ARGS="-o HarmoniaOperationCenter -r ${WORKSPACE}"
if [[ -n "${EXCLUDE_LIST}" ]]; then
    CRYO_COMMAND_ARGS="$CRYO_COMMAND_ARGS -e ${EXCLUDE_LIST}"
fi
if [[ -n "${INCLUDE_LIST}" ]]; then
    CRYO_COMMAND_ARGS="$CRYO_COMMAND_ARGS -i ${INCLUDE_LIST}"
fi
if [[ -n "${SUFFIX}" ]]; then
    CRYO_COMMAND_ARGS="$CRYO_COMMAND_ARGS -s ${SUFFIX}"
fi
if [[ "${DRY_RUN}" != "false" ]]; then
    CRYO_COMMAND_ARGS="$CRYO_COMMAND_ARGS -d"
fi
if [[ "${FLIP}" = "true" ]]; then
    CRYO_COMMAND_ARGS="$CRYO_COMMAND_ARGS -f"
fi
if [[ "${FAST_LOGGING}" = "true" ]]; then
    CRYO_COMMAND_ARGS="$CRYO_COMMAND_ARGS -q"
fi
if [[ "${CHECK_STATE}" = "true" ]]; then
    CRYO_COMMAND_ARGS="$CRYO_COMMAND_ARGS -c"
fi

# use HarmoniaOperationCenter which requires env.ENV_HARMONIA_BUILD_SH pointing to eap-job.sh
HARMONIA_HOME="$(cd ${WORKSPACE}/../harmonia && pwd)"
export ENV_HARMONIA_BUILD_SH=${HARMONIA_HOME}/eap-job.sh

# disable interactive mode in pr-merge
export NO_STOP_BEFORE_MERGE="true"

AUXILIA_HOME="$(cd ${WORKSPACE}/../auxilia && pwd)"
export PATH=${AUXILIA_HOME}:${PATH}

# hack to download jq which is needed by pr-merge
echo -e "Hacking by downloading jq."
curl -s -L -o ${AUXILIA_HOME}/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x ${AUXILIA_HOME}/jq

echo "WORKSPACE: ${WORKSPACE}"
echo "HARMONIA_HOME: ${HARMONIA_HOME}"
echo "AUXILIA_HOME: ${AUXILIA_HOME}"
echo "CRYO_COMMAND_ARGS: ${CRYO_COMMAND_ARGS}"

CRYO_JAR="$(ls ${PARENT_JOB_DIR}/target/cryo-*[^sources].jar)"
echo "CRYO_JAR: ${CRYO_JAR}"

CRYO_COMMAND_OPTS="-Djava.util.logging.manager=org.jboss.logmanager.LogManager"
CRYO_COMMAND_OPTS="-Daphrodite.config=${APHRODITE_CONFIG}"
CRYO_COMMAND="java ${CRYO_COMMAND_OPTS} -jar ${CRYO_JAR} ${CRYO_COMMAND_ARGS}"
if [[ -n "${MAVEN_ARGS}" ]]; then
	CRYO_COMMAND="${CRYO_COMMAND} -m${MAVEN_ARGS}"
fi

# do not zip workspace.zip when running eap-job.sh
export ZIP_WORKSPACE=

${CRYO_COMMAND}

#Create archive to avoid default excludes. Cleanup, tar and compress in place
mvn clean -DallTests

if  [[ -n "${ARCHIVE_LAST}" ]]; then
  EAP_FILE_ARCHIVE="eap_$(git rev-parse --abbrev-ref HEAD).tar.gz"
  touch "$EAP_FILE_ARCHIVE"
  tar -czf "$EAP_FILE_ARCHIVE" --exclude="$EAP_FILE_ARCHIVE" --exclude="workspace.zip" .
fi