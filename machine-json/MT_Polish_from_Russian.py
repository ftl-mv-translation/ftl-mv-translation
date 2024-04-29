from googletrans import Translator
import json

AUTOSAVE_INTERVAL = 100

def main():
    with open('machine-json/machine-ru-5.4.5.json') as f:
        data_dict = json.load(f)

    all_length = len(data_dict['translation'])
    count = 0
    count_translate = 0
        
    translator = Translator()
    
    def save(data_dict):
        with open('machine-json/machine-ru-5.4.5.json', 'wt') as f:
            json.dump(data_dict, f)
    
    def translate(original):
        for i in range(10):
            try:
                translation = translator.translate(original, 'pl', 'ru').text
                return translation, True
            except:
                pass
        return original, False
    
    
    for key, text_dict in data_dict['translation'].items():
        count += 1
        if text_dict['deepl'] == '':
            print(f'{count} done')
            continue
        translated_text, is_success = translate(text_dict['deepl'])
        if not is_success:
            print(f'translation failed: {translated_text}')
            continue
        text_dict['machine'] = translated_text.replace('\\ ', '\\')
        text_dict['deepl'] = ''
        print(f'{count}/{all_length}\t{translated_text}')
        
        count_translate += 1
        if count_translate % AUTOSAVE_INTERVAL == 0:
            print('auto saving...')
            save(data_dict)

    save(data_dict)
    print('All translation have done! If this is the first time to run this script, please re-run and check if there are missing translation.')

if __name__ == '__main__':
    main()