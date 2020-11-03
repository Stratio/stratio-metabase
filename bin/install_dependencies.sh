#!/usr/bin/env sh
mvn package -f ./local-query-execution-factory/pom.xml
cp ./local-query-execution-factory/target/local-query-execution-factory-0.2.jar ./bin/lib/local-query-execution-factory-0.2.jar
mvn install:install-file -Dfile=./bin/lib/local-query-execution-factory-0.2.jar -DgroupId=com.stratio.metabase -DartifactId=local-query-execution-factory -Dversion=0.2 -Dpackaging=jar

crossdata_version=2.19.0-809dcaf

mvn dependency:copy -Dartifact=com.stratio.crossdata.driver:stratio-crossdata-jdbc4:${crossdata_version} -DoutputDirectory=./bin/lib/
mvn install:install-file -Dfile=./bin/lib/stratio-crossdata-jdbc4-${crossdata_version}.jar -DgroupId=com.stratio.crossdata.driver -DartifactId=stratio-crossdata-jdbc4 -Dversion=${crossdata_version} -Dpackaging=jar
