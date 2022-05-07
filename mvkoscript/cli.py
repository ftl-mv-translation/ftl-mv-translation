from functools import reduce
import csv
import sys
import os
import click
import json5
import subprocess
from glob import glob
from pathlib import Path
from lxml import etree
from mvkoscript.xmltools import xpath, getpath, xmldiff, getsourceline, parse_illformed

FTL_NAMESPACES = ['mod']

def ensureparent(outputfilepath):
    Path(outputfilepath).parent.mkdir(parents=True, exist_ok=True)

def redirect_stdhandles_to_utf8():
    # pyinstaller ignores PYTHONIOENCODING; redirect them when freezed.
    sys.stdin = open(sys.stdin.fileno(), 'r', encoding='utf-8', closefd=False)
    sys.stdout = open(sys.stdout.fileno(), 'w', encoding='utf-8', closefd=False)
    sys.stderr = open(sys.stderr.fileno(), 'w', encoding='utf-8', closefd=False)

@click.group()
@click.option('--config', '-c', default='mvkoscript.config.jsonc', help='config file')
@click.pass_context
def main(ctx, config):
    ctx.ensure_object(dict)
    with open(config, encoding='utf-8') as f:
        ctx.obj['configpath'] = config
        ctx.obj['config'] = json5.load(f)
    
    if getattr(sys, 'frozen', False) and os.environ.get('PYTHONIOENCODING', None) == 'utf-8':
        redirect_stdhandles_to_utf8()
    
@main.command()
@click.argument('a')
@click.argument('b')
@click.option('--mismatch', '-m', default=10, help='show N mismatches')
@click.pass_context
def unhandled(ctx, a, b, mismatch):
    '''Find unhandled diff from two XML files.'''
    
    config = ctx.obj['config']
    stringSelectionXPath = config.get('stringSelectionXPath', [])

    atree = parse_illformed(a, FTL_NAMESPACES)
    btree = parse_illformed(b, FTL_NAMESPACES)

    excluded = reduce(
        lambda s1, s2: s1 | s2,
        (set(xpath(atree, xpathexpr)) for xpathexpr in stringSelectionXPath)
    )

    print('Comparing files...')
    diff = xmldiff(atree, btree)
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
@click.option('--location', '-l', default='', help='A location to file written in CSV')
@click.pass_context
def generate_csv(ctx, xml, output, prefix, location):
    '''
    Generate translate-toolkit compatible CSV file from XML.

    Usage: mvko generate-csv src-ko/data/blueprints.xml.append locale/data/blueprints.xml.append/ko.csv
    '''
    config = ctx.obj['config']
    stringSelectionXPath = config.get('stringSelectionXPath', [])

    location = location or xml

    print(f'Reading {xml}...')
    tree = parse_illformed(xml, FTL_NAMESPACES)
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
    print(f'Found {len(entities)} strings')
    print(f'Writing {output}...')
    ensureparent(output)
    with open(output, 'w', encoding='utf-8', newline='') as csvfile:
        # Using QUOTE_ALL because Weblate's CSV parser uses built-in csv.Sniffer which is incredibly unreliable.
        writer = csv.writer(csvfile, quoting=csv.QUOTE_ALL)
        writer.writerow(
            ['location', 'source', 'target', 'ID', 'fuzzy', 'context', 'translator_comments', 'developer_comments']
        )
        for entity in entities:
            key = f'{prefix}{getpath(tree, entity)}'
            if getattr(entity, 'value', None) is not None:
                # AttributeProxy
                value = getattr(entity, 'value')
            else:
                value = (getattr(entity, 'text') or '').strip()
            
            writer.writerow([
                # location
                f'{location}:{getsourceline(entity)}',
                # source
                key,
                # target
                value,
                # ID
                key,
                # fuzzy
                '',
                # context
                '',
                # translator_comments
                '',
                # developer_comments
                '',
            ])

