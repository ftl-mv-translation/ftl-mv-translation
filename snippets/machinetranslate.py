from googletrans import Translator
import json
from sys import argv

AUTOSAVE_INTERVAL = 100

def main():
    if len(argv) != 2:
        print('you must input json file name. ex. machinetranslate.py machine-json/machine-ja-5.4.4.json')
        return

    with open(argv[1]) as f:
        data_dict = json.load(f)
    
    target_lang = data_dict['lang']
    all_length = len(data_dict['translation'])
    count = 0
    count_translate = 0
        
    translator = Translator()
    
    
    def translate(original):
        for i in range(10):
            try:
                translation = translator.translate(original, target_lang, 'en').text
                return translation, True
            except:
                pass
        return original, False
    
    
    for text_dict in data_dict['translation']:
        count += 1
        if text_dict['machine'] != '' or text_dict['deepl'] != '':
            continue
        translated_text, is_success = translate(text_dict['original'])
        if not is_success:
            continue
        text_dict['machine'] = translated_text
        print(f'{count}/{all_length}\t{translated_text}')
        
        count_translate += 1
        if count_translate % AUTOSAVE_INTERVAL == 0:
            print('auto saving...')
            with open(argv[1], 'wt') as f:
                json.dump(data_dict, f)

if __name__ == '__main__':
    main()