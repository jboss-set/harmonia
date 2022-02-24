#!/bin/bash
set -eo pipefail

readonly GALAXY_YML='galaxy.yml'
readonly UPSTREAM_NS='middleware_automation'
readonly DOWNSTREAM_NS='redhat'
readonly PROJECT_DOWNSTREAM_NAME="${PROJECT_DOWNSTREAM_NAME}"
readonly DEFAULT_UPSTREAM_GIT_BRANCH='main'
readonly -A UPSTREAM_TO_DOWNSTREAM_NAMES
UPSTREAM_TO_DOWNSTREAM_NAMES["${UPSTREAM_NS}.wildfly"]='redhat.jboss_eap'
UPSTREAM_TO_DOWNSTREAM_NAMES["${UPSTREAM_NS}.infinispan"]='redhat.jboss_data_grid'
UPSTREAM_TO_DOWNSTREAM_NAMES["${UPSTREAM_NS}.keycloak"]='redhat.rh_sso'

echo GIT_REPOSITORY_URL: "${GIT_REPOSITORY_URL}"
echo GIT_REPOSITORY_BRANCH: "${GIT_REPOSITORY_BRANCH}"
echo WORKDIR: "${WORKDIR}"
echo VERSION: "${VERSION}"

echo "Building project from ${GIT_REPOSITORY_URL} inside ${WORKDIR}."
cd "${WORKDIR}"
if [ -n "${GIT_REPOSITORY_URL}" ]; then
  echo "Syncronizing with upstream ${GIT_REPOSITORY_URL} repository..."
  git remote add upstream "${GIT_REPOSITORY_URL}"
  git pull --rebase upstream "${DEFAULT_UPSTREAM_GIT_BRANCH}"
  echo 'Done.'
fi

echo "Rename dependencies to ${UPSTREAM_NS} to ${UPSTREAM_NS} that have different downstream project name"
for key in "${!UPSTREAM_TO_DOWNSTREAM_NAMES[@]}"
do
  value=${UPSTREAM_TO_DOWNSTREAM_NAMES[${key}]}
  echo -n "Replace dependency to ${key} by ${value} (if any)..."
  sed -i "${GALAXY_YML}" -e "s/${key}/${value}/g"
  echo 'Done'
done

echo -n "Change collection namespace from ${UPSTREAM_NS} to ${DOWNSTREAM_NS}..."
grep -e "${UPSTREAM_NS}" -r . | cut -f1 -d: | sort -u | \
while
  read -r file_to_edit
do
  echo -n "Editing ${file_to_edit}..."
  sed -i "${file_to_edit}" \
      -e "s/${UPSTREAM_NS}/${DOWNSTREAM_NS}/"
   echo 'Done.'
done

if [ "${PROJECT_DOWNSTREAM_NAME}" != "" ]; then
  echo "Change collection name to ${PROJECT_DOWNSTREAM_NAME}..."
  sed -i "${GALAXY_YML}" -e "s/\(^name: \).*$/\1${PROJECT_DOWNSTREAM_NAME}/"
  echo 'Done.'
fi

if [ -n "${VERSION}" ]; then
  readonly TAG="${VERSION}-${DOWNSTREAM_NS}"
  echo -n "Bump version to ${TAG}..."
  sed -i "${GALAXY_YML}" \
      -e "s/^\(version: \).*$/\1\"${TAG}\"/"
  echo 'Done.'
fi

echo 'Display changes performed on code base:'
git --no-pager diff --no-color -w .
echo 'Done'

echo 'Build collection:'
ansible-galaxy collection build .
echo 'Done.'

if [ -n "${VERSION}" ]; then
  echo "Tagging release ${TAG}"
  git tag "${TAG}"
  git commit -m "Release ${TAG}-${DOWNSTREAM_NS}" -a
  echo "Create branch"
  if [ -z "${GIT_REPOSITORY_BRANCH}" ]; then
    echo "No GIT_REPOSITORY_BRANCH provided, abort."
    exit 1
  fi
  git push origin "${GIT_REPOSITORY_BRANCH}:${TAG}"
fi
