#!/bin/bash
set -eo pipefail
readonly PATH_TO_ARCHIVE_TO_FETCH=${1}
#/webserver/5.6.2/jws-5.6.2-application-server-RHEL8-x86_64.zip
readonly PATH_TO_ARCHIVE_FILE=${2}

readonly MIDDLEWARE_DOWNLOAD_RELEASE_SERVER_URL=${MIDDLEWARE_DOWNLOAD_RELEASE_SERVER_URL}
readonly URL_TO_ARCHIVE="${MIDDLEWARE_DOWNLOAD_RELEASE_SERVER_URL}${PATH_TO_ARCHIVE_TO_FETCH}"

set -u

setCurlTarget() {
  local target=${1:-'')}

  if [ -z "${target}" ]; then
    echo " -o /dev/null"
  else
    echo " -o ${target}"
  fi
}


curlRequest() {
  local url_to_archive=${1}
  local errorMsg=${2}
  local errorCode=${3}
  local target=${4:-''}

  set +e
  # shellcheck disable=SC2046,SC2155
  local http_code=$(curl --insecure -s -w "%{http_code}" "${url_to_archive}" $(setCurlTarget "${target}") )
  set -e
  if [ "${http_code}" -ne 200 ] ; then
    echo "${errorMsg}"
    exit "${errorCode}"
  fi
}

if [ -z "${PATH_TO_ARCHIVE_TO_FETCH}" ]; then
  echo "PATH_TO_ARCHIVE_TO_FETCH has not been provided, aborting."
  exit 1
fi

if [ -z "${PATH_TO_ARCHIVE_FILE}" ]; then
  echo "No PATH_TO_ARCHIVE_FILE provided."
  exit 2
fi

if [ -z "${MIDDLEWARE_DOWNLOAD_RELEASE_SERVER_URL}" ]; then
  echo "URL for product download server not set: ${MIDDLEWARE_DOWNLOAD_RELEASE_SERVER_URL}"
  exit 2
fi

echo -n "Check if ${URL_TO_ARCHIVE} is accessible..."
curlRequest "${URL_TO_ARCHIVE}" "Can't access product to download." 4
echo 'Done.'

echo -n "Download product into ${PATH_TO_ARCHIVE_FILE}..."
curlRequest "${URL_TO_ARCHIVE}" "Can't access product to download." 5 "${PATH_TO_ARCHIVE_FILE}"
echo 'Done.'
