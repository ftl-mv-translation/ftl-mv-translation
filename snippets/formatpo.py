from mvlocscript.potools import readpo, writepo
from mvlocscript.fstools import glob_posix as glob

# Re-format all .po files based on how mvloc saves them (minimal header, line wrapping rules based on polib)
# Used for generating sensible text diffs for experiments

for path in glob('locale/**/*.po'):
    dict_entries, _, sourcelocation = readpo(path)
    writepo(path, dict_entries.values(), sourcelocation)
