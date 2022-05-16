from collections import defaultdict
import sys
import os
import click
import json5
import subprocess
from functools import reduce
from pathlib import Path
from lxml import etree
from mvlocscript.xmltools import (
    AttributeMatcher, MatcherBase, xpath, UniqueXPathGenerator, xmldiff, getsourceline, parse_illformed
)
from mvlocscript.fstools import ensureparent, simulate_pythonioencoding_for_pyinstaller, glob_posix
from mvlocscript.localeformats import (
    generate_pot, infer_sourcelocation, merge_pot, stringentries_to_dictionary, readpo, writepo, StringEntry
)

######################## FTLMV-SPECIFIC XML LOGICS ################################

FTL_XML_NAMESPACES = ['mod']

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

################################# CLI CODE ########################################

@click.group()
@click.option('--config', '-c', default='mvloc.config.jsonc', show_default=True, help='config file')
@click.pass_context
def main(ctx, config):
    simulate_pythonioencoding_for_pyinstaller()

    ctx.ensure_object(dict)
    with open(config, encoding='utf-8') as f:
        ctx.obj['configpath'] = config
        ctx.obj['config'] = json5.load(f)
    
@main.command()
@click.argument('a')
@click.argument('b')
@click.option('--mismatch', '-m', default=10, show_default=True, help='show N mismatches')
@click.pass_context
def unhandled(ctx, a, b, mismatch):
    '''Find unhandled diff from two XML files.'''
    
    config = ctx.obj['config']
    stringSelectionXPath = config.get('stringSelectionXPath', [])

    atree = parse_illformed(a, FTL_XML_NAMESPACES)
    btree = parse_illformed(b, FTL_XML_NAMESPACES)

    excluded = reduce(
        lambda s1, s2: s1 | s2,
        (set(xpath(atree, xpathexpr)) for xpathexpr in stringSelectionXPath)
    )

    print('Comparing files...')
    diff = xmldiff(atree, btree, matchers=ftl_xpath_matchers())
    print()
    print(f'#differences (all): {len(diff)}')
    diff = [(p, m) for p, m in diff if not excluded.issuperset(xpath(atree, p))]
    print(f'#differences (unhandled): {len(diff)}')
    print()
    for p, m in diff[:mismatch]:
        print(f'{p}: {m}')
    if len(diff) > mismatch:
        print()
        print(f'... and {len(diff) - mismatch} more diffs ...')

@main.command()
@click.argument('xml')
@click.argument('output')
@click.option('--prefix', '-p', default='', help='A prefix string for IDs')
@click.option('--location', '-l', default='', help='A location to the source file')
@click.pass_context
def generate(ctx, xml, output, prefix, location):
    '''
    Generate gettext .po file from XML.

    Example: mvloc generate src-ko/data/blueprints.xml.append locale/data/blueprints.xml.append/ko.po
    '''
    config = ctx.obj['config']
    stringSelectionXPath = config.get('stringSelectionXPath', [])

    location = location or xml

    print(f'Reading {xml}...')
    tree = parse_illformed(xml, FTL_XML_NAMESPACES)
    entities = reduce(
        lambda s1, s2: s1 | s2,
        (set(xpath(tree, xpathexpr)) for xpathexpr in stringSelectionXPath)
    )
    entities = sorted(
        entities,
        key=lambda entity: (
            getsourceline(entity),
            getattr(entity, 'tag', None) or getattr(entity, 'attrname', None)
        )
    )

    uniqueXPathGenerator = UniqueXPathGenerator(tree, ftl_xpath_matchers())

    def getkey(entity):
        path = uniqueXPathGenerator.getpath(entity)
        return f'{prefix}{path}'
    
    def getvalue(entity):
        if getattr(entity, 'value', None) is not None:
            # AttributeProxy
            return getattr(entity, 'value')
        else:
            return (getattr(entity, 'text') or '').strip()

    print(f'Found {len(entities)} strings')
    print(f'Writing {output}...')
    ensureparent(output)

    writepo(
        output,
        [StringEntry(getkey(entity), getvalue(entity), getsourceline(entity), False, False) for entity in entities],
        location
    )


