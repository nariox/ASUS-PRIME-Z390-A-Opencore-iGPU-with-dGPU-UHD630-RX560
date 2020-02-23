#!/bin/sh

while read line; do    
    if [[ $(echo $line | cut -d'=' -f1) == "SystemSerialNumber" ]]; then
        export $line
    fi
    if [[ $(echo $line | cut -d'=' -f1) == "SystemUUID" ]]; then
        export $line
    fi
done < LocalSettings.txt

cp config.plist.template config.plist

sed -i'.orig'  "s/YourSystemSerialNumber/$SystemSerialNumber/g" config.plist
sed -i'.orig' "s/YourSystemUUID/$SystemUUID/g" config.plist

rm config.plist.orig
