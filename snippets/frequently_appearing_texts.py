from collections import defaultdict
from mvlocscript.potools import readpo
from mvlocscript.fstools import glob_posix as glob
from pprint import pprint
from sys import argv
from json import dump

MINIMAM = 20

def main():
    stat = defaultdict(int)
    for path in glob('locale/**/en.po'):
        dict_original, _, _ = readpo(path)
        for entry in dict_original.values():
            stat[entry.value] += 1
    stat_sorted = sorted(stat.items(), key=lambda x:x[1], reverse=True)
    stat_multiple = [stat for stat in stat_sorted if stat[1] >= MINIMAM]
    return stat_multiple

def makejson(stat, lang):
    map_dict = {value[0]: '' for value in stat}
    with open(f'frequently_appearing_{lang}.json', 'wt', encoding='utf8') as f:
        dump(map_dict, f, indent=4)

if __name__ == '__main__':
    if len(argv) == 1:
        stat = main()
        pprint(stat)
        print(f'{len(stat)} texts')
    else:
        makejson(main(), argv[1])