from glob import glob
import pickle
import shutil
import sys
import os
import subprocess
import tempfile
import click
import zipfile
import json5
import requests
from collections import defaultdict
from functools import reduce
from pathlib import Path
from loguru import logger
from mvlocscript.ftl import (
    apply_postprocess, ftl_xpath_matchers, handle_id_relocations, handle_same_string_updates, parse_ftlxml, write_ftlxml
)
from mvlocscript.update import TranslationMemory, generate_translation_memory
from mvlocscript.xmltools import (
    XPathInclusionChecker, xpath, UniqueXPathGenerator, xmldiff, getsourceline
)
from mvlocscript.fstools import ensureparent, simulate_pythonioencoding_for_pyinstaller, glob_posix
from mvlocscript.potools import parsekey, readpo, writepo, StringEntry

logger.remove()
logger.add(sys.stderr, format=(
    '<level>{level: <8}</level> |'
    ' <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>'
))

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
@click.option('--mismatch', '-m', default=10, show_default=True, help='Show N mismatches at most.')
@click.pass_context
def unhandled(ctx, a, b, mismatch):
    '''
    Find unhandled diff from two XML files.


    Usage notes:

    * Use when you have a translated XML file to be ported to mvloc. This command shows which "differences" will be
    ignored by the `generate` command in the current ruleset defined in the config file.


    Example: mvloc unhandled src-en/data/blueprints.xml.append src-ko/data/blueprints.xml.append --mismatch 20
    '''

    config = ctx.obj['config']
    stringSelectionXPath = config.get('stringSelectionXPath', [])

    atree = parse_ftlxml(a)
    btree = parse_ftlxml(b)

    checker = XPathInclusionChecker(atree, stringSelectionXPath)

    print('Comparing files...')
    diff = xmldiff(atree, btree, matchers=ftl_xpath_matchers())
    print()
    print(f'#differences (all): {len(diff)}')
    diff = [(p, m) for p, m in diff if not checker.contains(p)]
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
@click.option('--prefix', '-p', required=True, type=str, help='A prefix string for IDs.')
@click.option('--location', '-l', required=True, type=str, help='A location to the source file.')
@click.option(
    '--prune-empty-strings', '-r', is_flag=True, default=False,
    help='Remove empty strings from the generated locale.'
)
@click.option(
    '--delete-identical-strings-with', '-d', default='',
    help='Specify the original locale to delete entries with string identical to their original counterpart.'
)
@click.pass_context
def generate(ctx, xml, output, prefix, location, prune_empty_strings, delete_identical_strings_with):
    '''
    Generate a gettext .po file from an XML file.


    Usage notes:

    * Use `{filename}$` for `--prefix` and `src-en/{filename}` for ``--location``. This scheme is pretty much assumed
    in any other commands.

    * `--prune-empty-string` is best used for generating .po files for the original locale (i.e. English).

    * `--delete-identical-strings-with` is best used when followed by `sanitize` call to recover the deleted entries.


    Example: mvloc generate src-en/data/blueprints.xml.append locale/data/blueprints.xml.append/en.po --prefix "data/blueprints.xml.append$" --location "data/blueprints.xml.append" --prune-empty-strings
    '''
    config = ctx.obj['config']
    stringSelectionXPath = config.get('stringSelectionXPath', [])

    print(f'Reading {xml}...')
    tree = parse_ftlxml(xml)
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

    print(f'Found {len(entities)} strings')
    print(f'Writing {output}...')
    ensureparent(output)

    def getkey(entity):
        path = uniqueXPathGenerator.getpath(entity)
        return f'{prefix}{path}'

    def getvalue(entity):
        if getattr(entity, 'value', None) is not None:
            # AttributeProxy
            return getattr(entity, 'value')
        else:
            return (getattr(entity, 'text') or '').strip()

    entries = (
        StringEntry(getkey(entity), getvalue(entity), getsourceline(entity), False, False)
        for entity in entities
    )
    if prune_empty_strings:
        entries = (entry for entry in entries if entry.value != '')

    if delete_identical_strings_with:
        dict_original, _, _ = readpo(delete_identical_strings_with)
        def is_identical(dict_original, entry):
            entry_original = dict_original.get(entry.key, None)
            return (
                (entry_original is not None)
                and (entry_original.value == entry.value)
                and (entry_original.fuzzy == entry.fuzzy)
            )

        entries = (entry for entry in entries if not is_identical(dict_original, entry))

    writepo(output, entries, location)

