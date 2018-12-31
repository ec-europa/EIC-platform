#!/bin/bash
# Synopsis  : ./install_fop-1.1.sh /path/to/exist_home

if [ -z "$1" ]; then
        echo "Use: ./install_fop-1.1.sh /path/to/exist_home"
        exit 1
fi
if [ -z "$EXIST_HOME" ]; then
        EXIST_HOME=$1
fi


sed -i '/<builtin-modules>/a <module uri="http://exist-db.org/xquery/xslfo" class="org.exist.xquery.modules.xslfo.XSLFOModule"/> ' $EXIST_HOME/conf.xml
echo "> XSL-FO module enabled in eXist-DB"

EXTENSIONS=$EXIST_HOME/extensions
sed -e "s/include.module.xslfo = false/include.module.xslfo = true/" $EXTENSIONS/build.properties > $EXTENSIONS/build.properties.temp
diff=$(diff $EXTENSIONS/build.properties $EXTENSIONS/build.properties.temp | wc -l)
if [[ $diff > 0 ]]; then
	echo "> Including XSL-FO module"
	mv $EXTENSIONS/build.properties.temp $EXTENSIONS/build.properties
else	
	echo "> XSL-FO module already included"
	rm $EXTENSIONS/build.properties.temp
fi

cd $EXIST_HOME/extensions/modules
if [ -e "fop-1.1-bin.zip" ]; then
	echo "> fop-1.1-bin.zip already exists"
else
	wget "http://apache.crihan.fr/dist/xmlgraphics/fop/binaries/fop-1.1-bin.zip"
fi
if [ -e "fop-pdf-images-2.1.0.SNAPSHOT-bin.tar.gz" ]; then
	echo "> fop-pdf-images-2.1.0.SNAPSHOT-bin.tar.gz already exists"
else
	wget "https://dist.apache.org/repos/dist/dev/xmlgraphics/binaries/fop-pdf-images-2.1.0.SNAPSHOT-bin.tar.gz"
fi

rm -rf $EXIST_HOME/lib/user/fop-1.1
unzip "fop-1.1-bin.zip" -d $EXIST_HOME/lib/user/
echo "> Unzipped into "$EXIST_HOME/lib/user/
LIB_USER=$EXIST_HOME/lib/user
mv $LIB_USER/fop-1.1/build/fop.jar $LIB_USER
mv $LIB_USER/fop-1.1/lib/batik-all-*.jar $LIB_USER
mv $LIB_USER/fop-1.1/lib/xmlgraphics-commons-*.jar $LIB_USER
mv $LIB_USER/fop-1.1/lib/avalon-*.jar $LIB_USER
rm fop-1.1-bin.zip

rm -rf $EXIST_HOME/lib/user/fop-pdf-images-2.1.0.SNAPSHOT
tar -xvf "fop-pdf-images-2.1.0.SNAPSHOT-bin.tar.gz" -C $EXIST_HOME/lib/user/
echo "> Unzipped into "$LIB_USER
mv $LIB_USER/fop-pdf-images-2.1.0.SNAPSHOT/*.jar $LIB_USER
rm fop-pdf-images-2.1.0.SNAPSHOT-bin.tar.gz

echo "> Jar's moved into "$LIB_USER
mkdir $EXIST_HOME/build/classes
cd ../../
./build.sh extension-modules


