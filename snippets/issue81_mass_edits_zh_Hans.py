from snippets.mass_edits import mass_translate

REPLACE_MAP = {
    'Do something on-board the ship.': '星舰管理。',
    'Do something onboard the ship.': '星舰管理。',
    'Check the storage.': '星舰管理。',
}

mass_translate('locale/**/zh_Hans.po', REPLACE_MAP, overwrite=True)
