from mvlocscript.ftl import parse_ftlxml
from mvlocscript.xmltools import XPathInclusionChecker
from snippets.mass_edits import MASS_MAP_IGNORE_AND_DONT_STAT, mass_map

xic = XPathInclusionChecker(parse_ftlxml('src-en/data/blueprints.xml.append'), [
    "//FTL/*[starts-with(@name,'JUDGE_BOON_')]//*",
    "//FTL/*[substring(@name, string-length(@name) - string-length('_ENEMY') + 1) = '_ENEMY']//*"
])

def mapfunc(entry_original, entry_translated):
    xpath = entry_original.key[entry_original.key.index('$') + 1:]
    if not xic.contains(xpath):
        return MASS_MAP_IGNORE_AND_DONT_STAT

    print(entry_original.key)
    return entry_original.value

mass_map('locale/data/blueprints.xml.append/ko.po', mapfunc, True)
