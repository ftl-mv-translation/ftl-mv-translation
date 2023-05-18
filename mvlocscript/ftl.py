from itertools import zip_longest
from re import A
from loguru import logger
from collections import defaultdict, namedtuple
from lxml import etree
from io import BytesIO, StringIO
from mvlocscript.xmltools import AttributeMatcher, MatcherBase, MultipleAttributeMatcher, get_tag_as_written, xpath

### Reading and writing FTL XMLs

_XSLT_ADD_NAMESPACE_TEMPLATE = '''
<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:%NAMESPACE_NAME%="http://dummy/%NAMESPACE_NAME%"
>
    <xsl:output indent="yes" method="xml"/>
    <xsl:param name="namespaces"/>

    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="/*" priority="1">
        <xsl:element name="{name()}">
            <xsl:attribute name="%NAMESPACE_NAME%:XMLTOOLSDUMMY">XMLTOOLSDUMMY</xsl:attribute>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
        </xsl:element>
    </xsl:template>
</xsl:stylesheet>
'''

_FTL_XML_NAMESPACES = ['mod']

def parse_ftlxml(path):
    '''
    FTL Multiverse XMLs are actually written in a dialect of XML:
    - Uses undefined namespaces (`mod:` without xmlns definition)
    - Allows double-hypen (`--`) in comments.

    This function reads them as a standard lxml-parsed tree with minimal changes:
    - Replaces double-hypen (`--`) in comments to `__` instead.
    - Adds xmlns definitions to undefined namespaces (*).

    (*) Note: FTL cannot parse xmlns definitions at all, so this "well-formed" XML is actually invalid in FTL when
        it's directly serialized. Instead it MUST be serialized with the write_ftlxml() to make it readable from FTL.
    '''
    tree = etree.parse(path, etree.XMLParser(recover=True))

    # Apply XSLT multiple times to add namespace definitions
    for namespace in _FTL_XML_NAMESPACES:
        xslt_content = _XSLT_ADD_NAMESPACE_TEMPLATE.replace('%NAMESPACE_NAME%', namespace)
        xslt = etree.parse(StringIO(xslt_content))
        tree = tree.xslt(xslt)
    
    # Reparse since the old "recovered" namespaces are not actually processed in the tree
    tree = etree.parse(BytesIO(etree.tostring(tree, encoding='utf-8')), etree.XMLParser(recover=True))

    # Remove attributes added by XSLT
    for namespace in _FTL_XML_NAMESPACES:
        tree.getroot().attrib.pop(f'{{http://dummy/{namespace}}}XMLTOOLSDUMMY')

    # Remove double-hypen comments
    for comment in tree.xpath('//comment()'):
        comment.text = comment.text.replace('--', '__')

    # Reparse once again with no recover option
    tree = etree.parse(BytesIO(etree.tostring(tree, encoding='utf-8')))

    return tree

def write_ftlxml(path, tree):
    '''
    Writes out an XML that is readable from FTL.
    '''

    result = etree.tostring(tree, encoding='utf-8', pretty_print=True)

    # Note that `xmlns:mod="http://dummy/mod"` part is added by parse_ftlxml().
    result = result.replace(
        f'<{tree.getroot().tag} xmlns:mod="http://dummy/mod">'.encode(encoding='utf-8'),
        f'<{tree.getroot().tag}>'.encode(encoding='utf-8')
    )

    with open(path, 'wb') as f:
        f.write(result)

### ID-generation logics

class FtlShipIconMatcher(MatcherBase):
    '''hyperspace.xml: match /FTL/ships/shipIcons/shipIcon elements using the child <name> element'''
    def __init__(self):
        self._element_to_name = {}
        self._name_count = defaultdict(int)

    def prepare(self, tree):
        for element in tree.xpath('/FTL/ships/shipIcons/shipIcon'):
            nameelements = element.xpath('name')
            if len(nameelements) != 1:
                continue
            name = nameelements[0].text
            if '"' in name:
                continue
            
            self._element_to_name[element] = name
            self._name_count[name] += 1

    def getsegment(self, tree, element, original_segment):
        name = self._element_to_name.get(element, None)
        if (name is not None) and (self._name_count[name] == 1):
            return f'shipIcon[name="{name}"]'
    
    def isuniquefromroot(self, tree, element, segment):
        # Disable condensing path as there are many <shipIcon> elements serving different purposes
        return False
    
    # In most cases we're safe to short-circuit isuniquefromparent() to True, but lets leave it for XPath validation.

class FtlEventChoiceMatcher(MultipleAttributeMatcher):
    '''events_*.xml: match <choice req="..." [lvl="..."]>'''
    def __init__(self):
        super().__init__(['req', 'lvl'], 'prioritized', disable_condensing=True)

    def getsegment(self, tree, element, original_segment):
        if element.tag != 'choice':
            return None
        return super().getsegment(tree, element, original_segment)
    

