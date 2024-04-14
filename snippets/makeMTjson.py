from mvlocscript.fstools import glob_posix
from mvlocscript.potools import readpo
from sys import argv
from json import dump

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
            dict_original = {entry.value: '' for entry in dict_original.values()}
            dict_temp.update(dict_original)
    data_dict['translation'] = [
        {
            'original': en,
            'deepl': '',
            'machine': ''
        }
        for en in dict_temp.keys()
    ]
            
    with open(f'machine-{argv[1]}-{argv[2]}.json', 'wt') as f:
        dump(data_dict, f)

if __name__ == '__main__':
    main()