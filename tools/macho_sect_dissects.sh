#!/bin/sh

# macho_sect_dissects.sh: split and delete macho  sects
# 
# Created by Massimo Chiodini on 13/05/2013
# Copyright (C) HT srl 2013. All rights reserved
# 
#  Note: output file name display the offset range of
#  string not deleted in the  section 
#  from input macho file
#

OPT=$1
FILE=$2

if [ -z $OPT ]
then 
	echo "  usage: $0 -t|-s <macho file i386>"
	exit 0
fi

if [ $OPT == "-t" ]
then
	SECT="__text"
fi

if [ $OPT == "-s" ]
then
	SECT="__cstring"
fi

echo trying to disect section $SECT on $FILE

HEX_OFFSET=`echo $FILE | sed -n 's/.*--//p' | sed -n 's/++.*//p'`
HEX_END=`echo $FILE | sed -n 's/.*++//p'`

OFFSET=`printf "%d" $HEX_OFFSET`
END=`printf "%d" $HEX_END`

let "SIZE = END - OFFSET"

# echo OFFSET = $OFFSET END = $END SIZE = $SIZE

if [ $OFFSET == "0" ]
then
	#echo "otool -l $FILE | grep $SECT -A 5 | sed -n 's/offset //p'"
	TMP_OFFSET=`otool -l $FILE | grep $SECT -A 5 | sed -n 's/offset //p'`

	OFFSET=`printf "%d" $TMP_OFFSET`

	#echo "otool -l $FILE | grep $SECT -A 5 | sed -n 's/size //p'"
	HEX_SIZE=`otool -l $FILE | grep $SECT -A 5 | sed -n 's/size //p'`

	SIZE=`printf "%d" $HEX_SIZE`

	let "BEGIN_A = $OFFSET + 4096"

	FILE_NAME=$FILE
else
	FILE_NAME=`echo $2| sed -n 's/--.*//p'`

	let "BEGIN_A = $OFFSET"
fi

echo filename = $2 offset = $OFFSET size = $SIZE

let "HALF_SIZE = $SIZE / 2"
let "END_A = $BEGIN_A + $HALF_SIZE"
let "BEGIN_B = $END_A + 1"
let "END_B = $END_A + $HALF_SIZE"

HEX_BEGIN_A=`printf "0x%X" $BEGIN_A`
HEX_END_A=`printf "0x%X" $END_A`
HEX_BEGIN_B=`printf "0x%X" $BEGIN_B`
HEX_END_B=`printf "0x%X" $END_B`

DISSECTED_FILE_A=$FILE_NAME--$HEX_BEGIN_A++$HEX_END_A
DISSECTED_FILE_B=$FILE_NAME--$HEX_BEGIN_B++$HEX_END_B

echo dissected file 1 = $DISSECTED_FILE_A 

cp $FILE $DISSECTED_FILE_A
# echo dd if=/dev/zero of=$DISSECTED_FILE_A bs=1 oseek=$BEGIN_B count=$HALF_SIZE conv=notrunc
dd if=/dev/zero of=$DISSECTED_FILE_A bs=1 seek=$BEGIN_B count=$HALF_SIZE conv=notrunc > /dev/null 2>&1

echo dissected file 2 = $DISSECTED_FILE_B 

cp $FILE $DISSECTED_FILE_B
# echo dd if=/dev/zero of=$DISSECTED_FILE_B bs=1 oseek=$BEGIN_A count=$HALF_SIZE conv=notrunc
dd if=/dev/zero of=$DISSECTED_FILE_B bs=1 seek=$BEGIN_A count=$HALF_SIZE conv=notrunc > /dev/null 2>&1
