#!/bin/sh
# Regenerates config.plist from config.plist.template, injecting the personal
# SMBIOS values stored in LocalSettings.txt (git-ignored).
#
# LocalSettings.txt must now contain ALL FOUR unique identifiers (GenSMBIOS
# generates them together; ROM may be given as 12 hex chars or as base64):
#   MLB=C02xxxxxxxxxxx
#   SystemSerialNumber=xxxxxxxxxx
#   SystemUUID=00000000-0000-0000-0000-000000000000
#   ROM=049226BDC366

PB=/usr/libexec/PlistBuddy

if [ ! -f config.plist.template ] || [ ! -f LocalSettings.txt ]; then
    echo "Error: config.plist.template and LocalSettings.txt are both required"
    exit 1
fi

while read line; do
    case "$line" in
        ''|\#*) continue ;;
    esac
    export "$line"
done < LocalSettings.txt

for var in MLB SystemSerialNumber SystemUUID ROM; do
    eval "val=\$$var"
    if [ -z "$val" ]; then
        echo "Error: $var is missing from LocalSettings.txt (see header of this script)"
        exit 1
    fi
done

# Accept ROM as 12 hex chars (GenSMBIOS style) and convert to base64,
# otherwise assume it is already base64.
ROM_STRIPPED=$(printf '%s' "$ROM" | tr -d '0-9A-Fa-f')
if [ ${#ROM} -eq 12 ] && [ -z "$ROM_STRIPPED" ]; then
    ROM=$(printf '%s' "$ROM" | xxd -r -p | base64 | tr -d '\n')
fi

cp config.plist.template config.plist || exit 1

$PB -c "Set :PlatformInfo:Generic:MLB $MLB"                             config.plist || exit 1
$PB -c "Set :PlatformInfo:Generic:SystemSerialNumber $SystemSerialNumber" config.plist || exit 1
$PB -c "Set :PlatformInfo:Generic:SystemUUID $SystemUUID"               config.plist || exit 1
$PB -c "Set :PlatformInfo:Generic:ROM $ROM"                             config.plist || exit 1

echo "config.plist generated from template with your SMBIOS values."
