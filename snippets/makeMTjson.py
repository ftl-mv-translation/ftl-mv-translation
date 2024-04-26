from mvlocscript.fstools import glob_posix
from mvlocscript.potools import readpo
from sys import argv
from json import dump
from pathlib import Path

def main():
    if len(argv) != 3:
        print('You must input the lang code and multiverse version in the correct order. ex) snippets/makeMTjson.py ja 5.4.4')
        return
    
    globpattern_original = 'locale/**/en.po'

    data_dict = {}
    data_dict['lang'] = argv[1]
    data_dict['version'] = argv[2]
    dict_temp = {}
    for filepath_original in glob_posix(globpattern_original):
            dict_original, _, _ = readpo(filepath_original)
            dict_map = {}
            try:
                dict_hand, _, _ = readpo(f'locale/{Path(filepath_original).parent.parent.name}/{Path(filepath_original).parent.name}/{argv[1]}.po')
                for key, entry in dict_original.items():
                     dict_map[entry.value] = dict_hand.get(key, '')
                for key in dict_map:
                     if dict_map[key] == '':
                          continue
                     dict_map[key] = dict_map[key].value
            except Exception as e:
                 print(e)
                 dict_map = {entry.value: '' for entry in dict_original.values()}
            dict_temp.update(dict_map)
    data_dict['translation'] = [
        {
            'original': en,
            'deepl': hand,
            'machine': ''
        }
        for en, hand in dict_temp.items()
    ]
            
    with open(f'machine-json/machine-{argv[1]}-{argv[2]}.json', 'wt') as f:
        dump(data_dict, f)

if __name__ == '__main__':
    main()