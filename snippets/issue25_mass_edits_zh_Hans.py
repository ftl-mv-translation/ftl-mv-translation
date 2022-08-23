from snippets.mass_edits import mass_translate

REPLACE_MAP = {
    'Continue...': '继续。',
    # Replaced by #81
    # 'Do something on-board the ship.': '舰船管理。',
    # 'Do something onboard the ship.': '舰船管理。',
    # 'Check the storage.': '舰船管理。',
    'Do nothing.': '跳过。',
    'An unvisited location.': '未探索的信标。',
}

mass_translate('locale/**/zh_Hans.po', REPLACE_MAP, overwrite=True)
