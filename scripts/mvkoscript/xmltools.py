from lxml import etree

def getpath(tree, element):
    # Similar to lxml.etree.ElementTree.getpath(), but use @name attribute instead of ordinal if available.
    path: str = tree.getpath(element)
    segments = path.split('/')

    newpath = ''
    for i, segment in enumerate(segments):
        if i == 0 and segment == '':
            # Initial "/"
            continue

        def next_newpath():
            xpath_ordinal = f'{newpath}/{segment}'

            if segment.find('[') == -1:
                # no []: just add the segment
                return xpath_ordinal

            xpath_ordinal_result = tree.xpath(xpath_ordinal)
            assert(len(xpath_ordinal_result) == 1)
            elem = xpath_ordinal_result[0]

            name = elem.get('name')
            if name is None:
                # no @name: just use ordinal as-is
                return xpath_ordinal

            xpath_name = f'{newpath}/{elem.tag}[@name="{name}"]'
            try:
                xpath_name_result = tree.xpath(xpath_name)
                if xpath_name_result == xpath_ordinal_result:
                    return xpath_name
            except etree.XPathEvalError:
                return xpath_ordinal
            
            return xpath_ordinal
        
        newpath = next_newpath()
    
    return newpath

def xmldiff(atree, btree):
    # Compare atree and btree
    
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
            differences.append((getpath(atree, aelem), f'tag differs: {aelem.tag} != {belem.tag}'))
        
        if normalized_text(aelem) != normalized_text(belem):
            differences.append(
                (getpath(atree, aelem), f'text differs: "{normalized_text(aelem)}" != "{normalized_text(belem)}"')
            )
        
        add_attribute_differences(getpath(atree, aelem), aelem.attrib, belem.attrib)

        iselement = lambda e: isinstance(e.tag, str) # non-comment checker
        achildren = list(filter(iselement, aelem))
        bchildren = list(filter(iselement, belem))
                
        if len(achildren) != len(bchildren):
            differences.append((getpath(atree, aelem), f'#children differs: {len(aelem)} != {len(belem)}'))
        else:
            for i in range(len(achildren)):
                add_differences(achildren[i], bchildren[i])
            
    add_differences(atree.getroot(), btree.getroot())
    return differences
