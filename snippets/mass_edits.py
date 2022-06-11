from collections import defaultdict
from mvlocscript.potools import readpo, writepo
from mvlocscript.fstools import glob_posix as glob
from pathlib import Path

def _shorten(obj):
    ret = repr(obj)
    if len(ret) > 40:
        ret = ret[:37] + '...'
    return ret

def mass_translate(glob_pattern, replace_map, overwrite):
    stats_new = defaultdict(int)
    stats_mismatch = defaultdict(int)
    stats_match = defaultdict(int)
    
    for path in glob(glob_pattern):
        dict_original, _, sourcelocation = readpo(Path(path).parent / 'en.po')
        dict_translated, _, _ = readpo(path)

        changed = False

        for key in list(dict_translated):
            entry_translated = dict_translated[key]
            if entry_translated.obsolete:
                continue
            entry_original = dict_original[key]

            target = replace_map.get(entry_original.value, None)
            if target is None:
                continue

            if entry_translated.value == '':
                stats_new[entry_original.value] += 1
            elif entry_translated.value == target:
                stats_match[entry_original.value] += 1
                continue
            else:
                stats_mismatch[entry_original.value] += 1
                if not overwrite:
                    continue

            dict_translated[key] = entry_translated._replace(value=target)
            changed = True

        if changed:
            writepo(path, dict_translated.values(), sourcelocation)

    for key in replace_map:
        print(
            '{:<40} | {} new, {} {}, {} match (skipped)'.format(
                _shorten(key),
                stats_new[key],
                stats_mismatch[key],
                'overwritten' if overwrite else 'mismatch (skipped)',
                stats_match[key]
            )
        )
