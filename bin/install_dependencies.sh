#!/usr/bin/env sh
mvn install:install-file -Dfile=./bin/lib/stratio-crossdata-jdbc4-2.11.1.jar -DgroupId=com.stratio.jdbc -DartifactId=stratio-crossdata-jdbc4 -Dversion=2.11.1 -Dpackaging=jar
