from mvlocscript.potools import readpo, writepo, StringEntry

dict_old_original, _, _ = readpo('events_sector_abandoned.xml/en.po')
dict_new_original, _, _ = readpo('locale/data/events_sector_abandoned.xml/en.po')

for lang in ['de', 'fr', 'ko', 'ru', 'zh_Hans']:
    dict_old_lang, _, _ = readpo(f'events_sector_abandoned.xml/{lang}.po')
    new_entries = []
    for new_key in dict_new_original:
        found = False
        for old_key in dict_old_original:
            if dict_old_original[old_key].value == dict_new_original[new_key].value:
                found = True
                new_entries.append(StringEntry(dict_new_original[new_key].key, dict_old_lang[old_key].value, dict_new_original[new_key].lineno, dict_old_lang[old_key].fuzzy, dict_old_lang[old_key].obsolete))
                break
        if not found:
            new_entries.append(StringEntry(dict_new_original[new_key].key, '', dict_new_original[new_key].lineno, False, False))
    writepo(f'locale/data/events_sector_abandoned.xml/{lang}.po', new_entries, 'src-en/data/events_sector_abandoned.xml')