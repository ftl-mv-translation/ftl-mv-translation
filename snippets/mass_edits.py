from collections import defaultdict
from mvlocscript.potools import readpo, writepo
from mvlocscript.fstools import glob_posix as glob
from pathlib import Path

MASS_MAP_IGNORE_AND_DONT_STAT = 0
MASS_MAP_IGNORE_BUT_STAT = 1

def _shorten(obj):
    ret = repr(obj)
    if len(ret) > 40:
        ret = ret[:37] + '...'
    return ret

def mass_map(glob_pattern, mapfunc, overwrite):
    stats_new = defaultdict(int)
    stats_mismatch = defaultdict(int)
    stats_match = defaultdict(int)
    stats_subject = set()
    
    for path in glob(glob_pattern):
        dict_original, _, sourcelocation = readpo(Path(path).parent / 'en.po')
        dict_translated, _, _ = readpo(path)

        changed = False

        for key in list(dict_translated):
            entry_translated = dict_translated[key]
            if entry_translated.obsolete:
                continue
            entry_original = dict_original[key]

            target = mapfunc(entry_original, entry_translated)
            if (target is None) or (target == MASS_MAP_IGNORE_AND_DONT_STAT):
                continue
            elif target == MASS_MAP_IGNORE_BUT_STAT:
                stats_subject.add(entry_original.value)
                continue
            else:
                stats_subject.add(entry_original.value)

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

    for key in sorted(stats_subject):
        print(
            '{:<40} | {} new, {} {}, {} match (skipped)'.format(
                _shorten(key),
                stats_new[key],
                stats_mismatch[key],
                'overwritten' if overwrite else 'mismatch (skipped)',
                stats_match[key]
            )
        )

def mass_translate(glob_pattern, replace_map, overwrite):
    def mapfunc(entry_original, entry_translated):
        return replace_map.get(entry_original.value, MASS_MAP_IGNORE_AND_DONT_STAT)
    
    mass_map(glob_pattern, mapfunc, overwrite)
    