#!/bin/sh

cd /Volumes/EFI/EFI/OC
/Volumes/EFI/Utilities/CreateVault/create_vault.sh .
/Volumes/EFI/Utilities/CreateVault/RsaTool -sign vault.plist vault.sig vault.pub
export off=$(($(strings -a -t d OpenCore.efi | grep "=BEGIN OC VAULT=" | cut -f1 -d' ')+16))
dd of=OpenCore.efi if=vault.pub bs=1 seek=$off count=528 conv=notrunc
rm vault.pub
