from functools import reduce
import csv
import click
import json5
from lxml import etree
from .xmltools import xpath, getpath, xmldiff, getsourceline

@click.group()
@click.option('--config', '-c', default='mvkoscript.config.jsonc', help='config file')
@click.pass_context
def main(ctx, config):
    ctx.ensure_object(dict)
    with open(config, encoding='utf-8') as f:
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

    atree = etree.parse(a)
    btree = etree.parse(b)

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

@main.command()
@click.argument('xml')
@click.argument('output')
@click.option('--prefix', '-p', default='', help='A prefix string for IDs')
@click.option('--location', '-l', default='', help='A location to file written in CSV')
@click.pass_context
def generate_csv(ctx, xml, output, prefix, location):
    '''Generate translate-toolkit compatible CSV file from XML'''
    config = ctx.obj['config']
    stringSelectionXPath = config.get('stringSelectionXPath', [])

    location = location or xml

    print(f'Reading {xml}...')
    tree = etree.parse(xml)
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


if __name__ == '__main__':
    main()