# FTL: Multiverse Translation Project

## Link to the latest nightly translation

Download from [HERE](https://github.com/ftl-mv-translation/ftl-mv-translation/releases/latest). (Updated every UTC 00:00)

## Localized Multiverse Installer

You can also install translated Multiverse and its addons via our localized installer. [HERE](https://github.com/ftl-mv-translation/mvinstaller/releases/latest)

## Running the script

The script is written in Python and managed by poetry. A standard setuptools may install it as a package,
or you may use poetry to manage the virtualenv and installation process.

The `mvloc` command can be invoked with either one of the following setups:

1. Use regular pip (or [pipx](https://github.com/pypa/pipx)) to install the package. (virtualenv is recommended)
2. Use poetry to install the package (`poetry install`), then run `poetry shell` to activate virtualenv. (*)

(*) Since poetry 2.0.0, `shell` is not included by default. You need to enable it by running `poetry self add poetry-plugin-shell`.

All `mvloc` subcommands starting with `batch-` generates `report.txt` file that contains logs and outputs of all task
in a workflow.


## Workflows

### Translation

The repo is designed to work with [Weblate](https://weblate.org/). Following Weblate addon settings are recommended:

* Component discovery
   ```
   Regular expression to match translation files against:
   locale/(?P<component>.*)/(?P<language>[^/.]*)\.po
   
   File format:
   gettext PO file (monolingual)
   
   Define the monolingual base filename:
   locale/{{ component }}/en.po
   
   Define the base file for new translations:
   locale/{{ component }}/en.po
   ```

### Updating the English strings

1. Unzip the latest FTL: Multiverse into src-en/ directory
2. Update the `packaging` section of `mvloc.config.jsonc` file
3. Run `mvloc major-update --first-pass`
4. Push the changes to the repo, then Update -> Force Synchronization from Weblate.
5. Run `mvloc major-update --second-pass`
6. Push the changes to the repo, then Update -> Force Synchronization from Weblate.

The command extracts localizable strings from `src-en/` and updates  `en.po` files in `locale/`.
Note that the two-step is required for Weblate to automatically handle the string changes correctly.

### Changing string extraction criteria

1. Edit `mvloc.config.jsonc` file
3. Run `mvloc batch-generate --clean --update en`

Unlike `major-update` command it tries to update the file without global translation memory,
does not perform a fuzzy matching, and preserves the obsolete/fuzzy entries.

### Applying the translation

Run `mvloc batch-apply <langname>` -- Example: `mvloc batch-apply ko`

This command transforms XMLs in `src-en/` using translation files on `locale/`,
then writes them out to `output-<langname>` directory.

Add `-m` option if you use machine translation from `locale-machine/`. Machine translation is put on untranslated texts, does not replace hand translation.
-- Example: `mvloc batch-apply ja -m`

### Packaging the translation

1. Follow the "Applying the translation" workflow first
2. Run `mvloc package <langname>` -- Example: `mvloc package ko`

If you used `-m` option while applying process, add `-m` option as well.
-- Example: `mvloc package ja -m`

This command automatically packages the translation. It downloads the English Multiverse, overwrites it with
translated XMLs, (optionally overwrites it with contents in `auxfiles-<langname>/` if any), and zip it to create
a package suitable for Slipstream Mod Manager.

### Bootstrapping

1. Create `src-<langname>/` directory and place the translated XMLs there -- Example: `src-ko/`.
2. Run `mvloc batch-generate --diff --clean <langname>`

The bootstrapping process tries to reverse the applying process: extracting the strings out of already translated
XML files. This is useful when migrating from an ongoing translation project.

In case where the string extraction criteria is incomplete to cover your XMLs, the unhandled changes are shown in
the report.txt (shown as "Diff report" tasks). In that case, adjust `mvloc.config.jsonc` appropriately, follow the
"Updating the English strings" workflow to update en.po files, and repeat this workflow again.

> #### Bootstrapping only a subset of XML files
>
> * This is useful when importing a new translated XML file over an already existing locale in the project.
> * Put XML files into `src-<langname>/`. Make sure to remove any other files or they will be overwritten as well!
> * Remove `--clean` option when invoking `mvloc`. Other files will be untouched.

### Machine translation

If you want localized MV but cant find translation for your language, you can make MT(machine translation) by yourself. Also you can join our weblate project to start hand translation, but you will soon realize how large the scale of MV is. So I recommend to make MT first, then replace it with your hand translation gradually.

`mvloc machine <langname>` -- Example: `mvloc machine ja`

It will take around 12 hours to finish translation due to mass texts in mv.
You do not have to run the script continuously because there is the autosave function, and you can edit the script to change the interval(default: 100).

To implement MT in Nightly, add `bash snippets/ci-nightly-machine.sh <langname>` [HERE](https://github.com/ftl-mv-translation/ftl-mv-translation/blob/c4f2e63a98ade4d2895ea5fa16d371703769c2a9/.github/workflows/nightly.yml#L36)

> If you have deepl api free, you can replace MT with deepl translation, which would be more decent quality. `mvloc deepl <langname> <deepl-api-free-key> <character-limit(optional)>`
> Deepl api free has translation limit of 500k characters per month. MV has about 4m characters, so it may take 8 months to complete deepl translation.

If vanilla ftl does not support your language, you have to find fonts suitable for ftl, and make `auxfiles-<langname>/` to override existing language fonts. [Korean](https://github.com/ftl-mv-translation/ftl-mv-translation/tree/main/auxfiles-ko/fonts/zh-Hans) is a good example.
You can also ask HS devs to add your language. 

## Disclaimer

FTL: Faster Than Light is a trademark of Subset Games. Unless otherwise stated, the authors and the contributors of this
repository is not affiliated with nor endorsed by Subset Games.