@main.command()
@click.argument('target')
@click.option(
    '--original-xml', '-x', default='',
    help='Path to the XML for the original locale.'
         ' Required if the config specifies copySourceTemplate for the target language.'
)
@click.option('--original-po', '-p', required=True, type=str, help='Path to the .po file for the original locale.')
@click.option(
    '--targetlang', '-t', default='',
    help='The language of target.'
         ' The copySourceTemplate configuration will be applied only when this option is specified.'
)
@click.pass_context
def sanitize(ctx, target, original_xml, original_po, targetlang):
    '''
    Sanitize a translated .po file for a new translation. In details,

    * Add new entries, or mark existing entries obsolete so that its non-obsolete catalog matches to that of the
    original .po file.

    * Obsolete entries are deleted if the string is empty.

    * By default new entries are set to an empty string. If `--targetlang` and `--original-xml` is specified, and
    `copySourceTemplate` rule is specified for the target language, then each new entry is copied from its source
    counterpart as long as it matches to the rule.


    Usage notes:

    * Use this command to postprocess a newly generated translation. For updating translation, use `update` command
    instead which supports 3-way merging.

    * Original (English) files do not need to be sanitized by this command. Just use `generate` command with
    `--prune-empty-string` instead, regardless of whether the file is new or updated.

    * This command covers pretty much what `msgmerge` command does in the gettext package.


    Example: mvloc sanitize locale/data/blueprints.xml.append/ko.po --original-xml src-en/data/blueprints.xml.append --original-po locale/data/blueprints.xml.append/en.po --targetlang ko
    '''

    def get_copy_source_checker(config, targetlang, xmlpath):
        if not targetlang:
            return None
        template = config.get('languageSpecifics', {}).get(targetlang, {}).get('copySourceTemplate', [])
        if not template:
            return None

        if not xmlpath:
            raise RuntimeError('copySourceTemplate detected but --original-xml is not specified.')
        return XPathInclusionChecker(parse_ftlxml(xmlpath), template)

    config = ctx.obj['config']
    copy_source_checker = get_copy_source_checker(config, targetlang, original_xml)

    dict_original, _, sourcelocation = readpo(original_po)
    assert sourcelocation
    # Extract non-obsolete entries only, though this is likely a redundant step in mvloc
    # since English files are not supposed to have obsolete entries at all.
    dict_original = {k: v for k, v in dict_original.items() if not v.obsolete}
    dict_translated, _, _ = readpo(target)

    dict_new = {}

    for key, entry_original in dict_original.items():
        entry_translated = dict_translated.get(key, None)
        if (entry_translated is None) or entry_translated.obsolete:
            # A new entry
            _, xpathexpr = parsekey(key)
            if copy_source_checker and copy_source_checker.contains(xpathexpr):
                # Copy the string as-is
                dict_new[key] = entry_original
            else:
                # Add as an empty string
                dict_new[key] = entry_original._replace(value='', fuzzy=False)
        else:
            # An existing entry
            dict_new[key] = entry_original._replace(value=entry_translated.value, fuzzy=entry_translated.fuzzy)

    for key, entry_translated in dict_translated.items():
        if key in dict_new:
            continue

        if entry_translated.value == '':
            # Empty obsolete entries are not really useful in any sense
            continue

        # A deleted entry
        dict_new[key] = entry_translated._replace(lineno=-1, obsolete=True)

    # dict_new is already sorted as dict_original is. The rest (deleted entries) are obsoleted.
    writepo(target, dict_new.values(), sourcelocation)

