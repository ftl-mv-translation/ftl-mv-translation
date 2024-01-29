# FTL: Multiverse Translation Project

## Link to the latest nightly translation

Download from [HERE](https://github.com/ftl-mv-translation/ftl-mv-translation/releases/latest). (Updated every UTC 00:00)

## Running the script

The script is written in Python and managed by poetry. A standard setuptools may install it as a package,
or you may use poetry to manage the virtualenv and installation process.

The `mvloc` command can be invoked with either one of the following setups:

1. Use regular pip (or [pipx](https://github.com/pypa/pipx)) to install the package. (virtualenv is recommended)
2. Use poetry to install the package (`poetry install`), then run `poetry shell` to activate virtualenv. (*)

(*) Note that directly invoking `poetry run mvloc` might NOT work for `batch-` commands because of [this poetry bug](https://github.com/python-poetry/poetry/issues/965). Running `mvloc` inside the spawned shell won't have this issue.

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

### Packaging the translation

1. Follow the "Applying the translation" workflow first
2. Run `mvloc package <langname>` -- Example: `mvloc package ko`

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

## Disclaimer

FTL: Faster Than Light is a trademark of Subset Games. Unless otherwise stated, the authors and the contributors of this
repository is not affiliated with nor endorsed by Subset Games.
