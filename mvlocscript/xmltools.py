from collections import defaultdict
from functools import reduce
from lxml import etree

class AttributeProxy:
    def __init__(self, attrib):
        self._attrib = attrib
    
    @property
    def value(self):
        return str(self._attrib)

    @value.setter
    def value(self, value):
        self.getparent().set(self.attrname, value)
    
    @property
    def attrname(self):
        return self._attrib.attrname
    
    def getparent(self):
        return self._attrib.getparent()
    
    def __eq__(self, rhs):
        return isinstance(rhs, AttributeProxy) and self.getparent() == rhs.getparent() and self.attrname == rhs.attrname
    
    def __hash__(self):
        return hash((self.getparent(), self.attrname))

def get_element(tree_or_element):
    getroot = getattr(tree_or_element, 'getroot', None)
    if getroot is not None:
        return getroot()
    return tree_or_element

def xpath(tree_or_element, expr):
    '''
    Similar to lxml xpath(), but wraps attribute into AttributeProxy class,
    not lxml.etree._ElementUnicodeResult which is a thin proxy of str. This gives more control.
    '''
    xpath_result = tree_or_element.xpath(expr, namespaces=get_element(tree_or_element).nsmap)

    def convert_xpath_result(element_or_attribute):
        if getattr(element_or_attribute, 'is_attribute', False):
            return AttributeProxy(element_or_attribute)
        else:
            return element_or_attribute

    return list(map(convert_xpath_result, xpath_result))

def _get_tag_as_written(e):
    tag, prefix = e.tag, e.prefix
    if prefix is None:
        return tag
    else:
        return f'{prefix}:{tag[tag.find("}") + 1:]}'

class MatcherBase:
    def prepare(self, tree):
        pass

    def getsegment(self, tree, element):
        raise NotImplementedError
    
    def isuniquefromroot(self, tree, element, segment):
        results = tree.xpath(f'//{segment}', namespaces=tree.getroot().nsmap)
        assert len(results) > 0 and element in results
        return len(results) == 1
    
    def isuniquefromparent(self, tree, element, segment):
        results = element.xpath(f'../{segment}', namespaces=tree.getroot().nsmap)
        assert len(results) > 0 and element in results
        return len(results) == 1

class AttributeMatcher(MatcherBase):
    '''Match specific attribute name for identification'''
    def __init__(self, attribute):
        self._attribute = attribute
        self._cache = defaultdict(int)

    def prepare(self, tree):
        for element in tree.xpath(f'//*[@{self._attribute}]'):
            tagname = _get_tag_as_written(element)
            attrval = element.get(self._attribute)
            if '"' not in attrval:
                self._cache[(tagname, attrval)] += 1

    def getsegment(self, tree, element):
        attrval = element.get(self._attribute)
        if (attrval is not None) and ('"' not in attrval):
            return f'{_get_tag_as_written(element)}[@{self._attribute}="{attrval}"]'
        return None
    
    def isuniquefromroot(self, tree, element, segment):
        tagname = _get_tag_as_written(element)
        attrval = element.get(self._attribute)
        return self._cache[(tagname, attrval)] == 1