@main.command()
@click.argument('oldoriginal')
@click.argument('neworiginal')
@click.argument('target')
@click.option(
    '--new-original-xml', '-x', default='',
    help='Path to the XML for the original locale.'
         ' Required if the config specifies copySourceTemplate for the target language.'
)
@click.option(
    '--targetlang', '-t', default='',
    help='The language of target.'
         ' The copySourceTemplate configuration will be applied only when this option is specified.'
)
@click.option(
    '--id-relocation-strategy', '-i', default='',
    help='An algorithm used for ID relocation.'
)
@click.pass_context
def update(ctx, oldoriginal, neworiginal, target, new_original_xml, targetlang, id_relocation_strategy):
    '''
    Perform 3-way merging on a translated .po file to apply changes from the original locale. In specific,

    * ID relocation are detected and applied.

    * Updates to the same-strings are applied.

    There are multiple number of available ID relocation strategies that can be choosed by `--id-relocation-strategy`:
    `lld`, `gs`, `gsa`, and `elm`.

    * `lld` (least lineno difference): Match each old and new entries as long as their string are identical.
    If there are multiple of such entries, use a translation whose lineno is closest to the changed lineno.
    The matching is greedy.

    * `gs` (group substitution): Match each old and new entries as long as their string are identical.
    If there are multiple of such entries, check if:
    
    1) The translated strings are consistent, i.e. ALL the translated strings whose source string
    matches to that of the relocated entry are identical.

    2) There are no potential `new` entries, i.e. the number of entries whose source string
    matches to that of the relocated entry is no more than that of the old ones.
    
    If they are, use them. Otherwise, matching fails for those entries.

    * `gsa` (group substitution, aggressive): A variant of `gs`. It relieves the condition by not requiring
    the consistency of translation among the unchanged entries in the source. It only checks consistency for translation
    of the old entries that are potentially relocated, i.e. changed or removed.

    * `elm` (exact lineno matching): Match 1:1 from old to new entries in order of appearance. Fails if there are
    difference in the number of entries between old and new, or their lineno differs.


    Usage notes:

    * Use this command to apply changes from an original (English) file to a translated file.

    * ID relocation strategies
    
    - `gs` is the default and the most conservative strategy. It performs each relocation only if it is likely there are
    no ambiguity in translation. `gsa` is similar but might recover some more by narrowing the definition of ambiguity.

    - `lld` is quirky in that it tries to match lineno in a greedy manner. It's the best strategy if the content is
    inserted or deleted at the end of the file.

    - `elm` is best used when the content did not change but there's a difference in ID generation algorithm.


    Example: mvloc update locale/data/blueprints.xml.append/en.po.old locale/data/blueprints.xml.append/en.po locale/data/blueprints.xml.append/ko.po --original-xml src-en/data/blueprints.xml.append --targetlang ko --id-relocation-strategy gsa
    '''

    print('Reading files...')
    
    dict_oldoriginal, _, sourcelocation = readpo(oldoriginal)
    dict_neworiginal, _, _ = readpo(neworiginal)
    dict_target, _, _ = readpo(target)

    assert sourcelocation

    if id_relocation_strategy:
        print('Handling ID relocations...')
        dict_target = handle_id_relocations(dict_oldoriginal, dict_neworiginal, dict_target, id_relocation_strategy)
    
    print('Handling same-string updates...')
    dict_target = handle_same_string_updates(dict_oldoriginal, dict_neworiginal, dict_target)
    
    print('Sorting...')
    entries_target = sorted(dict_target.values(), key=lambda entry: entry.lineno)
    
    print('Writing...')
    writepo(target, entries_target, sourcelocation)

    # Pass to sanitize for the rest
    print('Sanitizing...')
    ctx.invoke(
        sanitize,
        target=target,
        original_xml=new_original_xml,
        original_po=neworiginal,
        targetlang=targetlang
    )


@main.command()
@click.argument('inputxml')
@click.argument('originalpo')
@click.argument('translatedpo')
@click.argument('outputxml')
@click.option(
    '--targetlang', '-t', default='',
    help='The language of target.'
         ' Some configuration will be applied only when this option is specified.'
)
@click.pass_context
def apply(ctx, inputxml, originalpo, translatedpo, outputxml, targetlang):
    '''
    Apply locale to XML, generating a translated XML file.

    Example: mvloc apply src-en/data/blueprints.xml.append locale/data/blueprints.xml.append/en.po locale/data/blueprints.xml.append/ko.po output-ko/data/blueprints.xml.append
    '''

    if targetlang:
        config = ctx.obj['config']
        perLanguageSettings = config.get('languageSpecifics', {}).get(targetlang, {})
    else:
        perLanguageSettings = {}
    
    postprocesses = perLanguageSettings.get('applyPostprocesses', {})
    use_fuzzy = perLanguageSettings.get('applyUseFuzzy', False)

    print(f'Reading {inputxml}...')
    tree = parse_ftlxml(inputxml)

    dict_original, _, _ = readpo(originalpo)
    dict_translated, _, _ = readpo(translatedpo)
    dict_translated = {key: entry for key, entry in dict_translated.items() if not entry.obsolete}

    # Use keys from the original locale
    for key in dict_original:
        entry_translated = dict_translated.get(key, None)
        if (not entry_translated) or ((not use_fuzzy) and entry_translated.fuzzy):
            continue
        string_translated = entry_translated.value
        if not string_translated:
            continue

        _, xpathexpr = parsekey(key)
        entities = xpath(tree, xpathexpr)

        if len(entities) == 0:
            print(f'WARNING: XPath query yielded nothing: {key}.')
        elif len(entities) > 1:
            print(f'WARNING: XPath query yielded multiple results: {key}.')
        else:
            entity = entities[0]
            if getattr(entity, 'value', None) is not None:
                # AttributeProxy
                setattr(entity, 'value', string_translated)
            else:
                setattr(entity, 'text', string_translated)

    for postprocess, arg in postprocesses.items():
        apply_postprocess(tree, Path(outputxml).as_posix(), postprocess, arg)

    ensureparent(outputxml)
    write_ftlxml(outputxml, tree)

