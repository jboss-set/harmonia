CLI=/home/jboss/alignment-cli-0.3-SNAPSHOT.jar
CONFIG=/home/jboss/wildfly-18-alignment-config.json

ls -l $CLI
cat $CONFIG

java -jar $CLI generate-prs -c $CONFIG -f wildfly/pom.xml

