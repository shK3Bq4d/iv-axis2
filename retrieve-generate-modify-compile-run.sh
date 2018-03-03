#!/usr/bin/env bash
# ex: set filetype=sh :

set -euxo pipefail

# states where we are going to work and move to there
WORKDIR=~/tmp/test3
test -d "$WORKDIR" || mkdir -p "$WORKDIR"
cd "$WORKDIR"

# This will be our service name and refers to an existing example included
# in the axis2 .zip archive that I am going to dowload
SERVICE_NAME=Echo; VARIANT="12"
SERVICE_NAME=Ping; VARIANT=""
SERVICE_NAME=Ping; VARIANT="12"

# Intermediary package. Not very important in this example but parametrization
# likely to be of some use in future use
P=mr.sanfrancisco.test

# download and extract AXIS2
AXIS2_VERSION=1.7.7
AXIS2_DIR=$WORKDIR/axis2-${AXIS2_VERSION}/
AXIS2_ZIP_NAME=axis2-${AXIS2_VERSION}-bin.zip
if [[ ! -f $AXIS2_ZIP_NAME ]]; then
	wget http://mirror.easyname.ch/apache/axis/axis2/java/core/$AXIS2_VERSION/$AXIS2_ZIP_NAME
fi
[[ -e "$AXIS2_DIR" ]] && rm -rf "$AXIS2_DIR"
7za x $AXIS2_ZIP_NAME > 7x.output.log

# inputs
WSDL=$AXIS2_DIR/samples/jaxws-samples/src/webapp/WEB-INF/wsdl/${SERVICE_NAME}${VARIANT}.wsdl
WSDL2JAVA_OUT=$WORKDIR/o
JAVAC_OUT=$WORKDIR/${SERVICE_NAME}${VARIANT}
SRELOUT=S
RRELOUT=R
PATH=$AXIS2_DIR/bin:$PATH

# CD to same dir as currently running script
#DIR="$( cd -P "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"
#cd $DIR

# clean previous build
[[ -d $WSDL2JAVA_OUT ]] && rm -rf $WSDL2JAVA_OUT
[[ -d $JAVAC_OUT ]] && rm -rf $JAVAC_OUT

# generate service source file
wsdl2java.sh -o $WSDL2JAVA_OUT -s -ssi -p $P -ss -u -sd -S $SRELOUT -R $RRELOUT -uri $WSDL

# hard coded source code generation replacement of hard-coded "TODO : ..." text
JAVA_FILE=$WSDL2JAVA_OUT/$SRELOUT/${P//./\/}/${SERVICE_NAME}Service${VARIANT}Skeleton.java
if [[ -f  "$JAVA_FILE" ]]; then
	sed -r -i -e "$(echo "s,.*TODO : fill this with the necessary business logic,
		System.out.println(\"Coucou my friends. I was compiled on $(date)\");
			,
			" | tr -d '\n')" $JAVA_FILE
	cat $JAVA_FILE
else
	echo "No such file $JAVA_FILE. No source code auto-modification"
fi

# pre-package services.xml
mkdir -p $JAVAC_OUT/META-INF
#cp $WSDL2JAVA_OUT/$RRELOUT/services.xml $JAVAC_OUT/META-INF/
cp $WSDL2JAVA_OUT/$RRELOUT/* $JAVAC_OUT/META-INF/

# compile service
cd $WSDL2JAVA_OUT/$SRELOUT
find -name \*.java | xargs javac -cp ${AXIS2_DIR}/lib/\* -d $JAVAC_OUT

# run pre-packaged tomcat + axis2 with shared acces to $JAVAC_OUT and listening
# on port $HOST_PORT
#  - For pre-packaged tomcat +  axis2, ee https://hub.docker.com/r/ainehanta/axis2/ 
#    and https://hub.docker.com/r/ainehanta/axis2/ for details
#  - to retrieve deployed services, go to 
#    http://localhost:$HOST_PORT/axis2/services/listServices
HOST_PORT=9999
docker run \
	-p $HOST_PORT:8080 \
	-v $JAVAC_OUT:/usr/local/tomcat/webapps/axis2/WEB-INF/services/${SERVICE_NAME}${VARIANT} \
	ainehanta/axis2

exit 0