@main.command()
@click.argument('original')
@click.argument('translated')
@click.option(
    '--empty-identical', '-e', is_flag=True, default=False,
    help='Empty each translated string if it is identical to the original.'
)
@click.pass_context
def sanitize(ctx, original, translated, empty_identical):
    '''
    Given two locale files, sanitize them to be properly flagged in Weblate.

    Example: mvloc sanitize --empty_identical locale/data/blueprints.xml.append/en.po locale/data/blueprints.xml.append/ko.po
    '''

    sourcelocation = infer_sourcelocation(original)
    assert sourcelocation

    entries_original = readpo(original)

    # Original: filter empty strings out
    key_of_empty_strings_original = set(entry.key for entry in entries_original if entry.value == '')
    entries_original = [entry for entry in entries_original if entry.key not in key_of_empty_strings_original]
    writepo(original, entries_original, sourcelocation)

    # Translated: apply original changes to translation as if invoking msgmerge
    pot = generate_pot(entries_original, sourcelocation)
    merge_pot(translated, pot)

    if empty_identical:
        # Translated: empty strings identical to their respective original string
        dict_original = stringentries_to_dictionary(entries_original)
        entries_translated = readpo(translated)

        def transform_entry(entry_translated):
            entry_original = dict_original.get(entry_translated.key)
            if (entry_original is not None) and (entry_original.value == entry_translated.value):
                return entry_translated._replace(value = '')
            return entry_translated

        entries_translated = [transform_entry(entry_translated) for entry_translated in entries_translated]
        writepo(translated, entries_translated, sourcelocation)

def key_to_xpath(key):
    idx = key.find('$')
    if idx == -1:
        return key
    return key[idx + 1:]

@main.command()
@click.argument('inputxml')
@click.argument('originalpo')
@click.argument('translatedpo')
@click.argument('outputxml')
@click.pass_context
def apply(ctx, inputxml, originalpo, translatedpo, outputxml):
    '''
    Apply locale to XML, generating a translated XML file.

    Example: mvloc apply src-en/data/blueprints.xml.append locale/data/blueprints.xml.append/en.po locale/data/blueprints.xml.append/ko.po output/data/blueprints.xml.append
    '''
    print(f'Reading {inputxml}...')
    tree = parse_illformed(inputxml, FTL_XML_NAMESPACES)

    entries_original = stringentries_to_dictionary(readpo(originalpo))
    entries_translated = stringentries_to_dictionary(entry for entry in readpo(translatedpo) if not entry.obsolete)
    
    for key, entry_original in entries_original.items():
        entry_translated = entries_translated.get(key, None)
        original = entry_original.value
        translation = entry_translated.value if entry_translated else None
        if not original:
            if translation:
                print(
                    f'WARNING: {key} is empty in original but NON-EMPTY, NON-OBSOLETE in target locale;'
                    ' This might indicate a problem.'
                )
            continue
        if not translation:
            continue

        xpathexpr = key_to_xpath(key)
        entities = xpath(tree, xpathexpr)

        if len(entities) == 0:
            print(f'WARNING: XPath query yielded nothing: {key}.')
        elif len(entities) > 1:
            print(f'WARNING: XPath query yielded multiple results: {key}.')
        else:
            entity = entities[0]
            if getattr(entity, 'value', None) is not None:
                # AttributeProxy
                setattr(entity, 'value', translation)
            else:
                setattr(entity, 'text', translation)
    
    result = etree.tostring(tree, encoding='utf-8', pretty_print=True)

    # This ugly hack makes XML ill-formed (by undefined namespace) but seems required for FTL to parse them correctly.
    # Note that `xmlns:mod="http://dummy/mod"` part is actually added by parse_illformed.
    result = result.replace(b'<FTL xmlns:mod="http://dummy/mod">', b'<FTL>')

    ensureparent(outputxml)
    with open(outputxml, 'wb') as outputfile:
        outputfile.write(result)