@main.command()
@click.argument('original')
@click.argument('translated')
@click.pass_context
def empty_untranslated(ctx, original, translated):
    '''
    Given two CSV files, empty each string in the target CSV
    where its respective string in the source is exactly the same.

    Usage: mvko empty-untranslated locale/data/blueprints.xml.append/en.csv locale/data/blueprints.xml.append/ko.csv
    '''
    
    with open(original, encoding='utf-8') as originalfile:
        entries_original = list(csv.DictReader(originalfile))
    with open(translated, encoding='utf-8') as translatedfile:
        entries_translated = list(csv.DictReader(translatedfile))

    # Extract keys where string value are empty on both the orignal and the translated
    key_of_empty_strings_original = set(entry['source'] for entry in entries_original if entry['target'] == '')
    key_of_empty_strings_translated = set(entry['source'] for entry in entries_translated if entry['target'] == '')
    key_of_empty_strings_both = key_of_empty_strings_original & key_of_empty_strings_translated

    # Filter empty strings out
    # Rule: original removes all empty strings, and translated removes strings where BOTH are empty
    entries_original = [entry for entry in entries_original if entry['source'] not in key_of_empty_strings_original]
    entries_translated = [entry for entry in entries_translated if entry['source'] not in key_of_empty_strings_both]

    # Identical translations are removed out afterward
    dict_original = {entry['source']: entry['target'] for entry in entries_original}
    for entry in entries_translated:
        if entry['target'] == dict_original.get(entry['source'], None):
            entry['target'] = ''

    def write_csv(path, entries):
        with open(path, 'w', encoding='utf-8', newline='') as csvfile:
            # Using QUOTE_ALL because Weblate's CSV parser uses built-in csv.Sniffer which is incredibly unreliable.
            writer = csv.DictWriter(
                csvfile,
                fieldnames=[
                    'location', 'source', 'target', 'ID', 'fuzzy', 'context', 'translator_comments', 'developer_comments'
                ],
                quoting=csv.QUOTE_ALL
            )
            writer.writeheader()
            writer.writerows(entries)
    
    write_csv(original, entries_original)
    write_csv(translated, entries_translated)

def key_to_xpath(key):
    idx = key.find('$')
    if idx == -1:
        return key
    return key[idx + 1:]

@main.command()
@click.argument('inputxml')
@click.argument('originalcsv')
@click.argument('translatedcsv')
@click.argument('outputxml')
@click.pass_context
def apply_locale(ctx, inputxml, originalcsv, translatedcsv, outputxml):
    '''
    Apply locale CSV to XML, generating a translated XML file.

    Usage: mvko apply-locale src-en/data/blueprints.xml.append locale/data/blueprints.xml.append/en.csv
           locale/data/blueprints.xml.append/ko.csv output/data/blueprints.xml.append
    '''
    print(f'Reading {inputxml}...')
    tree = parse_illformed(inputxml, FTL_NAMESPACES)

    def csv_to_dict(path):
        with open(path, encoding='utf-8') as csvfile:
            return {entry['source']: entry['target'] for entry in csv.DictReader(csvfile)}

    original_entries = csv_to_dict(originalcsv)
    translated_entries = csv_to_dict(translatedcsv)
    
    untranslated_count = 0

    for key, value in original_entries.items():
        translation = translated_entries.get(key, None)
        if not value:
            print(f'WARNING: {key} is empty in csv (original).')
            if translation:
                print(f'         AND {key} is NON-EMPTY in csv (translation); This might indicate a problem.')
            continue
        
        if not translation:
            untranslated_count += 1
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

    print(f'#untranslated = {untranslated_count}')

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
@click.pass_context
def batch_bootstrap(ctx):
    '''
    Batch operation for bootstrapping.
    Assumes "src-en/" and "src-ko/" directory to be present. Generates "locale/" directory and "report.txt".

    Usage: mvko batch-bootstrap
    '''

    configpath = ctx.obj['configpath']
    config = ctx.obj['config']
    file_patterns = config.get('filePatterns', [])

    filepaths_en = [
        Path(path).as_posix()
        for file_pattern in file_patterns
        for path in glob(file_pattern, root_dir='src-en', recursive=True)
    ]
    filepaths_ko = [
        Path(path).as_posix()
        for file_pattern in file_patterns
        for path in glob(file_pattern, root_dir='src-ko', recursive=True)
    ]
    filepaths_either = sorted(
        set(filepaths_en) | set(filepaths_ko),
        key=(filepaths_en + filepaths_ko).index
    )

    with open('report.txt', 'w', encoding='utf-8', newline='\n') as reportfile:
        for filepath in filepaths_either:
            print(f'Processing {filepath}...')

            exists = {'en': filepath in filepaths_en, 'ko': filepath in filepaths_ko}
            csv_success = {'en': False, 'ko': False}

            # Generate csv for each language
            for lang in ('en', 'ko'):
                if exists[lang]:
                    csv_success[lang] = runproc(
                        f'Generating CSV file: {filepath}, {lang}',
                        reportfile, configpath,
                        'generate-csv', f'src-{lang}/{filepath}', f'locale/{filepath}/{lang}.csv',
                        '-p', f'{filepath}$', '-l', f'src-en/{filepath}'
                    )
            if csv_success['en'] and csv_success['ko']:
                # Empty untranslated strings
                runproc(
                    f'Emptying untranslated strings: {filepath}',
                    reportfile, configpath,
                    'empty-untranslated', f'locale/{filepath}/en.csv', f'locale/{filepath}/ko.csv'
                )
            if exists['en'] and exists['ko']:
                # Run diff report
                runproc(
                    f'Diff report: {filepath}',
                    reportfile, configpath,
                    'unhandled', f'src-en/{filepath}', f'src-ko/{filepath}', '-m', '20'
                )

