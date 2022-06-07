from mvlocscript.potools import readpo, writepo
from mvlocscript.fstools import glob_posix as glob
from pathlib import Path

REPLACE_MAP = {
    'Check the storage.': 'Das Lager überprüfen.',
}

for path in glob('locale/**/de.po'):
    dict_original, _, sourcelocation = readpo(Path(path).parent / 'en.po')
    dict_translated, _, _ = readpo(path)

    changed = False

    for key in list(dict_translated):
        entry_translated = dict_translated[key]
        if entry_translated.obsolete:
            continue
        entry_original = dict_original[key]

        target = REPLACE_MAP.get(entry_original.value, None)
        if target is None:
            continue
        dict_translated[key] = entry_translated._replace(value=target)
        changed = True

    if changed:
        writepo(path, dict_translated.values(), sourcelocation)
