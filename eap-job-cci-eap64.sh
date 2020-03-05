# Allow to override the following values:
readonly EAP_LOCAL_MAVEN_REPO_FOLDER=${EAP_LOCAL_MAVEN_REPO_FOLDER:-eap-maven-local-repository}
readonly EAP_LOCAL_MAVEN_REPO=${EAP_LOCAL_MAVEN_REPO:-${WORKSPACE}/${EAP_LOCAL_MAVEN_REPO_FOLDER}}
readonly MEMORY_SETTINGS=${MEMORY_SETTINGS:-'-Xmx1024m -Xms512m -XX:MaxPermSize=256m'}
readonly SRC_LOCATION_FOLDER=${SRC_LOCATION_FOLDER:-eap-sources}
readonly SRC_LOCATION=${SRC_LOCATION:-${WORKSPACE}/${SRC_LOCATION_FOLDER}}

# and will reuse MAVEN_OPTS and TESTSUITE_OPTS if defined.
mkdir -p "${EAP_LOCAL_MAVEN_REPO}"
export MAVEN_OPTS="${MAVEN_OPTS} ${MEMORY_SETTINGS}"
export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.repo.local=${EAP_LOCAL_MAVEN_REPO}"

# Remove home variable
unset JBOSS_HOME

cd ${SRC_LOCATION}
echo "Starting build..."
./build.sh clean install -fae -B -DskipTests -Dts.noSmoke -DallTests -Prelease

# Adjust Surefire memory settings (due to failures in JDK6)
echo "Adjusted memory settings"
sed -i 's/-Duser.language=en<\/argLine>/-Duser.language=en -XX:MaxPermSize=256m<\/argLine>/g' pom.xml

echo "Finished build"
cd ${WORKSPACE}

# Make all artifacts
# Maven artifacts
zip -qr jboss-eap-6.4-maven-artifacts.zip ${EAP_LOCAL_MAVEN_REPO_FOLDER}

# Server and sources
echo "Copying distribution artifacts to workspace"
#mv -v ${SRC_LOCATION}/dist/target/jboss-eap-6.4.zip ${WORKSPACE}/
#mv -v ${SRC_LOCATION}/dist/target/jboss-eap-6.4-src.zip ${WORKSPACE}/
zip -qr jboss-eap-6.4-src-prepared.zip ${SRC_LOCATION_FOLDER}
