# FTL: Multiverse Korean Translation

## Running the script

The script is written in Python and managed by poetry. A standard setuptools may install it as a package, or you may use poetry to manage the virtualenv and installtion process.

The `mvloc` command can be invoked with following setups:

1. Use pip to install the package. (virtualenv is recommended)
2. Use poetry to install the package (`poetry install`) then run it by `poetry run mvloc`.

All `mvloc` subcommands starting with `batch-` generates `report.txt` file that contains logs and outputs of all task in the workflow.

## Workflows

### Translation

The repo is designed to work with [Weblate](https://weblate.org/). Following Weblate addon settings are recommended:

* Component discovery
   ```
   Regular expression to match translation files against:
   locale/(?P<component>.*)/(?P<language>[^/.]*)\.json
   
   File format:
   JSON file
   
   Define the monolingual base filename:
   locale/{{ component }}/en.json
   
   Define the base file for new translations:
   locale/{{ component }}/en.json
   ```

* Flag unchanged translations as "Needs editing"

### Updating the English strings

1. Unzip the latest FTL: Multiverse into src-en/ directory
2. Run `mvloc batch-en`

The command extracts localizable strings from `src-en/` and updates  `en.json` files in `locale/`. Weblate can automatically grab the JSON changes once the repository is updated.

### Changing string extraction criteria

Edit `mvloc.config.jsonc` file, then and follow the "Updating the English strings" workflow.

### Applying the translation

1. Unzip the latest FTL: Multiverse into `src-en/` directory
2. Run `mvloc batch-apply`

The command transforms XMLs in `src-en/` using translations on `locale/`, then writes them out to `output/`.

### Bootstrapping

1. Unzip the original FTL: Multiverse into `src-en/` directory
2. Create `src-ko/` directory and place the translated XMLs there.
3. Run `mvloc batch-bootstrap`

The bootstrapping process tries to reverse the applying process: extracting the strings out of already translated XML files. This is useful when migrating from an ongoing translation project.

## Disclaimer

FTL: Faster Than Light is a trademark of Subset Games. Unless otherwise stated, the authors and the contributors of this repository is not affiliated with nor endorsed by Subset Games.
