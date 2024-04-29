import re
from glob import glob
from pathlib import Path
import json5
import json
from makeMTjson import makeMT

#This is an outdated script. File format was changed from 5.4.4 to 5.4.5 for MT json. You cant use this script for updating MT json from 5.4.5 to newer version.

_MACHINE_FN_PATTERN = re.compile(
    r'^machine-(?P<locale>[a-zA-Z_]+)-(?P<version>v?[0-9\.]+(?:-.*)?)\.json$',
    re.IGNORECASE
)

with open('mvloc.config.jsonc') as f:
    config = json5.load(f)
    
base_version = config['packaging']['version']

for pathstr in glob("machine-json/*"):
    path = Path(pathstr).name
    match = _MACHINE_FN_PATTERN.match(path)
    if match is None:
        continue
    match = match.groupdict()
    locale = match['locale']
    version = match['version']
    if version == base_version:
        print(f'locale: {locale} is up-to-date.')
        continue
    print(f'making machine-{locale}-{base_version}.json')
    makeMT(locale, base_version)
    print(f'updating {locale}...')
    with open(f'machine-json/machine-{locale}-{version}.json') as f:
        old_json = json.load(f)
    with open(f'machine-json/machine-{locale}-{base_version}.json') as f:
        new_json = json.load(f)
    for old_text_dict in old_json['translation']:
        new_text = new_json['translation'].get(old_text_dict['original'], None)
        if new_text is None:
            continue
        new_text['deepl'] = old_text_dict['deepl']
        new_text['machine'] = old_text_dict['machine']
    with open(f'machine-json/machine-{locale}-{base_version}.json', 'wt') as f:
        json.dump(new_json, f)