@main.command()
@click.argument('inputa')
@click.argument('inputb')
@click.argument('output')
@click.option(
    '--criteria', '-c', default='!o!e:!o:vf', show_default=True,
    help='Specify the criteria of copying. See help for details.'
)
@click.option(
    '--copy-sourcelocation', '-l', is_flag=True, default=False,
    help='Allow merging locales from different sources, using the prefix and source location from INPUTB.'
)
@click.pass_context
def merge(ctx, inputa, inputb, output, criteria, copy_sourcelocation):
    '''
    Copy translation from the first argument (A) to the second (B), writing out the third. All arguments are .po files.

    This command is designed for merging two translation files from the same language.
    If you want to merge changes from English to other languages, use `sanitize` command instead.

    ---

    --criteria limits the condition of entries and the attributes that are copied over. It's specified in `X:Y:Z`
    format, where X specifies the condition for the elements in INPUTA, Y specifies the condition for the elements
    in INPUTB, and Z specifies which attributes are copied over from INPUTA.

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


    Usage notes:

    * Sanitizing the merge result is strongly recommended for any non-trivial merges.


    Examples:

    * Example 1: Merge a.po with b.po using default setting (copy translated strings from A to B)

    mvloc merge a.po b.po output.po

    * Example 2: Copy translated strings from A to B, but only if they're empty in B

    mvloc merge -c !o!e:!oe:vf a.po b.po output.po

    * Example 3: Copy only new entries from A to B

    mvloc merge -c n::vlof a.po b.po output.po

    * Example 4: Mark each entry fuzzy in B if and only if it's fuzzy in A

    mvloc merge -c !n!o:!o:f a.po b.po output.po

    * Example 5: Create keys for new entries in B, but initialize them as empty

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

    dict_a, prefix_a, sourcelocation_a = readpo(inputa)
    dict_b, prefix_b, sourcelocation_b = readpo(inputb)

    assert prefix_a and sourcelocation_a and prefix_b and sourcelocation_b

    if not copy_sourcelocation and ((sourcelocation_a != sourcelocation_b) or (prefix_a != prefix_b)):
        raise RuntimeError(
            f'prefix/sourcelocation mismatch. Use --copy-sourcelocation to merge between locales of different sources.'
        )

    # Unify the prefix
    if copy_sourcelocation:
        dict_a_new = {}
        for entry in dict_a.values():
            _, xpathexpr = parsekey(entry.key)
            newkey = f'{prefix_b}{xpathexpr}'
            dict_a_new[newkey] = entry._replace(key=newkey)
        dict_a = dict_a_new

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
    ensureparent(output)
    writepo(output, new_entries_b, sourcelocation_b)
    print(
        f'Stats: {stats_skipped} strings skipped, {stats_added} strings created'
        f' and {stats_overwritten} string overwritten.'
    )

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
    '--clean', '-c', is_flag=True, default=False,
    help='Delete all <TARGETLANG>.po files from locale/ directory before running.'
)
@click.option(
    '--update', '-u', 'update_mode', is_flag=True, default=False, help='Run in update mode.'
)
@click.option(
    '--id-relocation-strategy', '-i', default='gs', show_default=True,
    help='An algorithm used for ID relocation in update mode. See help for `update` command for more information.'
)
@click.pass_context
def batch_generate(ctx, targetlang, diff, clean, update_mode, id_relocation_strategy):
    '''
    Batch operation for bootstrapping (for translation) and updating (for original).
    Assumes `src-en/` and `src-<TARGETLANG>/` directory to be present.
    Generates `locale/**/<TARGETLANG>.po` files and `report.txt` file.

    `--update` mode is only available when `TARGETLANG` is `en`. It invokes the `update` command instead of `sanitize`
    after generating the English locale so that each translation can be updated with 3-way merging strategy.


    Usage notes:

    * Use `--diff` to inspect if there are changes in raw XML files missing in the generated locale files. If needed,
    change the rules in the config file and try again.

    * Use `--clean` when constructing a whole new language locale from a set of raw XMLs. Conversely, omit `--clean` to
    import only a subset of XML files in `src-<TARGETLANG>/`.

    * Use `--update` when upgrading a Multiverse version. The `--update` option alters the postprocessing command used
    for syncing each translation file to the English changes, from the `sanitize` command to the `update` command.
    Though `sanitize` command still generates a valid output, it lacks smarter 3-way merge features like ID relocation
    and identical string updates, which may lead to more translation losses and more handwork.
    (Weblate is capable of alleviating a huge amount of such issues, but it still requires manual fixes in the end)

    A rough (and barely accurate) metaphor is that invoking without `--update` works like invoking the `msgmerge` tool
    with pot files, where `--update` works more like a `pretranslate` tool from the translate-toolkit package without
    fuzzy matching.


    Examples:

    * Example 1: Bootstrapping a whole new Korean translation from raw translated XML files located in `src-ko/`.

    mvloc batch-generate --diff --clean ko

    * Example 2: Importing some raw XML files located in `src-ko/` into existing Korean translation.

    mvloc batch-generate --diff ko

    * Example 3: Creating English locale from scratch

    mvloc batch-generate --clean en

    * Example 4: Updating English locale (and thus updating all other languages in the process)

    mvloc batch-generate --update --clean en

    * Example 5: Updating only specific English XML files in `src-en/`

    mvloc batch-generate --update en
    '''

    if update_mode and (targetlang != 'en'):
        raise RuntimeError('--update can only be used when TARGETLANG is "en".')

    configpath = ctx.obj['configpath']
    config = ctx.obj['config']
    filePatterns = config.get('filePatterns', [])

    filepaths_xml_en = [
        path
        for file_pattern in filePatterns
        for path in glob_posix(file_pattern, root_dir='src-en')
    ]
    filepaths_xml_targetlang = [
        path
        for file_pattern in filePatterns
        for path in glob_posix(file_pattern, root_dir=f'src-{targetlang}')
    ]

    if update_mode:
        # Delete all en.po.old if remaining
        for oldlocale in glob_posix(f'locale/**/{targetlang}.po.old'):
            Path(oldlocale).unlink()

        # Then rename all en.po to en.po.old
        for oldlocale in glob_posix(f'locale/**/{targetlang}.po'):
            path = Path(oldlocale)
            path.rename(path.parent / f'{targetlang}.po.old')
    elif clean:
        # Just delete all {targetlang}.po if remaining
        for oldlocale in glob_posix(f'locale/**/{targetlang}.po'):
            Path(oldlocale).unlink()

    try:
        with open('report.txt', 'w', encoding='utf-8', newline='\n', buffering=1) as reportfile:
            for filepath in filepaths_xml_targetlang:
                print(f'Processing {filepath}...')

                en_locale = f'locale/{filepath}/en.po'

                # Generate locale
                if targetlang == 'en':
                    generate_postprocess_args = ['-r']
                elif Path(en_locale).exists():
                    generate_postprocess_args = ['-d', en_locale]
                else:
                    generate_postprocess_args = []
                success = runproc(
                    f'Generating locale: {filepath}, {targetlang}',
                    reportfile, configpath,
                    'generate', f'src-{targetlang}/{filepath}', f'locale/{filepath}/{targetlang}.po',
                    '-p', f'{filepath}$', '-l', f'src-en/{filepath}', *generate_postprocess_args
                )
                if not success:
                    continue

                # Sync phase: sanitize / update
                if Path(en_locale).exists():
                    en_old_locale = f'locale/{filepath}/en.po.old'
                    en_xml_missing_warning_shown = False

                    if targetlang == 'en':
                        # Sync every other translation
                        command_targets = glob_posix(f'locale/{filepath}/*.po')
                        command_targets.remove(en_locale)
                    else:
                        # Sync the generated language only
                        command_targets = [f'locale/{filepath}/{targetlang}.po']

                    for command_target in command_targets:
                        if update_mode and Path(en_old_locale).exists():
                            command_title = 'Updating locale: %s'
                            command_args = [
                                'update', en_old_locale, en_locale, command_target, '-i', id_relocation_strategy
                            ]
                            assert targetlang == 'en'
                        else:
                            command_title = 'Sanitizing locale: %s'
                            command_args = ['sanitize', command_target, '-p', en_locale]

                        # Both sanitize and update shares -x and -t usage
                        if filepath not in filepaths_xml_en:
                            if not en_xml_missing_warning_shown:
                                print(
                                    f'WARNING: {filepath}: en.po exists but the XML file is missing from src-en/.'
                                    ' copySourceTemplate settings will NOT be applied.'
                                )
                                en_xml_missing_warning_shown = True
                        else:
                            command_args += ['-x', f'src-en/{filepath}', '-t', Path(command_target).stem]

                        runproc(
                            command_title % command_target,
                            reportfile, configpath,
                            *command_args
                        )

                # Generate a diff report
                if diff and (filepath in filepaths_xml_en):
                    # Run diff report
                    runproc(
                        f'Diff report: {filepath}',
                        reportfile, configpath,
                        'unhandled', f'src-en/{filepath}', f'src-{targetlang}/{filepath}', '-m', '20'
                    )
    finally:
        if update_mode:
            for oldlocale in glob_posix(f'locale/**/{targetlang}.po.old'):
                oldpath = Path(oldlocale)
                if clean:
                    # Delete all en.po.old
                    Path(oldlocale).unlink()
                else:
                    # Rename all en.po.old back to en.po unless overwriting newly created ones.
                    newpath = oldpath.parent / f'{targetlang}.po'
                    if newpath.exists():
                        oldpath.unlink()
                    else:
                        oldpath.rename(newpath)


@main.command()
@click.argument('targetlang')
@click.pass_context
def batch_apply(ctx, targetlang):
    '''
    Batch operation for applying translation.
    Assumes "src-en/" and "locale/" directory to be present.
    Updates result to "output-<TARGETLANG>/" directory and "report.txt".

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
    outputbasepath = Path(f'output-{targetlang}')

    with open('report.txt', 'w', encoding='utf-8', newline='\n', buffering=1) as reportfile:
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
                'apply', str(xmlpath), str(localepath_en), str(localepath_targetlang), str(outputpath),
                '-t', targetlang
            )

