from collections import defaultdict
from itertools import islice
from typing import Optional
from bisect import bisect_left, bisect_right
import rapidfuzz.process
import rapidfuzz.fuzz
from mvlocscript.potools import StringEntry, parsekey, readpo
from mvlocscript.fstools import glob_posix
from loguru import logger

### Parameters

# Fuzzy match with 90% similarity or higher when relocating strings
_FUZZY_MATCH_MINIMAL_SCORE = 90

# Use ambiguous translation if 90% of them are the same (per file or per global)
_AMBIGUOUS_MINIMAL_DOMINANCY = 0.9

# Use ambiguous translation if at least 50% of them are translated (per file or per global)
_AMBIGUOUS_MINIMAL_TRANSLATION_RATIO = 0.5

# Use ambiguous translation if at least 3 of them are translated (per file or per global)
_AMBIGUOUS_MINIMAL_TRANSLATION_COUNT = 3

# Use length-based partial search for fuzzy matching for further optimization
class BlazeFuzz:
    def __init__(self, sentences, minimal_similarity=_FUZZY_MATCH_MINIMAL_SCORE):
        self._sentences = sorted(sentences, key=len)
        self._cutoff = minimal_similarity
        
        similarity_delta = (1 - minimal_similarity / 100) * 1.5
        self._minlen = 1 - similarity_delta
        self._maxlen = 1 + similarity_delta
    
    def extract_one(self, value):
        minindex = bisect_left(self._sentences, len(value) * self._minlen, key=len)
        maxindex = bisect_right(self._sentences, len(value) * self._maxlen, key=len)

        result = rapidfuzz.process.extractOne(
            value, self._sentences[minindex:maxindex],
            scorer=rapidfuzz.fuzz.ratio, score_cutoff=self._cutoff, processor=None
        )
        return result[0] if result else None

# When to mark fuzzy:
# 1. Not a complete match (< 100% score).
# 2. Ambiguous translation.
# 3. Any of the entries in the respective pool (whether it being original or translated) is fuzzy.
# 4. Whenever the pool *EXPANDS* on the newer version -- that is, when the number of entries are increased by
#    fuzzy matching update.

class TranslationMemoryEntry:
    def __init__(self):
        self._pool: dict[str, tuple[StringEntry, StringEntry]] = {}
        self._match_prepared = False
        self._dominant_translation_global: Optional[tuple[str, bool]] = None # (value, fuzzy)
        self._dominant_translation_by_file: dict[str, Optional[tuple[str, bool]]] = None # {path: (value, fuzzy)}

    def add_to_pool(self, entry_original: StringEntry, entry_translated: StringEntry):
        self._pool[entry_original.key] = (entry_original, entry_translated)

    def prepare_match(self):
        if self._match_prepared:
            return

        def get_dominant_translation(pool: list[tuple[StringEntry, StringEntry]]):
            histogram = defaultdict(int)
            fuzzy = defaultdict(bool)
            total_count = 0

            for entry_original, entry_translated in pool:
                value_translated = entry_translated.value
                if value_translated == '':
                    # Not yet translated
                    continue
                
                histogram[value_translated] += 1
                fuzzy[value_translated] = (
                    fuzzy[value_translated] or entry_original.fuzzy or entry_translated.fuzzy
                )
                total_count += 1

            dominant = max(histogram, default=None, key=histogram.get)
            if dominant is None:
                return None
            elif histogram[dominant] == total_count:
                return dominant, fuzzy[dominant]
            elif (
                (total_count >= _AMBIGUOUS_MINIMAL_TRANSLATION_COUNT)
                and (total_count >= _AMBIGUOUS_MINIMAL_TRANSLATION_RATIO * len(pool))
                and (histogram[dominant] >= total_count * _AMBIGUOUS_MINIMAL_DOMINANCY)
            ):
                return dominant, True
            else:
                return None

        # Group pool by files
        pool_by_file = defaultdict(list)
        for key, entry_pair in self._pool.items():
            path, _ = parsekey(key)
            pool_by_file[path].append(entry_pair)

        self._dominant_translation_global = get_dominant_translation(self._pool.values())
        self._dominant_translation_by_file = {
            path: get_dominant_translation(pool_by_file[path])
            for path in pool_by_file
        }

        self._match_prepared = True

    def match(self, filepath, key) -> Optional[tuple[str, bool]]:
        # Returns (value_translated, force_fuzzy) or None

        self.prepare_match()

        # Search in order of exact match -> same-file match -> global match
        exact_match = self._pool.get(key, None)
        if exact_match:
            _, entry_translated = exact_match
            return entry_translated.value, entry_translated.fuzzy
        
        file_match = self._dominant_translation_by_file.get(filepath, None)
        if file_match:
            return file_match
        
        return self._dominant_translation_global
    
class TranslationMemory:
    def __init__(self):
        self.tm: dict[str, TranslationMemoryEntry] = defaultdict(TranslationMemoryEntry)
        self._fuzz = None
        
    def add(self, dict_original, dict_translated):
        for key, entry_original in dict_original.items():
            if entry_original.obsolete:
                continue
            entry_translated = dict_translated.get(key, None)
            if (entry_translated is None) or entry_translated.obsolete:
                continue
        
            self.tm[entry_original.value].add_to_pool(entry_original, entry_translated)

    def prepare_match(self):
        for tme in self.tm.values():
            tme.prepare_match()
        self._fuzz = BlazeFuzz(self.tm.keys())

    def match(self, value, key) -> Optional[tuple[str, bool]]:
        # Returns (value_translated, fuzzy)
        value_oldoriginal = self._fuzz.extract_one(value)
        if value_oldoriginal is None:
            return None
        
        path, _ = parsekey(key)
        tme_match = self.tm[value_oldoriginal].match(path, key)
        if tme_match is None:
            return None
        value_translated, fuzzy = tme_match
        # We're gating fuzzy for the exact match only; Weblate will handle the fuzzy matches.
        # It's the only way to guarantee for Weblate to automatically show diffs.
        fuzzy = fuzzy and (value == value_oldoriginal)
        
        return (value_translated, fuzzy)

def generate_translation_memory(globpattern_original, globpattern_translated):
    logger.info('Reading original strings for generating TM...')
    dict_original_all = {}
    for filepath_original in glob_posix(globpattern_original):
        dict_original, _, _ = readpo(filepath_original)
        dict_original_all.update(dict_original)
    
    logger.info('Reading translated strings for generating TM...')
    dict_translated_all = {}
    for filepath_translated in glob_posix(globpattern_translated):
        dict_translated, _, _ = readpo(filepath_translated)
        dict_translated_all.update(dict_translated)
    
    logger.info('Generating TM...')
    tm = TranslationMemory()
    tm.add(dict_original_all, dict_translated_all)

    logger.info('Preprocessing matches...')
    tm.prepare_match()

    logger.info('Done.')
    return tm