class FtlCustomStoreMatcher(MatcherBase):
    '''hyperspace.xml: match <customStore id="...">'''
    def __init__(self):
        self._inner = AttributeMatcher('id')

    def prepare(self, tree):
        return self._inner.prepare(tree)

    def getsegment(self, tree, element, original_segment):
        if element.tag != 'customStore':
            return None
        return self._inner.getsegment(tree, element, original_segment)
    
    def isuniquefromroot(self, tree, element, segment):
        # Disable condensing path
        return False
    
    def isuniquefromparent(self, tree, element, segment):
        return self._inner.isuniquefromparent(tree, element, segment)

class FtlCustomShipMatcher(MatcherBase):
    '''hyperspace.xml: do _NOT_ apply any ID generation logic for //customShip/crew/*, as its @name is not an ID'''
    def getsegment(self, tree, element, original_segment):
        p1 = element.getparent() 
        p2 = None if p1 is None else p1.getparent()
        if (
            (p1 is not None)
            and (p2 is not None)
            and get_tag_as_written(p1) == 'crew'
            and get_tag_as_written(p2) == 'customShip'
        ):
            return original_segment
        return None
    
    def isuniquefromroot(self, tree, element, segment):
        # Disable condensing path
        return False
    
    def isuniquefromparent(self, tree, element, segment):
        # The segment is always unique from the element's parent as guaranteed by _ElementTree.getpath()
        return True

def ftl_xpath_matchers():
    return [
        # Don't apply any custom ID generation for //customShip/crew/*
        FtlCustomShipMatcher(),
        # Most elements use @name for key
        # @auto_blueprint also serves as a complementary key for <ship> elements
        MultipleAttributeMatcher(['name', 'auto_blueprint'], 'prioritized'),
        # Use @req and @lvl for <choice> elements in events
        FtlEventChoiceMatcher(),
        # Use child <name> element as a key for <shipIcon> elements
        FtlShipIconMatcher(),
        # Use @id for <customStore> elements
        FtlCustomStoreMatcher(),
    ]

### Update logics

def _shorten(obj):
    ret = str(obj)
    if len(ret) > 40:
        ret = ret[:37] + '...'
    return ret

def _shorten_seq(seq):
    seq = tuple(seq)
    ret = ', '.join(f'"{item}"' for item in seq[:3])
    if len(seq) > 3:
        ret += f', ... <{len(seq) - 3}>'
    return f'({ret})'

class IdRelocStrategyBase:
    def do(self, dict_oldoriginal, dict_neworiginal, dict_oldtranslated):
        raise NotImplementedError