@main.command()
@click.argument('targetlang')
@click.pass_context
def stats(ctx, targetlang):
    '''
    Show brief stats for the number of translated strings.

    Example: mvloc stats ko
    '''

    locale_en = [
        Path(path).parent.as_posix()
        for path in glob_posix('**/en.po', root_dir='locale')
    ]
    locale_targetlang = [
        Path(path).parent.as_posix()
        for path in glob_posix(f'**/{targetlang}.po', root_dir='locale')
    ]

    print(f'Number of files: {len(locale_targetlang)} / {len(locale_en)}')
    if set(locale_en) != set(locale_targetlang):
        print(f'Missing: {", ".join(set(locale_en) - set(locale_targetlang))}')
    print()

    stats = defaultdict(int) # key: (obsolete, empty, fuzzy)

    for path in locale_targetlang:
        dict_entries, _, _ = readpo(f'locale/{path}/{targetlang}.po')
        for entry in dict_entries.values():
            stats[(entry.obsolete, entry.value == '', entry.fuzzy)] += 1
    
    total = sum(stats.values())
    if total == 0:
        print('No translation found.')
        return
    
    print('*' + '-' * 42 + '*')
    for i in range(8):
        columnname = ('Obsolete' if i & 4 else '') + ('Empty' if i & 2 else '') + ('Fuzzy' if i & 1 else '')
        if columnname == '': columnname = 'Translated'
        
        count = stats[(bool(i & 4), bool(i & 2), bool(i & 1))]
        print('| {:>20} | {:<7} ({:5.1f} %) |'.format(columnname, count, count / total * 100))
    print('*' + '-' * 42 + '*')
    print('| {:>20} | {:<7} ({:5.1f} %) |'.format("Total", total, 100))
    print('*' + '-' * 42 + '*')

