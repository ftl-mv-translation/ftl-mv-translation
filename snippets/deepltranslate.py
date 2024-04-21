import requests
import json
from random import random
from time import sleep
from sys import argv

url = "https://api-free.deepl.com/v2/translate"
#url = "https://api.deepl.com/v2/translate"
character_limit = -1 #Limit on number of characters to translate. -1 means unlimited
retry_number = 5 #Number of retries if translation fails.
auto_save_interval = 10 #Auto save interval for each number of translations. 

def Main():
    if len(argv) != 3:
        print('you must input your deepl apy key and target json file path')
        return
    
    API_KEY = argv[1]
    json_path = argv[2]
    
    def Rewrite(data):
        with open(json_path, 'wt') as f:
            json.dump(data, f)

    with open(json_path) as f:
        data = json.load(f)
    
    target_lang = data['lang']
    
    translation_number = 0
    count_in_total = 0
    for text in data['translation']:
        if text['deepl'] != '':
            continue
        
        for i in range(retry_number):
            translation_number += len(text['original'])
            if character_limit > -1 and translation_number > character_limit:
                print('Reached character limit which you set.')
                Rewrite(data)
                return
            
            params = {
                    'auth_key' : API_KEY,
                    'text' : text['original'],
                    'source_lang' : 'EN',
                    'target_lang' : target_lang,
                }
            try:
                response = requests.post(url, data=params)
                status = response.status_code
                
                if status == 200:
                    translated_text = response.json()['translations'][0]['text']
                    text['deepl'] = translated_text
                    text['machine'] = ''
                    count_in_total += 1
                    print(f'translated {count_in_total} times and {translation_number} characters in total\t{translated_text}')
                    if count_in_total % auto_save_interval == 0:
                        print('Auto saving data...')
                        Rewrite(data)
                    break
                elif status == 456:
                    print('Reached the translation limit of 500000 characters per month.')
                    Rewrite(data)
                    return
                else:
                    print(f'HTTP error : {status}')
                    sleep((2 ** i) + random())
                
            except Exception:
                continue
    print('All of the texts have been translated!')
    Rewrite(data)
    return


if __name__ == '__main__':
    Main()
    input('Json rewriting is completed. Press enter key to exit.')