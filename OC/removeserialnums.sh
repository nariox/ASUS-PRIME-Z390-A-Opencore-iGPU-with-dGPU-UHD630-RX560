#!/bin/sh
# Creates a sanitized config.plist.template from config.plist.
#
# Masking works by plist KEY POSITION (never by matching values from
# LocalSettings.txt), so a value that drifted from LocalSettings can never
# silently slip through -- that was the bug that leaked the original
# identifiers. Covers all four unique identifiers: MLB, SystemSerialNumber,
# SystemUUID, ROM.
#
# Plain XML editing, deliberately NOT PlistBuddy: its <data> handling
# corrupted ROM on a real run (double base64 -> "OCS: Failed to parse data
# field ... context <ROM>"). The script validates the result and fails loudly.
set -e

if [ ! -f config.plist ]; then
    echo "Error: config.plist not found"
    exit 1
fi

python3 - <<'PY'
import base64, plistlib, re, sys

s = open('config.plist').read()

def mask_key(s, key, tag, repl):
    pat = re.compile(r'(<key>%s</key>\s*<%s>)[^<]*(</%s>)' % (key, tag, tag))
    n = len(pat.findall(s))
    if n != 1:
        sys.exit('Error: expected exactly 1 <key>%s</key> <%s> value, found %d'
                 ' -- aborting without writing anything' % (key, tag, n))
    return pat.sub(lambda m: m.group(1) + repl + m.group(2), s)

s = mask_key(s, 'MLB', 'string', 'YourMLB')
s = mask_key(s, 'SystemSerialNumber', 'string', 'YourSystemSerialNumber')
s = mask_key(s, 'SystemUUID', 'string', 'YourSystemUUID')
s = mask_key(s, 'ROM', 'data', 'AAAAAA==')
open('config.plist.template', 'w').write(s)
print('config.plist.template written (MLB, serial, UUID, ROM masked).')

# Safety net: both plists must parse, and no real identifier may appear
# ANYWHERE in the template text (not just under its key).
cfg = plistlib.load(open('config.plist', 'rb'))['PlatformInfo']['Generic']
tpl = plistlib.load(open('config.plist.template', 'rb'))['PlatformInfo']['Generic']

for key, want in (
        ('MLB', 'YourMLB'),
        ('SystemSerialNumber', 'YourSystemSerialNumber'),
        ('SystemUUID', 'YourSystemUUID')):
    if tpl[key] != want:
        sys.exit('Error: template %s is not the placeholder (masked value %r)'
                 % (key, tpl[key]))
    if cfg[key] == want:
        sys.exit('Error: config.plist %s already looks masked -- refusing '
                 '(would hide a real leak)' % key)

rom_b64 = base64.b64encode(bytes(cfg['ROM'])).decode()
rom_hex = bytes(cfg['ROM']).hex()
for needle in (cfg['MLB'], cfg['SystemSerialNumber'],
               str(cfg['SystemUUID']), str(cfg['SystemUUID']).lower(),
               rom_b64, rom_hex, rom_hex.upper()):
    if needle in s:
        sys.exit('Error: identifier literal %r still present in template text!'
                 % needle)

print('template validated: all four identifiers masked, plist parses, '
      'no identifier literals anywhere in the file.')
PY
