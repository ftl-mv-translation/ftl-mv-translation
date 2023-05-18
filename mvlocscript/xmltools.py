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

def get_tag_as_written(e):
    tag, prefix = e.tag, e.prefix
    if prefix is None:
        return tag
    else:
        return f'{prefix}:{tag[tag.find("}") + 1:]}'

class MatcherBase:
    def prepare(self, tree):
        pass

    def getsegment(self, tree, element, original_segment):
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
            tagname = get_tag_as_written(element)
            attrval = element.get(self._attribute)
            if '"' not in attrval:
                self._cache[(tagname, attrval)] += 1

    def getsegment(self, tree, element, original_segment):
        attrval = element.get(self._attribute)
        if (attrval is not None) and ('"' not in attrval):
            return f'{get_tag_as_written(element)}[@{self._attribute}="{attrval}"]'
        return None
    
    def isuniquefromroot(self, tree, element, segment):
        tagname = get_tag_as_written(element)
        attrval = element.get(self._attribute)
        return self._cache[(tagname, attrval)] == 1

def _get_multiple_values_from_dict(dictionary, keys):
    return tuple(dictionary.get(key, None) for key in keys)

class MultipleAttributeMatcher(MatcherBase):
    '''Match specific attributes for identification'''

    _UNIQUE_FROM_ROOT = 2
    _UNIQUE_FROM_PARENT = 1
    _UNIQUE_NONE = 0

    def __init__(self, attributes, attribute_selection='exhaustive', disable_condensing=False):
        '''
        @attribute_selection can be one of:
            'exhaustive': use every possible combinations for attribute selection
            'prioritized': use attribute only if all other preceding attributes are used as well.
        '''
        self._attributes = attributes
        self._elementscache = []
        self._resultcache = {} # element -> (segment, UNIQUE_*)
        if attribute_selection not in ('exhaustive', 'prioritized'):
            raise RuntimeError(f'Unknown attribute_selection: {attribute_selection}')
        self._attribute_selection_exhaustive = (attribute_selection == 'exhaustive')
        self._disable_condensing = disable_condensing

    def prepare(self, tree):
        condition_expr = ' or '.join(f'@{attribute}' for attribute in self._attributes)
        self._elementscache = tree.xpath(f'//*[{condition_expr}]')

    def _candidates(self, element):
        attrvals = _get_multiple_values_from_dict(element, self._attributes)
        num_attributes = len(self._attributes)
        
        if self._attribute_selection_exhaustive:
            # 000001, 000010, 000011, ..., 111110, 111111
            # Start from 1 because we don't want condition-less rewrites to be considered
            check_targets = list(range(1, 1 << num_attributes))
            # Check in order of least popcounts
            check_targets = sorted(check_targets, key=lambda bits: bin(bits).count('1'))
        else:
            # 000001, 000011, 000111, ..., 011111, 111111
            check_targets = list(
                (1 << num_selected_attributes) - 1
                for num_selected_attributes in range(1, num_attributes + 1)
            )

        for i in check_targets:
            candidate = {}
            for j in range(num_attributes):
                if i & (1 << j):
                    candidate[j] = attrvals[j]
            
            # Can't use '"' in XPath, at least in an easy and representative way
            if all(((attrval is None) or ('"' not in attrval)) for attrval in candidate.values()):
                yield candidate

    def _count_matches(self, elements, tagname, candidate):
        ret = 0
        for other_element in elements:
            if get_tag_as_written(other_element) != tagname:
                continue
            
            attrvals = _get_multiple_values_from_dict(other_element, self._attributes)
            if all(attrvals[idx] == value for idx, value in candidate.items()):
                ret += 1
        return ret

    def _evaluate_candidate(self, element, candidate):
        tagname = get_tag_as_written(element)
        if not self._disable_condensing:
            fromroot = self._count_matches(self._elementscache, tagname, candidate)
            assert fromroot > 0
            if fromroot == 1:
                return MultipleAttributeMatcher._UNIQUE_FROM_ROOT
        
        parent = element.getparent()
        if parent is None:
            # This is unlikely because it means the element is the root.
            # Anyway technically speaking it's unique in this case
            return MultipleAttributeMatcher._UNIQUE_FROM_PARENT
        
        fromparent = self._count_matches(set(parent) & set(self._elementscache), tagname, candidate)
        assert fromparent > 0
        if fromparent == 1:
            return MultipleAttributeMatcher._UNIQUE_FROM_PARENT
        
        return MultipleAttributeMatcher._UNIQUE_NONE

    def _candidate_to_segment(self, tagname, candidate):
        condition_expr = ' and '.join(
            f'not(@{self._attributes[attridx]})' if attrval is None else f'@{self._attributes[attridx]}="{attrval}"'
            for attridx, attrval in candidate.items()
        )
        return f'{tagname}[{condition_expr}]'

    def getsegment(self, tree, element, original_segment):
        if element not in self._elementscache:
            return None

        # In case if it's already computed
        result = self._resultcache.get(element, None)
        if result is not None:
            return result[0]
        
        best_candidate = None
        best_candidate_uniquity = -1
        for candidate in self._candidates(element):
            uniquity = self._evaluate_candidate(element, candidate)
            if uniquity > best_candidate_uniquity:
                best_candidate = candidate
                best_candidate_uniquity = uniquity
                if uniquity == MultipleAttributeMatcher._UNIQUE_FROM_ROOT:
                    break
        
        assert best_candidate is not None
        segment = self._candidate_to_segment(get_tag_as_written(element), best_candidate)
        self._resultcache[element] = (segment, best_candidate_uniquity)
        return segment
    
    def isuniquefromroot(self, tree, element, segment):
        _, uniquity = self._resultcache[element]
        return uniquity >= MultipleAttributeMatcher._UNIQUE_FROM_ROOT
    
    def isuniquefromparent(self, tree, element, segment):
        _, uniquity = self._resultcache[element]
        return uniquity >= MultipleAttributeMatcher._UNIQUE_FROM_PARENT

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
            return self.getpath(element_or_attribute_or_attributeproxy.getparent()) + f'/@{attrname}'

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
                new_segment = matcher.getsegment(self._tree, curelement, segment)
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
    