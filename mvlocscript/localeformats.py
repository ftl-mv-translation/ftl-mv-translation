import polib
from collections import namedtuple

StringEntry = namedtuple('StringEntry', ['key', 'value', 'lineno', 'fuzzy', 'obsolete'])

def stringentries_to_dictionary(entries: list[StringEntry]) -> dict[str, StringEntry]:
    return {entry.key: entry for entry in entries}

def readpo(path) -> list[StringEntry]:
    ret = []
    for entry in polib.pofile(path):
        occurrences = entry.occurrences[0][1] if entry.occurrences else -1
        if occurrences == -1 and not entry.obsolete:
            raise RuntimeError("sourceline cannot be omitted for non-obsolete entries")

        ret.append(
            StringEntry(entry.msgid, entry.msgstr, occurrences, entry.fuzzy, entry.obsolete)
        )
    return ret

def infer_sourcelocation(path):
    try:
        return polib.pofile(path)[0].occurrences[0][0]
    except:
        return None

def _create_pofile(entries: list[StringEntry], sourcelocation):
    po = polib.POFile()
    po.metadata = {
        'MIME-Version': '1.0',
        'Content-Type': 'text/plain; charset=utf-8',
        'Content-Transfer-Encoding': '8bit',
    }
    for entry in entries:
        poentry = polib.POEntry(
            msgid=entry.key,
            msgstr=entry.value,
            occurrences=[(sourcelocation, entry.lineno)],
            obsolete=entry.obsolete,
            flags=['fuzzy'] if entry.fuzzy else []
        )
        po.append(poentry)
    
    return po

def writepo(path, entries: list[StringEntry], sourcelocation):
    _create_pofile(entries, sourcelocation).save(path)

def generate_pot(entries: list[StringEntry], sourcelocation):
    pot = _create_pofile(entries, sourcelocation)
    for entry in pot:
        entry.obsolete = False
        entry.flags = []
        entry.msgstr = ''
    return pot

def merge_pot(path, pot):
    po = polib.pofile(path)
    po.merge(pot)
    def sortkey(entry):
        if entry.occurrences:
            return entry.occurrences[0][1]
        assert entry.obsolete # Obsolete entries are rid of sourceline and written last anyway
        return -1
    po.sort(key=sortkey)
    po.save(path)

