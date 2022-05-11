import sys
import os
import click
import json5
import subprocess
from functools import reduce
from pathlib import Path
from lxml import etree
from mvlocscript.xmltools import xpath, UniqueXPathGenerator, xmldiff, getsourceline, parse_illformed
from mvlocscript.fstools import ensureparent, simulate_pythonioencoding_for_pyinstaller, glob_posix
from mvlocscript.localeformats import (
    generate_pot, infer_sourcelocation, merge_pot, stringentries_to_dictionary, readpo, writepo, StringEntry
)

FTL_XML_NAMESPACES = ['mod']
FTL_XML_UNIQUE_ATTRIBUTES = ['name']

@click.group()
@click.option('--config', '-c', default='mvloc.config.jsonc', help='config file')
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
@click.option('--mismatch', '-m', default=10, help='show N mismatches')
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
    diff = xmldiff(atree, btree, FTL_XML_UNIQUE_ATTRIBUTES)
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

    Usage: mvloc generate src-ko/data/blueprints.xml.append locale/data/blueprints.xml.append/ko.po
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

    uniqueXPathGenerator = UniqueXPathGenerator(tree, FTL_XML_UNIQUE_ATTRIBUTES)

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

    Usage: mvloc sanitize --fuzzy locale/data/blueprints.xml.append/en.po locale/data/blueprints.xml.append/ko.po
    '''

    config = ctx.obj['config']
    stringSelectionXPath = config.get('stringSelectionXPath', [])

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

    Usage: mvloc apply src-en/data/blueprints.xml.append locale/data/blueprints.xml.append/en.po
           locale/data/blueprints.xml.append/ko.po output/data/blueprints.xml.append
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

    Usage: mvloc batch-generate --diff --clean --empty-identical ko
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

    Usage: mvloc batch-apply ko
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