@main.command()
@click.pass_context
def batch_en(ctx):
    '''
    Batch operation for English update.
    Assumes "src-en/" directory to be present. Updates "locale/" directory and "report.txt".

    Usage: mvko batch-en
    '''

    configpath = ctx.obj['configpath']
    config = ctx.obj['config']
    file_patterns = config.get('filePatterns', [])

    filepaths_en = [
        Path(path).as_posix()
        for file_pattern in file_patterns
        for path in glob(file_pattern, root_dir='src-en', recursive=True)
    ]

    for oldcsv in glob('locale/**/en.csv', recursive=True):
        Path(oldcsv).unlink()

    with open('report.txt', 'w', encoding='utf-8', newline='\n') as reportfile:
        for filepath in filepaths_en:
            print(f'Processing {filepath}...')

            # Generate csv for each language
            lang = 'en'
            csv_success = runproc(
                f'Generating CSV file: {filepath}, {lang}',
                reportfile, configpath,
                'generate-csv', f'src-{lang}/{filepath}', f'locale/{filepath}/{lang}.csv',
                '-p', f'{filepath}$', '-l', f'src-en/{filepath}'
            )
            if csv_success and Path(f'locale/{filepath}/ko.csv').exists():
                # Empty untranslated strings
                runproc(
                    f'Emptying untranslated strings: {filepath}',
                    reportfile, configpath,
                    'empty-untranslated', f'locale/{filepath}/en.csv', f'locale/{filepath}/ko.csv'
                )

@main.command()
@click.pass_context
def batch_apply(ctx):
    '''
    Batch operation for applying translation.
    Assumes "src-en/" and "locale/" directory to be present. Updates "output/" directory and "report.txt".

    Usage: mvko batch-apply
    '''

    configpath = ctx.obj['configpath']

    target_en = [
        Path(path).parent.as_posix()
        for path in glob('**/en.csv', root_dir='locale', recursive=True)
    ]
    target_ko = [
        Path(path).parent.as_posix()
        for path in glob('**/ko.csv', root_dir='locale', recursive=True)
    ]
    target_either = sorted(
        set(target_en) | set(target_ko),
        key=(target_en + target_ko).index
    )

    xmlbasepath_en = Path('src-en')
    csvbasepath = Path('locale')
    outputbasepath = Path('output')

    with open('report.txt', 'w', encoding='utf-8', newline='\n') as reportfile:
        for targetpath in target_either:
            print(f'Processing {targetpath}...')

            csvpath_en = csvbasepath / targetpath / 'en.csv'
            csvpath_ko = csvbasepath / targetpath / 'ko.csv'
            xmlpath = xmlbasepath_en / targetpath
            outputpath = outputbasepath / targetpath

            if not csvpath_en.exists():
                print('=> skipped: en.csv not found')
                continue
            if not csvpath_ko.exists():
                print('=> skipped: ko.csv not found')
                continue
            if not xmlpath.exists():
                print('=> skipped: XML not found')
                continue
            
            runproc(
                f'Applying translation: {targetpath}',
                reportfile, configpath,
                'apply-locale', str(xmlpath), str(csvpath_en), str(csvpath_ko), str(outputpath)
            )

if __name__ == '__main__':
    main()
