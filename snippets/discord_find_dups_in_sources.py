from collections import defaultdict
from mvlocscript.potools import readpo
from mvlocscript.fstools import glob_posix as glob

counts = defaultdict(int)

for path in glob('locale/**/en.po'):
    dict_original, _, _ = readpo(path)
    for entry in dict_original.values():
        if entry.obsolete:
            continue
        counts[entry.value] += 1
    
counts = [(v, k) for k, v in counts.items() if v >= 50]
counts.sort()
for v, k in counts:
    print('{:<8}`{}`'.format(v, k))
