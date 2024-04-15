import json
from sys import argv

def main():
    if len(argv) != 2:
        print('You must input MT json file. ex) snippets/fix_variable.py machine-json/machine-ja-5.4.4.json')
        return
    
    with open(argv[1]) as f:
        data_dict = json.load(f)
        
    for text_dict in data_dict['translation']:
        text_dict['deepl'] = text_dict['deepl'].replace('\\ ', '\\')
        text_dict['machine'] = text_dict['machine'].replace('\\ ', '\\')
    
    with open(argv[1], 'wt') as f:
        json.dump(data_dict, f)
        
if __name__ == '__main__':
    main()