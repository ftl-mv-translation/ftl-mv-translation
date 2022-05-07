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
    # pyinstaller ignores PYTHONIOENCODING so we redirect them
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
    
    assert len(entries_original) == len(entries_translated)

    removelist_original = []
    removelist_translated = []
    
    for i, entry_original in enumerate(entries_original):
        entry_translated = entries_translated[i]

        if entry_original['target'] == '':
            removelist_original.append(i)
            if entry_translated['target'] == '':
                removelist_translated.append(i)
        elif entry_original['target'] == entry_translated['target']:
            entry_translated['target'] = ''
    
    for i in reversed(removelist_original):
        del entries_original[i]
    for i in reversed(removelist_translated):
        del entries_translated[i]
    
    with open(translated, 'w', encoding='utf-8', newline='') as translatedfile:
        # Using QUOTE_ALL because Weblate's CSV parser uses built-in csv.Sniffer which is incredibly unreliable.
        writer = csv.DictWriter(
            translatedfile,
            fieldnames=[
                'location', 'source', 'target', 'ID', 'fuzzy', 'context', 'translator_comments', 'developer_comments'
            ],
            quoting=csv.QUOTE_ALL
        )
        writer.writeheader()
        writer.writerows(entries_translated)

def key_to_xpath(key):
    idx = key.find('$')
    if idx == -1:
        return key
    return key[idx + 1:]

@main.command()
@click.argument('inputxml')
@click.argument('inputcsv')
@click.argument('outputxml')
@click.pass_context
def apply_locale(ctx, inputxml, inputcsv, outputxml):
    '''
    Apply locale CSV to XML, generating a translated XML file.

    Usage: mvko apply-locale src-en/data/blueprints.xml.append locale/data/blueprints.xml.append/ko.csv output/data/blueprints.xml.append
    '''
    print(f'Reading {inputxml}...')
    tree = parse_illformed(inputxml, FTL_NAMESPACES)
    
    with open(inputcsv, encoding='utf-8') as csvfile:
        entries = list(csv.DictReader(csvfile))
    
    for entry in entries:
        value = entry['target']
        if value == '':
            # Not yet translated: leave original text
            continue

        key = entry['source']
        xpathexpr = key_to_xpath(key)
        entities = xpath(tree, xpathexpr)

        if len(entities) == 0:
            print(f'Warning: XPath query yielded nothing: {key}.')
        elif len(entities) > 1:
            print(f'Warning: XPath query yielded multiple results: {key}.')
        else:
            entity = entities[0]
            if getattr(entity, 'value', None) is not None:
                # AttributeProxy
                setattr(entity, 'value', value)
            else:
                setattr(entity, 'text', value)
    
    result = etree.tostring(tree, encoding='utf-8', pretty_print=True)
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
    config = ctx.obj['config']
    file_patterns = config.get('filePatterns', [])

    filepaths_en = [
        Path(path).as_posix()
        for file_pattern in file_patterns
        for path in glob(file_pattern, root_dir='src-en', recursive=True)
    ]

    # TODO

    # with open('report.txt', 'w', encoding='utf-8', newline='\n') as reportfile:
    #     for filepath in filepaths_en:
    #         print(f'Processing {filepath}...')

    #         # Generate csv for each language
    #         lang = 'en'
    #         csv_success = runproc(
    #             f'Generating CSV file: {filepath}, {lang}',
    #             reportfile, configpath,
    #             'generate-csv', f'src-{lang}/{filepath}', f'locale/{filepath}/{lang}.csv',
    #             '-p', f'{filepath}$', '-l', f'src-en/{filepath}'
    #         )
    #         if csv_success and Path(f'locale/{filepath}/ko.csv').exists():
    #             # Empty untranslated strings
    #             runproc(
    #                 f'Emptying untranslated strings: {filepath}',
    #                 reportfile, configpath,
    #                 'empty-untranslated', f'locale/{filepath}/en.csv', f'locale/{filepath}/ko.csv'
    #             )

if __name__ == '__main__':
    main()
