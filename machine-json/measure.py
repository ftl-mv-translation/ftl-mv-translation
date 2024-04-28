from json import load
from sys import argv

with open(argv[1]) as f:
    data = load(f)

all_length = len(data['translation'])
deepl_length = 0
deepl_chara_len = 0
untranslated_len = 0
untranslated_chara_len = 0

for key, textdata in data['translation'].items():
    if textdata['deepl'] != '':
        deepl_length += 1
    else:
        deepl_chara_len += len(key)
        if textdata['machine'] == '':
            untranslated_len += 1
            untranslated_chara_len += len(key)
        
print(f"language: {data['lang']}, version: {data['version']}\n\n*deepl*\nachievement: {deepl_length}/{all_length}({deepl_length / all_length * 100}%)\nleft: {all_length - deepl_length} texts ({deepl_chara_len} characters)\n\n*total*\nachievement: {all_length - untranslated_len}/{all_length}({(all_length -untranslated_len) / all_length * 100}%)\nleft: {untranslated_len} texts ({untranslated_chara_len} characters)")
