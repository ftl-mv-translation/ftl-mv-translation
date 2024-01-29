from collections import defaultdict
from mvlocscript.potools import readpo, writepo, parsekey
from mvlocscript.fstools import glob_posix as glob
from pathlib import Path

def main():
    def parsekey_to_restore(k):
        idx = k.find('|')
        return k[:idx], k[idx + 1:]
    to_restore = open('to_restore.txt', 'r').read().strip().split('\n')
    to_restore = [parsekey_to_restore(k) for k in to_restore]
    glob_current = "locale/**/*.po"
    
    # find entries that are both empty in current and broken, yet nonempty in fixed
    for current_path in glob(glob_current):
        if current_path.endswith('en.po'):
            continue
        fixed_path = current_path.replace('locale', 'locale-fixed-secondpass')

        dict_current, _, sourcelocation = readpo(current_path)
        dict_fixed, _, _ = readpo(fixed_path)

        for fn, key in to_restore:
            path, _ = parsekey(key)
            path = path[:-1]

            if Path('locale') / path / fn == Path(current_path):
                dict_current[key] = dict_current[key]._replace(
                    value = dict_fixed[key].value,
                    fuzzy = dict_current[key].fuzzy or dict_fixed[key].fuzzy
                )
                print(key)

        writepo(current_path, dict_current.values(), sourcelocation)

main()