@main.command()
@click.argument('targetlang')
@click.pass_context
def package(ctx, targetlang):
    '''
    Package translated XMLs into a full mod.
    Assumes "output-<TARGETLANG>/" and optionally "auxfiles-<TARGETLANG>/" directory to be present.
    Creates "packages/FTL-Multiverse-<VERSION>-<TARGETLANG>+<GITCOMMITID>.zip" where,

    * `<VERSION>` denotes the version of Multiverse as specified in configuration.
    * If `git` command is available, `<GITCOMMITID>` denotes the git commitid. Otherwise it's `xxxxxxx`.
    
    Example: mvloc package ko
    '''

    def get_gitcommitid():
        try:
            return subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).decode().strip()
        except:
            print('WARNING: failed to fetch git commitid. Using xxxxxxx as replacement.')
            return 'xxxxxxx'

    def write_directories_into_zip(zipf, target_directories):
        writelist = {}
        for pathbase in target_directories:
            pathbase = Path(pathbase)
            writelist.update({
                path: pathbase / path
                for path in glob_posix('**', root_dir=pathbase)
            })

        for arcname, path in writelist.items():
            zipf.write(path, arcname=arcname)

    def download(url, dst):
        try:
            tmppath = Path(f'{dst}.downloading')
            ensureparent(tmppath)

            req = requests.get(url, stream=True)
            with tmppath.open('wb') as f:
                for chunk in req.iter_content(chunk_size=128):
                    f.write(chunk)
            
            Path(dst).unlink(missing_ok=True)
            tmppath.rename(dst)
        except:
            tmppath.unlink(missing_ok=True)
            raise

    config = ctx.obj['config']
    urls = config['packaging']['fullOriginal']
    version = config['packaging']['version']

    original_paths = []
    for idx, url in enumerate(urls):
        original_path = Path(f'.cache/{version}-file{idx}.ftl')
        if not original_path.exists():
            print(f'Downloading {url} to {original_path}...')
            download(url, original_path)
        original_paths.append(original_path)

    # Extract files
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as extracted_pathbase:
        print('Extracting source...')
        for original_path in original_paths:
            with zipfile.ZipFile(original_path) as zipf:
                zipf.extractall(path=extracted_pathbase)
        
        translated_path = Path(
            f'packages/FTL-Multiverse-{version}-{targetlang}+{get_gitcommitid()}.ftl'
        )
        working_path = Path(f'{str(translated_path)}.working')

        ensureparent(working_path)
        try:
            with zipfile.ZipFile(working_path, 'w') as zipf:
                print(f'Assembling {translated_path}...')
                
                target_directories = [extracted_pathbase, f'output-{targetlang}']
                auxfiles_pathbase = f'auxfiles-{targetlang}'
                if Path(auxfiles_pathbase).is_dir():
                    target_directories.append(auxfiles_pathbase)
                
                write_directories_into_zip(zipf, target_directories)
            
            translated_path.unlink(missing_ok=True)
            working_path.rename(translated_path)
        except:
            working_path.unlink(missing_ok=True)
            raise


