import json
import re
from mvlocscript import machine
from pprint import pprint

json_path = None
data = None

def main():
    global json_path, data
    lang = input('Enter the language code that you want to edit. >>')
    json_list = machine.getMTjson(lang)
    if len(json_list) == 0:
        print(f"can't find any file in machine-json/ whose lang code is {lang}")
        return
    elif len(json_list) > 1:
        print(f"find multiple files in machine-json/ whose lang code is {lang}. make sure put only one file per langage in machine-json/")
        return
    
    json_path = json_list[0]
    print(f"you are editting {json_path}")
    with open(json_path) as f:
        data = json.load(f)
    
    while True:
        ParseCommand(input('>>'))
    
def ParseCommand(command):
    global json_path, data
    command = command.split(' ')
    if command[0] == '/searchOrigi':
        text = ' '.join(command[1:])
        text_pattern = re.compile(
            text,
            re.IGNORECASE
        )
        for en, translated in data['translation'].items():
            if text_pattern.search(en) is None:
                continue
            if translated['deepl'] != '':
                print(en + '\t(d)' + translated['deepl'])
            elif translated['machine'] != '':
                print(en + '\t(m)' + translated['machine'])
            else:
                print(en)
            print('\n')
    elif command[0] == '/searchText':
        text = ' '.join(command[1:])
        text_pattern = re.compile(
            text,
            re.IGNORECASE
        )
        for en, translated in data['translation'].items():
            if translated['deepl'] != '':
                target = translated['deepl']
            elif translated['machine'] != '':
                target = translated['machine']
            else:
                continue
            if text_pattern.search(target) is None:
                continue

            print(f'{target}\n')
    elif command[0] == '/deepl':
        machine.deepltranslate(command[1], json_path)


if __name__ == '__main__':
    main()