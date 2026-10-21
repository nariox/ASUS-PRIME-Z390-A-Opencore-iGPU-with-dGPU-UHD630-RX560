#!/bin/sh
# Regenerates config.plist from config.plist.template, injecting the personal
# SMBIOS values stored in LocalSettings.txt (git-ignored).
#
# LocalSettings.txt must contain ALL FOUR unique identifiers (GenSMBIOS
# generates MLB + serial + UUID together; ROM is your MAC address as 12 hex
# chars, or already base64):
#   MLB=C02xxxxxxxxxxx
#   SystemSerialNumber=xxxxxxxxxx
#   SystemUUID=00000000-0000-0000-0000-000000000000
#   ROM=049226BDC366
#
# Values are substituted BY PLIST KEY, never by matching placeholder text:
# e.g. the ROM placeholder <data>AAAAAA==</data> is byte-identical to the
# unrelated DefaultBackgroundColor data value, so text matching would corrupt
# it. Substitution is plain XML editing, deliberately NOT PlistBuddy: its
# <data> handling for Set corrupted ROM on a real run (double base64, rejected
# by OpenCore: "OCS: Failed to parse data field ... context <ROM>").
# The script validates the result and fails loudly.
set -e

if [ ! -f config.plist.template ] || [ ! -f LocalSettings.txt ]; then
    echo "Error: config.plist.template and LocalSettings.txt are both required"
    exit 1
fi

python3 - <<'PY'
import base64, binascii, plistlib, re, sys

vals = {}
for line in open('LocalSettings.txt'):
    line = line.strip()
    if not line or line.startswith('#') or '=' not in line:
        continue
    k, v = line.split('=', 1)
    vals[k.strip()] = v.strip()

missing = [k for k in ('MLB', 'SystemSerialNumber', 'SystemUUID', 'ROM') if not vals.get(k)]
if missing:
    sys.exit('Error: missing from LocalSettings.txt: ' + ', '.join(missing)
             + '  (see header of this script for the format)')

rom = vals['ROM'].replace(':', '').replace('-', '').replace(' ', '')
try:
    rom_bytes = binascii.unhexlify(rom)
    if len(rom_bytes) != 6:
        raise binascii.Error
except binascii.Error:
    try:
        rom_bytes = base64.b64decode(vals['ROM'].strip(), validate=True)
    except binascii.Error:
        sys.exit('Error: ROM must be 12 hex chars or base64, got: ' + vals['ROM'])

s = open('config.plist.template').read()

def set_key(s, key, tag, repl):
    pat = re.compile(r'(<key>%s</key>\s*<%s>)[^<]*(</%s>)' % (key, tag, tag))
    n = len(pat.findall(s))
    if n != 1:
        sys.exit('Error: expected exactly 1 <key>%s</key> <%s> in template, '
                 'found %d -- aborting' % (key, tag, n))
    return pat.sub(lambda m: m.group(1) + repl + m.group(2), s)

s = set_key(s, 'MLB', 'string', vals['MLB'])
s = set_key(s, 'SystemSerialNumber', 'string', vals['SystemSerialNumber'])
s = set_key(s, 'SystemUUID', 'string', vals['SystemUUID'])
s = set_key(s, 'ROM', 'data', base64.b64encode(rom_bytes).decode())
open('config.plist', 'w').write(s)
print('config.plist generated from template.')

# Validation: plist parses AND every injected value round-trips correctly.
g = plistlib.load(open('config.plist', 'rb'))['PlatformInfo']['Generic']
assert g['MLB'] == vals['MLB'], 'MLB round-trip failed'
assert g['SystemSerialNumber'] == vals['SystemSerialNumber'], 'serial round-trip failed'
assert str(g['SystemUUID']).upper() == vals['SystemUUID'].upper(), 'UUID round-trip failed'
assert bytes(g['ROM']) == rom_bytes, (
    'ROM round-trip failed: config has %s, expected %s'
    % (bytes(g['ROM']).hex(), rom_bytes.hex()))
print('config.plist valid: all four identifiers round-trip OK (ROM = %s)'
      % bytes(g['ROM']).hex().upper())
PY
