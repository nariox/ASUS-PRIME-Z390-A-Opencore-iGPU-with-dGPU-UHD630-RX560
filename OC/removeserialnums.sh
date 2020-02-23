#!/bin/sh

while read line; do    
    if [[ $(echo $line | cut -d'=' -f1) == "SystemSerialNumber" ]]; then
        export $line
    fi
    if [[ $(echo $line | cut -d'=' -f1) == "SystemUUID" ]]; then
        export $line
    fi
done < LocalSettings.txt

rm -f config.plist.template
cp config.plist config.plist.template

sed -i'.orig' "s/$SystemSerialNumber/YourSystemSerialNumber/g" config.plist.template
sed -i'.orig' "s/$SystemUUID/YourSystemUUID/g" config.plist.template

rm config.plist.template.orig
