#!/bin/sh
# Creates a sanitized config.plist.template from config.plist.
# Unlike the old sed-based version, this masks values by plist key (so it can
# never silently skip a value that changed since LocalSettings.txt was written)
# and it covers ALL unique identifiers: MLB, SystemSerialNumber, SystemUUID, ROM.

PB=/usr/libexec/PlistBuddy

if [ ! -f config.plist ]; then
    echo "Error: config.plist not found"
    exit 1
fi

cp config.plist config.plist.template

$PB -c "Set :PlatformInfo:Generic:MLB YourMLB"                                 config.plist.template || exit 1
$PB -c "Set :PlatformInfo:Generic:SystemSerialNumber YourSystemSerialNumber"   config.plist.template || exit 1
$PB -c "Set :PlatformInfo:Generic:SystemUUID YourSystemUUID"                   config.plist.template || exit 1
$PB -c "Set :PlatformInfo:Generic:ROM AAAAAA=="                                config.plist.template || exit 1

echo "config.plist.template created with placeholders (MLB, serial, UUID, ROM masked)."