@main.command()
@click.option(
    '--first-pass', is_flag=True, default=False,
    help='Perform the first pass of the major update.'
)
@click.option(
    '--second-pass', is_flag=True, default=False,
    help='Perform the second pass of the major update.'
)
@click.pass_context
def major_update(ctx, first_pass, second_pass):
    '''
    Perform a major update.

    `--first-pass` and `--second-pass` are mutually exclusive options. Each pass should be done separately, and each
    result should be pushed onto Weblate separately to catch the difference created by the fuzzy string relocation.

    Usage notes:
    
    * Updating with global relocation is a 9-step process:
    
    \b
    1. Create a global translation memory from the old locale.
    2. Bootstrap a new set of original (en.po.new).
    3. Perform relocation on en.po. Do NOT update the string value if changed.
    4. Perform relocation on other *.po files.
    5. -- Push to repo, then update -> force sync from weblate --
    6. Perform same-string update.
    7. Sanitize.
    8. Replace en.po.new to en.po, updating every changes.
    9. -- Push to repo, then update -> force sync from weblate --

    The `--first-pass` option handles 1-4 and the `--second-pass` handles 6-8 respectively.
    The repo must be pushed twice, and each push must be visible to Weblate as a separate push.
    This way Weblate can show which change happened for fuzzy matches.

    Example: mvloc major-update --first-pass
    '''

    def relocate_strings(dict_neworiginal, dict_oldtranslated, tm: TranslationMemory, is_original):
        dict_newtranslated = {}
        for key, entry_neworiginal in dict_neworiginal.items():
            match_result = tm.match(entry_neworiginal.value, key)
            if match_result:
                value_translated, fuzzy = match_result
            else:
                entry_oldtranslated = dict_oldtranslated.get(key, None)
                if entry_oldtranslated:
                    value_translated = entry_oldtranslated.value
                    fuzzy = entry_oldtranslated.fuzzy
                else:
                    value_translated = entry_neworiginal.value if is_original else ''
                    fuzzy = False
            dict_newtranslated[key] = entry_neworiginal._replace(
                value=value_translated,
                fuzzy=fuzzy and (not is_original)
            )
        return dict_newtranslated

    # -------------

    if first_pass == second_pass:
        raise RuntimeError('Must be call with exactly one of the --first_pass or --second-pass.')

    configpath = ctx.obj['configpath']
    config = ctx.obj['config']
    filePatterns = config.get('filePatterns', [])

    filepaths_xml = [
        path
        for file_pattern in filePatterns
        for path in glob_posix(file_pattern, root_dir='src-en')
    ]
    
    list_of_languages = set(Path(path).stem for path in glob_posix('locale/**/*.po'))

    with open('report.txt', 'w', encoding='utf-8', newline='\n', buffering=1) as reportfile:
        if first_pass:
            # Cleanup removed files if any
            for filepath_po in glob_posix('**/*.po', root_dir='locale'):
                if Path(filepath_po).parent.as_posix() not in filepaths_xml:
                    print(f'Cleanup: removing locale/{filepath_po}...')
                    (Path('locale') / filepath_po).unlink()

            tm = {}
            for lang in list_of_languages:
                print(f'Generating TM for {lang}...')
                tm[lang] = generate_translation_memory('locale/**/en.po', f'locale/**/{lang}.po')
            
            for filepath_xml in filepaths_xml:
                print(f'Generating en.po.new for {filepath_xml}...')

                # Generate en.po.new
                success = runproc(
                    f'Generating locale: {filepath_xml}, en',
                    reportfile, configpath,
                    'generate', f'src-en/{filepath_xml}', f'locale/{filepath_xml}/en.po.new',
                    '-p', f'{filepath_xml}$', '-l', f'src-en/{filepath_xml}', '-r'
                )
                if not success:
                    continue

                dict_neworiginal, _, sourcelocation = readpo(f'locale/{filepath_xml}/en.po.new')
                assert sourcelocation

                for lang in list_of_languages:
                    print(f'Relocating strings for {filepath_xml}, {lang}...')

                    filepath_po = f'locale/{filepath_xml}/{lang}.po'

                    if Path(filepath_po).exists():
                        dict_oldtranslated, _, _ = readpo(filepath_po)
                    elif lang == 'en':
                        dict_oldtranslated = dict(dict_neworiginal)
                    else:
                        dict_oldtranslated = {
                            entry_neworiginal.key: entry_neworiginal._replace(value='', fuzzy=False)
                            for entry_neworiginal in dict_neworiginal.values()
                        }
                    dict_newtranslated = relocate_strings(dict_neworiginal, dict_oldtranslated, tm[lang], lang == 'en')
                    entries_newtranslated = sorted(dict_newtranslated.values(), key=lambda entry: entry.lineno)
                    writepo(filepath_po, entries_newtranslated, sourcelocation)

        elif second_pass:
            for filepath_xml in filepaths_xml:
                en_old_locale = f'locale/{filepath_xml}/en.po'
                en_new_locale = f'locale/{filepath_xml}/en.po.new'
                assert Path(en_old_locale).exists() and Path(en_new_locale).exists()

                other_locales = glob_posix(f'locale/{filepath_xml}/*.po')
                other_locales.remove(en_old_locale)

                for other_locale in other_locales:
                    assert Path(en_old_locale).exists()

                    print(f'Processing {other_locale}...')

                    runproc(
                        f'Updating locale: {other_locale}',
                        reportfile, configpath,
                        'update', en_old_locale, en_new_locale, other_locale,
                        '-x', f'src-en/{filepath_xml}',
                        '-t', Path(other_locale).stem
                    )
                
                print(f'Overwriting  {en_old_locale}...')
                shutil.move(en_new_locale, en_old_locale)
    
if __name__ == '__main__':
    main()
