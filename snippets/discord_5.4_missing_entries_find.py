from collections import defaultdict
from mvlocscript.potools import readpo, writepo
from mvlocscript.fstools import glob_posix as glob
from pathlib import Path

def main():
    glob_current = "locale/**/*.po"
    
    # find entries that are both empty in current and broken, yet nonempty in fixed
    for current_path in glob(glob_current):
        if current_path.endswith('en.po'):
            continue
        broken_path = current_path.replace('locale', 'locale-broken')
        fixed_path = current_path.replace('locale', 'locale-fixed')

        dict_current, _, sourcelocation = readpo(current_path)
        dict_broken, _, _ = readpo(broken_path)
        dict_fixed, _, _ = readpo(fixed_path)

        for key in dict_current:
            entry_current = dict_current[key]
            entry_broken = dict_broken[key]
            entry_fixed = dict_fixed[key]

            if entry_current.value == '' and entry_broken.value == '' and entry_fixed.value != '':
                print(Path(current_path).name + "|" + entry_current.key)

main()