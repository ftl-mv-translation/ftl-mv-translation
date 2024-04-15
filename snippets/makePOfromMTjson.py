from mvlocscript.fstools import glob_posix
from mvlocscript.potools import readpo, writepo, StringEntry
from sys import argv
import json
from pathlib import Path

def main():
    if len(argv) != 2:
        print('You must input MT json file. ex) snippets/makePOfromMTjson.py machine-json/machine-ja-5.4.4.json')
        return
    
    globpattern_original = 'locale/**/en.po'

    with open(argv[1]) as f:
        data_dict = json.load(f)
    
    lang = data_dict['lang']
    
    map_dict = {}
    for text_dict in data_dict['translation']:
        if text_dict['deepl'] != '':
            map_dict[text_dict['original']] = text_dict['deepl']
        elif text_dict['machine'] != '':
            map_dict[text_dict['original']] = text_dict['machine']
            
    for filepath_original in glob_posix(globpattern_original):
        dict_original, _, _ = readpo(filepath_original)
        new_entries = []
        for entry in dict_original.values():
            new_entries.append(StringEntry(entry.key, map_dict.get(entry.value, ''), entry.lineno, False, False))
        writepo(f'locale-machine/{Path(filepath_original).parent.parent.name}/{Path(filepath_original).parent.name}/{lang}.po', new_entries, f'src-en/{Path(filepath_original).parent.parent.name}/{Path(filepath_original).parent.name}')

if __name__ == '__main__':
    main()