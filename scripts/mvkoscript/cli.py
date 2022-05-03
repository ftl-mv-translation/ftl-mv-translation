from functools import reduce
import click
import json5
from lxml import etree
from .xmltools import xmldiff

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
    """Find unhandled diff from two XML files."""
    
    config = ctx.obj['config']
    stringSelectionXPath = config.get('stringSelectionXPath', [])

    atree = etree.parse(a)
    btree = etree.parse(b)

    excluded = reduce(
        lambda s1, s2: s1 | s2,
        (set(atree.xpath(xpath)) for xpath in stringSelectionXPath)
    )

    print('Comparing files...')
    diff = xmldiff(atree, btree)
    print()
    print(f'#differences (all): {len(diff)}')
    diff = [(p, m) for p, m in diff if not excluded.issuperset(atree.xpath(p))]
    print(f'#differences (unhandled): {len(diff)}')
    print()
    for p, m in diff[:mismatch]:
        print(f'{p}: {m}')

if __name__ == '__main__':
    main()