@main.command()
@click.argument('inputa')
@click.argument('inputb')
@click.argument('output')
@click.option(
    '--sanitize', '-s', 'sanitize_arg', default='',
    help='Run sanitize with a given original locale file.'
)
@click.option(
    '--empty-identical', '-e', is_flag=True, default=False,
    help='(Requires --sanitize) Empty each translated string from output if it is identical to the original.'
)
@click.option(
    '--criteria', '-c', default='!o!e:!o:vf', show_default=True,
    help='Specify the criteria of copying. See help for details.'
)
@click.option(
    '--copy-sourcelocation', '-l', is_flag=True, default=False,
    help='Allow merging locales from different sources, using the location from INPUTB.'
)
@click.pass_context
def merge(ctx, inputa, inputb, output, sanitize_arg, empty_identical, criteria, copy_sourcelocation):
    '''
    Copy translation from the first argument (A) to the second (B), writing out the third. All arguments are .po files.
    
    This command is designed for merging two translation files from the same language.
    If you want to merge changes from English to other languages, use `sanitize` command instead.

    ---

    --criteria limits the condition of entries and the attributes that are copied over. It's specified in `X:Y:Z` format,
    where X specifies the condition for the elements in INPUTA, Y specifies the condition for the elements in INPUTB,
    and Z specifies which attributes are copied over from INPUTA.
    
    X and Y are a combination of f (select entries) or !f (exclude entries) where f can be one of:

    o: obsolete entries, f: fuzzy entries, e: empty entries, n: new entries (i.e. entries which only exist in INPUTA)

    (Note: flag `n` can only be specified in X, not Y.)

    And Z is a combination of:

    v: the translated string, l: lineno, o: obsolete flag, f: fuzzy flag

    (Note: new entries will always be copied with line number and obsolete flag regardless of this option,
    as mvloc always requires a line number for non-obsolete entries.)

    The default setting is "!o!e:!o:vf", which copies all non-empty, non-obsolete entries from INPUTA to INPUTB,
    while preserving the line numbers and and obsolete flags in INPUTB.

    ---

    * Example 1: Merge a.ko.po with b.ko.po using default setting (copy translated strings from A to B)

    mvloc merge a.po b.po output.po
    
    * Example 1: Copy translated strings from A to B, but only if they're empty in B

    mvloc merge -s !o!e:!oe:vf a.po b.po output.po

    * Example 2: Merge entries using default setting, then sanitize the output (including emptying untranslated)

    mvloc merge --sanitize a.en.po --empty-identical a.ko.po b.ko.po output.ko.po

    * Example 3: Copy only new entries from A to B

    mvloc merge -c n::vlof a.po b.po output.po
    
    * Example 4: Mark each entry fuzzy in B if and only if it's fuzzy in A

    mvloc merge -c !n!o:-o:f a.po b.po output.po

    * Example 5: Create keys for new entries in B, but initialize them as empty (like msgmerge)

    mvloc merge -c n!o:: a.po b.po output.po

    * Example 6: Merge two files from different source XMLs, where A's source is integrated into B's

    mvloc merge --copy-sourcelocation -c ::vlof a.po b.po output.po
    '''

    def parse_criteria(criteria, keys_a, keys_b):
        CONDFUNCS = {
            'o': lambda entry: entry.obsolete,
            'f': lambda entry: entry.fuzzy,
            'e': lambda entry: entry.value == '',
            'n': lambda entry: (entry.key in keys_a) and (entry.key not in keys_b)
        }
        FIELDS = {
            'v': 'value',
            'l': 'lineno',
            'o': 'obsolete',
            'f': 'fuzzy'
        }

        def condfunc(condstr, exclude_n):
            ret = []
            while condstr:
                if condstr[0] == '!':
                    notflag = True
                    condchar = condstr[1]
                    condstr = condstr[2:]
                else:
                    notflag = False
                    condchar = condstr[0]
                    condstr = condstr[1:]
                if exclude_n and condchar == 'n':
                    raise RuntimeError('invalid criteria')
                f = CONDFUNCS.get(condchar, None)
                if f is None:
                    raise RuntimeError('invalid criteria')
                ret.append((notflag, f))
            return ret

        splits = criteria.split(':')
        if len(splits) != 3:
            print(criteria)
            raise RuntimeError('invalid criteria')
        
        cond_a, cond_b, copy_fields = splits
        condfunc_a = condfunc(cond_a, False)
        condfunc_b = condfunc(cond_b, False)
        copy_fields = [FIELDS[f] for f in copy_fields]
        return condfunc_a, condfunc_b, copy_fields

    def evaluate_cond(condfunc, entry):
        return all(f(entry) != n for n, f in condfunc)

    def copied(entry_a, entry_b, copy_fields):
        return entry_b._replace(**{field: getattr(entry_a, field) for field in copy_fields})

    ############################

    if empty_identical and not sanitize_arg:
        raise RuntimeError('--empty-identical works only if --sanitize is specified')

    sourcelocation_a = infer_sourcelocation(inputa)
    assert sourcelocation_a
    sourcelocation_b = infer_sourcelocation(inputb)
    assert sourcelocation_b

    if not copy_sourcelocation and (sourcelocation_a != sourcelocation_b):
        raise RuntimeError(
            f'sourcelocation mismatch: {sourcelocation_a} != {sourcelocation_b}.'
            ' Use --copy-sourcelocation to merge between locales of different sources.'
        )

    entries_a = readpo(inputa)
    entries_b = readpo(inputb)
    
    # Unify the sourcelocation
    if copy_sourcelocation:
        entries_a = [
            entry._replace(key=f'{sourcelocation_b}${entry.key[len(sourcelocation_a + 1):]}')
            for entry in entries_a
        ]
    
    dict_a = stringentries_to_dictionary(entries_a)
    dict_b = stringentries_to_dictionary(entries_b)
    condfunc_a, condfunc_b, copy_fields = parse_criteria(criteria, dict_a.keys(), dict_b.keys())

    stats_skipped, stats_added, stats_overwritten = 0, 0, 0
    for key, entry in dict_a.items():
        if not evaluate_cond(condfunc_a, entry):
            stats_skipped += 1
            continue
        is_entry_new = key not in dict_b
        if (not is_entry_new) and (not evaluate_cond(condfunc_b, dict_b[key])):
            stats_skipped += 1
            continue
        
        if is_entry_new:
            # Default for copying a new entry
            dest = StringEntry(key, '', entry.lineno, False, entry.obsolete)
            dest = copied(entry, dest, copy_fields)
            dict_b[key] = dest
            stats_added += 1
        else:
            dict_b[key] = copied(entry, dict_b[key], copy_fields)
            stats_overwritten += 1
    
    new_entries_b = sorted(dict_b.values(), key=lambda entry: entry.lineno)
    writepo(output, new_entries_b, sourcelocation_b)
    print(
        f'Stats: {stats_skipped} strings skipped, {stats_added} strings created'
        f' and {stats_overwritten} string overwritten.'
    )
    if sanitize_arg:
        print('Performing sanitization...')
        ctx.invoke(sanitize, original=sanitize_arg, translated=output, empty_identical=empty_identical)

