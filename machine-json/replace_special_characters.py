import json
from sys import argv

special_char_transtable_decode = str.maketrans({
    "{":"燃料",  # fule
    "|":"ドローン",  # drones
    "}":"ミサイル",  # missiles
    "~":"スクラップ",  # scrap
})

with open(argv[1]) as f:
    data = json.load(f)

for text_dict in data['translation']:
    text_dict['deepl'] = text_dict['deepl'].translate(special_char_transtable_decode)
    text_dict['machine'] = text_dict['machine'].translate(special_char_transtable_decode)

with open(argv[1], 'wt') as f:
    json.dump(data, f)