class IdRelocGroupSubstitution(IdRelocStrategyBase):
    def __init__(self, aggressive):
        self._aggressive = aggressive

    def _log_skip(self, group_sourcestring, reason, warning=False):
        (logger.warning if warning else logger.info)(
            '"{value:<40}" SKIP, {reason}',
            value=_shorten(group_sourcestring),
            reason=reason
        )

    def _log_success(self, group_sourcestring, keys_from, keys_to, fuzzy=None):
        if fuzzy is None:
            comment = ''
        else:
            comment = f' FUZZY, {fuzzy}'
        
        logger.info(
            '"{value:<40}"{comment} {before} -> {after}',
            value=_shorten(group_sourcestring),
            comment=comment,
            before=_shorten_seq(keys_from),
            after=_shorten_seq(keys_to)
        )

    def _group_original_entries_by_value(self, dict_oldoriginal, dict_neworiginal):
        # Helper function to group entries by value

        def v2k(dict_entries):
            ret = defaultdict(set)
            for key, entry in dict_entries.items():
                ret[entry.value].add(key)
            return ret
        
        v2k_oldoriginal = v2k(dict_oldoriginal)
        v2k_neworiginal = v2k(dict_neworiginal)

        ret = []
        for value, neworiginal_keys in v2k_neworiginal.items():
            oldoriginal_keys = v2k_oldoriginal.get(value, None)
            if oldoriginal_keys is None:
                # No common keys
                continue
            if oldoriginal_keys.issuperset(neworiginal_keys):
                # No new keys at all
                continue
            ret.append((value, frozenset(oldoriginal_keys), frozenset(neworiginal_keys)))
        return ret

    def _possible_translations_v2e(self, dict_oldtranslated, keys):
        ret = defaultdict(list)
        for key in keys:
            entry_oldtranslated = dict_oldtranslated.get(key, None)
            if entry_oldtranslated is not None:
                ret[entry_oldtranslated.value].append(entry_oldtranslated)
        return ret

    def do(self, dict_oldoriginal, dict_neworiginal, dict_oldtranslated):
        possible_id_relocations = self._group_original_entries_by_value(dict_oldoriginal, dict_neworiginal)
        relocation_history = [] # [(oldoriginal_keys, neworiginal_keys, value, fuzzy)]

        for value, oldoriginal_keys, neworiginal_keys in possible_id_relocations:
            neworiginal_unique_keys = neworiginal_keys - oldoriginal_keys
            oldoriginal_unique_keys = oldoriginal_keys - neworiginal_keys
            
            # Unmatching entries are always ambiguous
            if len(neworiginal_keys) > len(oldoriginal_keys):
                self._log_skip(
                    value,
                    f'#new > #old. {_shorten_seq(neworiginal_unique_keys)} > {_shorten_seq(oldoriginal_unique_keys)}'
                )
                continue

            possible_translations = self._possible_translations_v2e(
                dict_oldtranslated, oldoriginal_unique_keys if self._aggressive else oldoriginal_keys
            )
            if len(possible_translations) == 0:
                self._log_skip(value, 'no translation exists (possible desync).', warning=True)
                continue

            if len(possible_translations) > 1:
                if '' in possible_translations:
                    self._log_skip(value, 'partially untranslated.')
                else:
                    self._log_skip(
                        value,
                        f'translation conflicts. {_shorten_seq(_shorten(t) for t in possible_translations)}.'
                    )
                continue
            
            value, matching_entries = next(iter(possible_translations.items()))
            fuzzy = None
            if any(entry.fuzzy for entry in matching_entries):
                fuzzy = 'some translations are flagged fuzzy.'
            elif all(entry.obsolete for entry in matching_entries):
                fuzzy = 'all relocated translations are from obsolete entries.'

            self._log_success(value, oldoriginal_unique_keys, neworiginal_unique_keys, fuzzy)
            relocation_history.append((oldoriginal_unique_keys, neworiginal_unique_keys, value, fuzzy is not None))
        
        # Apply changes
        dict_unmoved = dict(dict_oldtranslated)
        dict_moved = {}
        
        for oldoriginal_keys, neworiginal_keys, value, fuzzy in relocation_history:
            for key in oldoriginal_keys:
                dict_unmoved.pop(key, None)
            for key in neworiginal_keys:
                entry_neworiginal = dict_neworiginal[key]
                dict_moved[key] = entry_neworiginal._replace(value=value, fuzzy=fuzzy)
        
        dict_unmoved.update(dict_moved)
        return dict_unmoved

class IdRelocLeastLinenoDiff(IdRelocStrategyBase):
    _Candidate = namedtuple('_Candidate', ['new_key', 'entry', 'distance'])

    def _find_candidates(self, entry_oldoriginal, dict_neworiginal):
        '''Helper returning entries with an identical value, and sort them by their proximity in the new file.'''
        return sorted([
            IdRelocLeastLinenoDiff._Candidate(
                key,
                entry_neworiginal,
                abs(entry_neworiginal.lineno - entry_oldoriginal.lineno)
            )
            for key, entry_neworiginal in dict_neworiginal.items()
            if entry_neworiginal.value == entry_oldoriginal.value
        ], key=lambda c: c.distance)

    def do(self, dict_oldoriginal, dict_neworiginal, dict_oldtranslated):
        relocation_history = {} # key (oldoriginal) -> _Candidate
        used_ids = [] # key (neworiginal)

        for key, entry_oldoriginal in dict_oldoriginal.items():
            entry_neworiginal = dict_neworiginal.get(key, None)
            if (entry_neworiginal is not None) and (entry_oldoriginal.value == entry_neworiginal.value):
                # Identical; pass
                continue

            candidates = [
                candidate
                for candidate in self._find_candidates(entry_oldoriginal, dict_neworiginal)
                if candidate.new_key not in used_ids
            ]
            if candidates:
                # Greedy matching: assume the first choice was a good one, even if it's not always true.
                candidate = next(iter(candidates))
                relocation_history[key] = candidate
                used_ids.append(candidate.new_key)
                logger.info(
                    f'{key} -> {candidate.new_key} (among {len(candidates)} candidates, distance={candidate.distance})'
                )
            else:
                logger.info(f'{key} -> SKIP, no candidate.')

        # Apply changes
        dict_unmoved = dict(dict_oldtranslated)
        dict_moved = {}
        
        for key, selected_candidate in relocation_history.items():
            entry_oldtranslated = dict_unmoved.pop(key, None)
            if entry_oldtranslated is None:
                logger.warning(f'{key} -> SKIP, has no translation, possible desync.')
                continue

            dict_moved[selected_candidate.new_key] = selected_candidate.entry._replace(
                value=entry_oldtranslated.value,
                fuzzy=entry_oldtranslated.fuzzy or entry_oldtranslated.obsolete or selected_candidate.entry.fuzzy
            )
        
        dict_unmoved.update(dict_moved)
        return dict_unmoved