def runproc(desc, reportfile, configpath, *args):
    newenv = dict(os.environ)
    executeargs = [sys.executable] if getattr(sys, 'frozen', False) else [sys.executable, sys.argv[0]]
    executeargs += ['-c', configpath]

    newenv['PYTHONIOENCODING']='utf-8'
    proc = subprocess.run(
        executeargs + list(args),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=newenv
    )
    result = proc.stdout.decode(encoding='utf-8', errors='replace').replace('\r', '')
    reportfile.write(
        f'---------------------\n{desc}\n({args})\nerrorcode {proc.returncode}\n---------------------\n{result}\n\n'
    )
    return proc.returncode == 0

@main.command()
@click.argument('targetlang')
@click.option(
    '--diff', '-d', is_flag=True, default=False, help='Write XML diff for unhandled rules in the report file.'
)
@click.option(
    '--clean', '-c', is_flag=True, default=False, help='Delete all <TARGETLANG>.po files from locale/ directory.'
)
@click.option(
    '--empty-identical', '-e', is_flag=True, default=False,
    help='Empty each translated string if it is identical to the original.'
)
@click.pass_context
def batch_generate(ctx, targetlang, diff, clean, empty_identical):
    '''
    Batch operation for bootstrapping.
    Assumes "src-en/" and "src-<TARGETLANG>/" directory to be present.
    Generates "locale/**/<TARGETLANG>.po" files and "report.txt" file.

    Example: mvloc batch-generate --diff --clean --empty-identical ko
    '''

    configpath = ctx.obj['configpath']
    config = ctx.obj['config']
    file_patterns = config.get('filePatterns', [])

    filepaths_en = [
        path
        for file_pattern in file_patterns
        for path in glob_posix(file_pattern, root_dir='src-en')
    ]
    filepaths_targetlang = [
        path
        for file_pattern in file_patterns
        for path in glob_posix(file_pattern, root_dir=f'src-{targetlang}')
    ]

    if clean:
        for oldlocale in glob_posix(f'locale/**/{targetlang}.po'):
            Path(oldlocale).unlink()
    
    with open('report.txt', 'w', encoding='utf-8', newline='\n') as reportfile:
        for filepath in filepaths_targetlang:
            print(f'Processing {filepath}...')

            # Generate locale
            success = runproc(
                f'Generating locale: {filepath}, {targetlang}',
                reportfile, configpath,
                'generate', f'src-{targetlang}/{filepath}', f'locale/{filepath}/{targetlang}.po',
                '-p', f'{filepath}$', '-l', f'src-en/{filepath}'
            )
            if not success:
                continue

            # Sanitize:
            # 1) if targetlang is en: apply sanitization to all translation
            # 2) otherwise: apply sanitization to one translation only
            en_locale = f'locale/{filepath}/en.po'
            if Path(en_locale).exists():
                sanitize_args = ['sanitize']
                if empty_identical:
                    sanitize_args.append('--empty-identical')
                sanitize_args.append(en_locale)

                if targetlang == 'en':
                    sanitize_targets = glob_posix(f'locale/{filepath}/*.po')
                    assert en_locale in sanitize_targets # We've just generated it

                    if len(sanitize_targets) == 1:
                        # English only: sanitize itself for empty string removal
                        pass
                    else:
                        sanitize_targets.remove(en_locale)
                else:
                    sanitize_targets = [f'locale/{filepath}/{targetlang}.po']
                
                for sanitize_target in sanitize_targets:
                    runproc(
                        f'Sanitizing locale: {filepath}, {sanitize_target}',
                        reportfile, configpath,
                        *sanitize_args, sanitize_target
                    )

            # Generate diff report
            if diff and (filepath in filepaths_en):
                # Run diff report
                runproc(
                    f'Diff report: {filepath}',
                    reportfile, configpath,
                    'unhandled', f'src-en/{filepath}', f'src-{targetlang}/{filepath}', '-m', '20'
                )

