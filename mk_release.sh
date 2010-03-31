#!/bin/bash

# Create a release file for SnoGE
# It's simple, dirty, and works for me.

# Leon Ward - leon@rm-rf.co.uk

TARPATH=..
FILES="snoge INSTALL README example.csv snoge.conf unified-example.conf"
VERFILES="snoge"

echo Checking version numbers in code...
for i in $VERFILES
do
	VER=$(grep snogeversion $i |awk -F = '{print $2}')
	echo -e " $VER - $i"
done	

VER=$(grep snogeversion snoge |awk -F = '{print $2}'| sed s/\;//g)
TARGET="$TARPATH/snoge-$VER"
FILENAME="snoge-$VER.tgz"
echo -e "* Build Version $VER in $TARPATH ? (ENTER = yes)"

read 

if [ -d $TARGET ]
then
	echo Error $TARGET exists
	exit 1
else
	echo Creating $TARGET
	mkdir $TARGET

	for i in $FILES
	do
		echo -e "- Adding $i to $TARGET"
		cp $i $TARGET
	done
		cd $TARPATH
		tar -czf $FILENAME snoge-$VER
	 	cd -	
fi

echo "Created $TARPATH/$FILENAME"
