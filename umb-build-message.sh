#!/bin/bash

readonly REQUIRED_VARS=(SERVER_URL BUILD_ID BUILD_URL SCM_URL SCM_REVISION RELEASE_NAME RELEASE_STREAM RELEASE_TYPE VERSION BASE_VERSION)

if ! command -v jq &> /dev/null
then
    echo "jq could not be found"
    exit 1
fi

MISSING_VARS=""
for var in "${REQUIRED_VARS[@]}"
do
  if [ -z "${!var}" ]; then
    if [ -n "${MISSING_VARS}" ]; then
      MISSING_VARS="${MISSING_VARS} ${var}"
    else
      MISSING_VARS="${var}"
    fi
  fi
done

if [ -n "${MISSING_VARS}" ]; then
  echo "Required properties are not found: ${MISSING_VARS}"
  exit 2
fi

server=$( jq -n '{ server: $ARGS.named }' \
      --arg url "${SERVER_URL}" \
      --arg build-type "jenkins" \
      --arg build-id "${BUILD_ID}" \
      --arg build-url "${BUILD_URL}" \
      --arg scm-type: "git" \
      --arg scm-url: "${SCM_URL}" \
      --arg scm-revision: "${SCM_REVISION}" )
 
sources=$( jq -n '{ "server-name": $ARGS.named }' \
      --arg url "${SOURCE_URL}" \
      --arg build-type "jenkins" \
      --arg build-id "${BUILD_ID}" \
      --arg build-url "${BUILD_URL}" \
      --arg scm-type: "git" \
      --arg scm-url: "${SCM_URL}" \
      --arg scm-revision: "${SCM_REVISION}" )

server=$( echo "${server}" | jq '.server' )
sources=$( echo "${sources}" | jq '."server-name"' )

bits=$( jq -n '{bits: $ARGS.named}' \
  --argjson server "$server" --argjson server-sources "$sources" )
bits=$( echo "${bits}" | jq '.bits' )

msg=$( jq -n '{release: $ARGS.named}' \
  --arg name "$RELEASE_NAME" \
  --arg stream "$RELEASE_STREAM" \
  --arg type "$RELEASE_TYPE" \
  --arg version "$VERSION" \
  --arg target-version "$BASE_VERSION" \
  --arg eap-base-version "$BASE_VERSION" \
  --arg url "$BUILD_URL" \
  --argjson bits "$bits" )

echo "${msg}" | jq > message_body.json

echo "MESSAGE_CONTENT=${msg}" >> MESSAGE.txt

cat message_body.json