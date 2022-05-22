from loguru import logger
from collections import defaultdict
from lxml import etree
from io import BytesIO, StringIO
from mvlocscript.potools import StringEntry
from mvlocscript.xmltools import AttributeMatcher, MatcherBase, MultipleAttributeMatcher

logger = logging.getLogger(__name__)

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
    result = result.replace(b'<FTL xmlns:mod="http://dummy/mod">', b'<FTL>')

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

    def getsegment(self, tree, element):
        name = self._element_to_name.get(element, None)
        if (name is not None) and (self._name_count[name] == 1):
            return f'shipIcon[name="{name}"]'
    
    def isuniquefromroot(self, tree, element, segment):
        # Disable condensing path as there are many <shipIcon> elements serving different purposes
        return False
    
    # In most cases we're safe to short-circuit isuniquefromparent() to True, but lets leave it for XPath validation.

class FtlEventChoiceMatcher(MatcherBase):
    '''events_*.xml: match <choice req="...">'''
    def __init__(self):
        self._inner = MultipleAttributeMatcher(['req', 'lvl'], 'prioritized')

    def prepare(self, tree):
        return self._inner.prepare(tree)

    def getsegment(self, tree, element):
        if element.tag != 'choice':
            return None
        return self._inner.getsegment(tree, element)
    
    def isuniquefromroot(self, tree, element, segment):
        # Disable condensing path
        return False
    
    def isuniquefromparent(self, tree, element, segment):
        return self._inner.isuniquefromparent(tree, element, segment)

class FtlCustomStoreMatcher(MatcherBase):
    '''hyperspace.xml: match <customStore id="...">'''
    def __init__(self):
        self._inner = AttributeMatcher('id')

    def prepare(self, tree):
        return self._inner.prepare(tree)

    def getsegment(self, tree, element):
        if element.tag != 'customStore':
            return None
        return self._inner.getsegment(tree, element)
    
    def isuniquefromroot(self, tree, element, segment):
        # Disable condensing path
        return False
    
    def isuniquefromparent(self, tree, element, segment):
        return self._inner.isuniquefromparent(tree, element, segment)

def ftl_xpath_matchers():
    return [
        # Most elements use @name for key.
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

def _group_id_relocations_by_value(dict_oldoriginal, dict_neworiginal):
    '''Helper function to group entries by value'''
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

def handle_id_relocations(dict_oldoriginal, dict_neworiginal, dict_oldtranslated):
    possible_id_relocations = _group_id_relocations_by_value(dict_oldoriginal, dict_neworiginal)
    dict_newtranslated = dict(dict_oldtranslated)

    for value, oldoriginal_keys, neworiginal_keys in possible_id_relocations:
        if len(neworiginal_keys) > len(oldoriginal_keys):
            logger.info(
                '"{value:<40}" SKIP, #new > #old'
                f' {_shorten_seq(neworiginal_keys - oldoriginal_keys)}'
                f' > {_shorten_seq(oldoriginal_keys - neworiginal_keys)}',
                value=_shorten(value)
            )
            continue

        possible_translations: dict[str, list[StringEntry]] = defaultdict(list)
        for key in oldoriginal_keys:
            entry_oldtranslated = dict_oldtranslated.get(key, None)
            if entry_oldtranslated is not None:
                possible_translations[entry_oldtranslated.value].append(entry_oldtranslated)
        
        if len(possible_translations) == 0:
            logger.warning(
                '"{value:<40}" SKIP, no translation exists (possible desync).',
                value=_shorten(value)
            )
            continue
        if len(possible_translations) > 1:
            # Assumes no empty strings in obsolete entries because sanitize does that.
            logger.info(
                '"{value:<40}"'
                + (
                    ' SKIP, partially untranslated.'
                    if '' in possible_translations else
                    f' SKIP, translation conflicts. {_shorten_seq(_shorten(t) for t in possible_translations)}.'
                ),
                value=_shorten(value)
            )
            continue

        new_value, matching_entries = next(iter(possible_translations.items()))
        if new_value == '':
            continue

        if any(entry.fuzzy for entry in matching_entries):
            fuzzy = True
            fuzzy_comment = 'some translations are flagged fuzzy.'
        elif all(entry.obsolete for entry in matching_entries):
            fuzzy = True
            fuzzy_comment = 'all relocated translations are obsolete entries.'
        else:
            fuzzy = False
            fuzzy_comment = ''
        
        logger.info(
            '"{value:<40}"'
            + (f' FUZZY, {fuzzy_comment}' if fuzzy else '')
            + f' {_shorten_seq(oldoriginal_keys - neworiginal_keys)}'
            + f' -> {_shorten_seq(neworiginal_keys - oldoriginal_keys)}',
            value=_shorten(value)
        )

        for key in (neworiginal_keys - oldoriginal_keys):
            dict_newtranslated[key] = dict_neworiginal[key]._replace(value=value, fuzzy=fuzzy)
        
        # Don't delete/obsolete (oldoriginal_keys - neworiginal_keys) as it may accidently remove translation
        # that were already processed by another relocation. Sanitization should handle the useless entries anyway.
    
    return dict_newtranslated

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
            if entry_oldtranslated.value != entry_neworiginal.value:
                dict_newtranslated[key] = entry_oldtranslated._replace(
                    value=entry_neworiginal.value,
                    fuzzy=entry_oldtranslated.fuzzy or entry_neworiginal.fuzzy
                )
            
                logger.info(
                    f'{key}: "{_shorten(entry_oldtranslated.value)}" -> "{_shorten(entry_neworiginal.value)}"'
                )
        else:
            # Copy otherwise
            dict_newtranslated[key] = entry_oldtranslated

    return dict_newtranslated


