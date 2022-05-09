import json
import polib
from collections import namedtuple

StringEntry = namedtuple('StringEntry', ['key', 'value', 'lineno'])

def stringentries_to_dictionary(entries: list[StringEntry]) -> dict[str, str]:
    return {entry.key: entry.value for entry in entries}

def readjson(path) -> list[StringEntry]:
    with open(path, encoding='utf-8') as f:
        return [StringEntry(k, v, -1) for k, v in json.load(f).items()]

    
def writejson(path, entries: list[StringEntry]):
    with open(path, 'w', encoding='utf-8', newline='') as f:
        json.dump({entry.key: entry.value for entry in entries}, f, indent=4, ensure_ascii=False)

def readpo(path) -> list[StringEntry]:
    return [
        StringEntry(entry.msgid, entry.msgstr, entry.occurrences[0][1])
        for entry in polib.pofile(path)
    ]

def writepo(path, entries: list[StringEntry], sourcelocation):
    po = polib.POFile()
    po.metadata = {
        'MIME-Version': '1.0',
        'Content-Type': 'text/plain; charset=utf-8',
        'Content-Transfer-Encoding': '8bit',
    }
    for entry in entries:
        po.append(polib.POEntry(
            msgid=entry.key,
            msgstr=entry.value,
            occurrences=[(sourcelocation, entry.lineno)]
        ))
    
    po.save(path)
