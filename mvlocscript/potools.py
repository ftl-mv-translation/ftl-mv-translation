import polib
from loguru import logger
from collections import namedtuple
from collections.abc import Iterable

# mvloc uses a strict subset of .po format where each entry has following constraints:
#
# * Each msgid follows a `{xmlfilename}${xpath}` format.
#   Example: `data/blueprints.xml.append$//crewBlueprint[@name="energy"]/title`
#
# * Each entry affects exactly one location in the target XML tree.
#   As consequence, each entry has exactly one occurrence comment (`#:`).
#
# * The entries are sorted in the source line number specified by occurrence, because Weblate shows entry in order.
#   Do note that obsolete entries are always located at the end of the file because polib orders as such.
#
# * Uses only msgid, msgstr, a fuzzy flag and an occurrence comment for an entry (other comments are internally managed
#   by Weblate). An entry might be an obsolete one, so basically each entry can be expressed by the following tuple:
#   Do note that polib does not retain lineno for obsolete entries so `obsolete == (lineno == -1)` is always valid.

StringEntry = namedtuple('StringEntry', ['key', 'value', 'lineno', 'fuzzy', 'obsolete']) # str, str, int, bool, bool

def parsekey(key: str) -> tuple[str, str]:
    idx = key.find('$')
    if idx == -1:
        return '', key
    return key[:idx + 1], key[idx + 1:]

def readpo(path) -> tuple[dict[str, StringEntry], str, str]:
    '''
    Read .po file and return it as `(entriesdict, prefix, sourcelocation)` tuple,
    where `entriesdict` is an ordered dict of StringEntry indexed by its key,
    `prefix` is a prefix of ID including character `$` (returns an empty string if none exists),
    and `sourcelocation` is a file path to the occurrences (returns an empty string if none exists).
    '''

    def infer_prefix(entries):
        if not entries:
            logger.warning(f'readpo(): cannot infer prefix for "{path}"; the file has no entries.')
            return ''
        
        firstentry = next(iter(entries))
        prefix, _ = parsekey(firstentry.key)
        if prefix == '':
            logger.warning(f'readpo(): cannot infer prefix for "{path}"; the entries are not prefixed.')
            return ''
        if not all(entry.key.startswith(prefix) for entry in entries):
            logger.warning(f'readpo(): cannot infer prefix for "{path}"; the entries have no common prefix.')
            return ''
        
        return prefix

    def infer_sourcelocation(pofile: polib.POFile):
        nonobsolete_poentries = [poentry for poentry in pofile if not poentry.obsolete]
        if not nonobsolete_poentries:
            logger.warning(f'readpo(): cannot infer sourcelocation for "{path}"; the file has no non-obsolete entries.')
            return ''
        
        firstentry = next(iter(nonobsolete_poentries))
        assert firstentry.occurrences
        sourcelocation = firstentry.occurrences[0][0]

        if not all(
            (poentry.occurrences and (poentry.occurrences[0][0] == sourcelocation))
            for poentry in nonobsolete_poentries
        ):
            logger.warning(
                f'readpo(): cannot infer sourcelocation for "{path}"; the entries have no common occurrence comments.'
            )
            return ''
        
        return sourcelocation

    def is_sorted(entries):
        # Check if the entries are sorted properly
        for idx, entry in enumerate(entries):
            if idx == 0:
                continue
            if entry.obsolete:
                continue

            preventry = entries[idx - 1]
            if preventry.obsolete or (preventry.lineno > entry.lineno):
                return False
        return True
    
    pofile = polib.pofile(path)

    entries = []
    for poentry in pofile:
        occurrences = int(poentry.occurrences[0][1]) if poentry.occurrences else -1
        if occurrences == -1 and not poentry.obsolete:
            raise RuntimeError("sourceline cannot be omitted for non-obsolete entries")

        entries.append(
            StringEntry(poentry.msgid, poentry.msgstr, occurrences, poentry.fuzzy, bool(poentry.obsolete))
        )

    if not is_sorted(entries):
        logger.warning(f'readpo(): "{path}" is not sorted by lineno.')

    entriesdict = {entry.key: entry for entry in entries}
    prefix = infer_prefix(entries)
    sourcelocation = infer_sourcelocation(pofile)
    
    return entriesdict, prefix, sourcelocation

def writepo(path, entries: Iterable[StringEntry], sourcelocation) -> None:
    '''
    Write a .po file based on given `entries` and `sourcelocation`. The input `entries` MUST be sorted beforehand.
    '''

    pofile = polib.POFile()
    pofile.metadata = {
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
        pofile.append(poentry)
    
    pofile.save(path)