class IdRelocExactLinenoMatch(IdRelocStrategyBase):
    def do(self, dict_oldoriginal, dict_neworiginal, dict_oldtranslated):
        # Check if everything is same except for keys
        if not (
            (len(dict_oldoriginal) == len(dict_neworiginal))
            and all(
                entry_oldoriginal._replace(key='') == entry_neworiginal._replace(key='')
                for entry_oldoriginal, entry_neworiginal in zip_longest(
                    dict_oldoriginal.values(), dict_neworiginal.values()
                )
            )
        ):
            logger.warning('SKIP, elm strategy requires same content between old and new.')
            return dict_oldtranslated
            
        dict_oldtranslated_copy = dict(dict_oldtranslated)
        dict_newtranslated = {}
        for entry_oldoriginal, entry_neworiginal in zip_longest(dict_oldoriginal.values(), dict_neworiginal.values()):
            entry_oldtranslated = dict_oldtranslated_copy.pop(entry_oldoriginal.key, None)
            if entry_oldtranslated is None:
                logger.warning(f'{entry_oldoriginal.key} -> SKIP, has no translation, possible desync.')
                continue

            dict_newtranslated[entry_neworiginal.key] = entry_oldtranslated._replace(key=entry_neworiginal.key)

        # Recover remaining entries. Should be obsolete ones if there's no desync. 
        for key, entry_oldtranslated in dict_oldtranslated_copy.items():
            if key in dict_newtranslated:
                continue
            if not entry_oldtranslated.obsolete:
                logger.warning(f'{key} -> SKIP, a residual entry is non-obsolete, possible desync.')
                continue
            dict_newtranslated[key] = entry_oldtranslated
        
        return dict_newtranslated

def handle_id_relocations(dict_oldoriginal, dict_neworiginal, dict_oldtranslated, id_relocation_strategy):
    STRATEGY_FACTORIES = {
        'gs': (lambda: IdRelocGroupSubstitution(False)),
        'gsa': (lambda: IdRelocGroupSubstitution(True)),
        'lld': (lambda: IdRelocLeastLinenoDiff()),
        'elm': (lambda: IdRelocExactLinenoMatch()),
    }
    factory = STRATEGY_FACTORIES.get(id_relocation_strategy, None)
    if factory is None:
        raise RuntimeError(f'Unknown strategy {id_relocation_strategy}')
    return factory().do(dict_oldoriginal, dict_neworiginal, dict_oldtranslated)

def handle_same_string_updates(dict_oldoriginal, dict_neworiginal, dict_oldtranslated):
    dict_newtranslated = {}

    updated_keys = set(dict_oldoriginal) & set(dict_neworiginal)
    def is_same_string(key, entry_oldtranslated):
        if key not in updated_keys:
            return False
        if entry_oldtranslated.obsolete:
            logger.warning(
                f'{key}: SKIP, obsoleted in translation but valid in both versions of the original locale'
                ' (possible desync).'
            )
            return False
        entry_oldoriginal = dict_oldoriginal[key]
        return entry_oldtranslated.value == entry_oldoriginal.value

    for key, entry_oldtranslated in dict_oldtranslated.items():
        if is_same_string(key, entry_oldtranslated):
            # Perform same-string update
            entry_neworiginal = dict_neworiginal[key]
            dict_newtranslated[key] = entry_oldtranslated._replace(
                value=entry_neworiginal.value,
                fuzzy=entry_oldtranslated.fuzzy or entry_neworiginal.fuzzy
            )
            if entry_oldtranslated.value != entry_neworiginal.value:
                logger.info(
                    f'{key}: "{_shorten(entry_oldtranslated.value)}" -> "{_shorten(entry_neworiginal.value)}"'
                )
        else:
            # Copy otherwise
            dict_newtranslated[key] = entry_oldtranslated

    return dict_newtranslated

### Apply logics

class ApplyPostProcessBase:
    def do(self, tree, path):
        raise NotImplementedError

class ApplyPostProcessHullNumbersFontSubstitution(ApplyPostProcessBase):
    '''Change /FTL/hullNumbers//@type for hull hit point numbers.'''
    def __init__(self, arg):
        self._type = arg

    def do(self, tree, path):
        if 'data/hyperspace.xml' not in path:
            return
        attributes = xpath(tree, '/FTL/hullNumbers//@type')
        for attribute in attributes:
            attribute.value = str(self._type)

def apply_postprocess(tree, path, postprocess, arg):
    POSTPROCESS_FACTORIES = {
        'substitute-font-for-hull-numbers': (lambda: ApplyPostProcessHullNumbersFontSubstitution(arg)),
    }
    factory = POSTPROCESS_FACTORIES.get(postprocess, None)
    if factory is None:
        raise RuntimeError(f'Unknown postprocess {postprocess}')
    factory().do(tree, path)
