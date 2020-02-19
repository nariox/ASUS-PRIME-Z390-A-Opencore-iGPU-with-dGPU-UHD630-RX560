#!/bin/sh

while read line; do    
    if [[ $(echo $line | cut -d'=' -f1) == "SystemSerialNumber" ]]; then
        export $line
    fi
    if [[ $(echo $line | cut -d'=' -f1) == "SystemUUID" ]]; then
        export $line
    fi
done < LocalSettings.txt

sed -i "s/YourSystemSerialNumber/$SystemSerialNumber/g" config.plist
sed -i "s/YourSystemUUID/$SystemUUID/g" config.plist