@main.command()
@click.argument('targetlang')
@click.pass_context
def batch_apply(ctx, targetlang):
    '''
    Batch operation for applying translation.
    Assumes "src-en/" and "locale/" directory to be present. Updates result to "output/" directory and "report.txt".

    Example: mvloc batch-apply ko
    '''

    configpath = ctx.obj['configpath']

    locale_en = [
        Path(path).parent.as_posix()
        for path in glob_posix('**/en.po', root_dir='locale')
    ]
    locale_targetlang = [
        Path(path).parent.as_posix()
        for path in glob_posix(f'**/{targetlang}.po', root_dir='locale')
    ]
    locale_either = sorted(
        set(locale_en) | set(locale_targetlang),
        key=(locale_en + locale_targetlang).index
    )

    xmlbasepath_en = Path('src-en')
    localebasepath = Path('locale')
    outputbasepath = Path('output') / targetlang

    with open('report.txt', 'w', encoding='utf-8', newline='\n') as reportfile:
        for targetpath in locale_either:
            print(f'Processing {targetpath}...')

            localepath_en = localebasepath / targetpath / 'en.po'
            localepath_targetlang = localebasepath / targetpath / f'{targetlang}.po'
            xmlpath = xmlbasepath_en / targetpath
            outputpath = outputbasepath / targetpath

            if not localepath_en.exists():
                print('=> skipped: en.po not found')
                continue
            if not localepath_targetlang.exists():
                print(f'=> skipped: {targetlang}.po not found')
                continue
            if not xmlpath.exists():
                print('=> skipped: XML not found')
                continue
            
            runproc(
                f'Applying translation: {targetpath}',
                reportfile, configpath,
                'apply', str(xmlpath), str(localepath_en), str(localepath_targetlang), str(outputpath)
            )

if __name__ == '__main__':
    main()
