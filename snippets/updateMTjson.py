import re
from glob import glob
from pathlib import Path
import json5
import json
from makeMTjson import makeMT


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
    with open(pathstr) as f:
        old_json = json.load(f)
    with open(f'machine-json/machine-{locale}-{base_version}.json') as f:
        new_json = json.load(f)

    for key, new_text_dict in new_json['translation'].items():
        new_text_dict = old_json['translation'].get(key, {'deepl': '', 'machine': ''})

    Path(pathstr).unlink()

    with open(f'machine-json/machine-{locale}-{base_version}.json', 'wt') as f:
        json.dump(new_json, f)