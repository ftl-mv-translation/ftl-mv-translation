from collections import defaultdict
from lxml import etree
from io import BytesIO, StringIO
from mvlocscript.xmltools import AttributeMatcher, MatcherBase

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

class FtlEventChoiceReqAttributeMatcher(MatcherBase):
    '''events_*.xml: match <choice req="...">'''
    def __init__(self):
        self._inner = AttributeMatcher('req')

    def getsegment(self, tree, element):
        if element.tag != 'choice':
            return None
        return self._inner.getsegment(tree, element)
    
    def isuniquefromroot(self, tree, element, segment):
        # Disable condensing path
        return False
    
    def isuniquefromparent(self, tree, element, segment):
        return self._inner.isuniquefromparent(tree, element, segment)

def ftl_xpath_matchers():
    return [AttributeMatcher('name'), FtlEventChoiceReqAttributeMatcher(), FtlShipIconMatcher()]
