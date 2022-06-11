from snippets.mass_edits import mass_translate

REPLACE_MAP = {
    "...": "...",
    "Nevermind.": "算了。",
    "Decline.": "拒绝。",
    "Refuse.": "拒绝。",
    "Leave.": "离开。",
}

mass_translate('locale/**/zh_Hans.po', REPLACE_MAP, overwrite=True)