class UniqueXPathGenerator:
    '''
    Similar to lxml.etree.ElementTree.getpath(), but
    * Use unique attributes instead of ordinal if available.
    * Condense redundant elements around unique attributes.
    * Supports attributes and AttributeProxy.
    '''
    def __init__(self, tree, matchers: list[MatcherBase]):
        self._tree = tree
        self._matchers = matchers
        for matcher in self._matchers:
            matcher.prepare(self._tree)

    def _check_xpath(self, rootobj, xpathexpr, expected_element):
        results = rootobj.xpath(xpathexpr, namespaces=self._tree.getroot().nsmap)
        return len(results) == 1 and results[0] == expected_element
    
    def getpath(self, element_or_attribute_or_attributeproxy):
        attrname = getattr(element_or_attribute_or_attributeproxy, 'attrname', None)
        if attrname:
            return self.getpath(self._tree, element_or_attribute_or_attributeproxy.getparent()) + f'/@{attrname}'

        element = element_or_attribute_or_attributeproxy
        path = self._tree.getpath(element)

        segments = path.split('/')
        if segments[0] == '':
            # Initial '/'
            segments = segments[1:]
            assert segments

        new_xpath = ''
        curelement = None
        for segment in segments:
            curelement = (
                self._tree.getroot()
                if curelement is None else
                curelement.xpath(segment, namespaces=self._tree.getroot().nsmap)[0]
            )

            for matcher in self._matchers:
                new_segment = matcher.getsegment(self._tree, curelement)
                if new_segment is None:
                    continue
                
                try:
                    if matcher.isuniquefromroot(self._tree, curelement, new_segment):
                        new_xpath = f'//{new_segment}'
                        break
                except etree.XPathEvalError:
                    pass

                try:
                    if matcher.isuniquefromparent(self._tree, curelement, new_segment):
                        new_xpath = f'{new_xpath}/{new_segment}'
                        break
                except etree.XPathEvalError:
                    pass
            else:
                # /.../tag[ordinal]
                new_xpath = f'{new_xpath}/{segment}'
        
        return new_xpath

class XPathInclusionChecker:
    '''
    Given a predetermined set of XPath queries on a tree, check if an XPath query is contained in that set.
    '''
    def __init__(self, tree, queries):
        self._tree = tree
        self._entities = reduce(
            lambda s1, s2: s1 | s2,
            (set(xpath(tree, xpathexpr)) for xpathexpr in queries)
        )

    def contains(self, query):
        return set(xpath(self._tree, query)).issubset(self._entities)

def xmldiff(atree, btree, *args, **kwargs):
    '''Compare atree and btree'''

    uniqueXPathGenerator = UniqueXPathGenerator(atree, *args, **kwargs)
    
    differences = []
    def normalized_text(elem):
        return (elem.text or '').strip()

    def add_attribute_differences(path, aattrib, battrib):
        akeys = set(aattrib)
        bkeys = set(battrib)
        for key in (akeys | bkeys):
            aval = aattrib.get(key)
            bval = battrib.get(key)
            if aval != bval:
                differences.append((f'{path}/@{key}', f'attrib differs: "{aval}" != "{bval}"'))
    
    def add_differences(aelem, belem):
        if aelem.tag != belem.tag:
            differences.append((uniqueXPathGenerator.getpath(aelem), f'tag differs: {aelem.tag} != {belem.tag}'))
        
        if normalized_text(aelem) != normalized_text(belem):
            differences.append(
                (uniqueXPathGenerator.getpath(aelem), f'text differs: "{normalized_text(aelem)}" != "{normalized_text(belem)}"')
            )
        
        add_attribute_differences(uniqueXPathGenerator.getpath(aelem), aelem.attrib, belem.attrib)

        iselement = lambda e: isinstance(e.tag, str) # non-comment checker
        achildren = list(filter(iselement, aelem))
        bchildren = list(filter(iselement, belem))
                
        if len(achildren) != len(bchildren):
            differences.append((uniqueXPathGenerator.getpath(aelem), f'#children differs: {len(aelem)} != {len(belem)}'))
        else:
            for i in range(len(achildren)):
                add_differences(achildren[i], bchildren[i])
            
    add_differences(atree.getroot(), btree.getroot())
    return differences

def getsourceline(element_or_attribute_or_attributeproxy):
    ret = (
        getattr(element_or_attribute_or_attributeproxy, 'sourceline', None)
        or getattr(element_or_attribute_or_attributeproxy.getparent(), 'sourceline', None)
    )
    if ret is None:
        raise RuntimeError(f'getsourceline failed for {element_or_attribute_or_attributeproxy}')
    return ret
    