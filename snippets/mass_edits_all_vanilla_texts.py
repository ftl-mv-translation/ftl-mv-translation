from json import load
from snippets.mass_edits import mass_translate

LANG_MAP = {'de': 'de', 'es': 'es', 'fr': 'fr', 'it': 'it', 'ja': 'ja', 'pl': 'pl', 'pt': 'pt_BR', 'ru': 'ru', 'zh-Hans': 'zh_Hans'}

for lang_vanilla, lang_mvproject in LANG_MAP.items():
    with open(f'snippets/vanilla-texts/text-{lang_vanilla}.json', encoding='utf8') as f:
        text_map = load(f)
    mass_translate(f'locale/**/{lang_mvproject}.po', text_map, overwrite=False)
