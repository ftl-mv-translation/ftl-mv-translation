from collections import defaultdict
from mvlocscript.potools import readpo, writepo, parsekey
from mvlocscript.fstools import glob_posix as glob
from pathlib import Path
import shutil

def main():
    glob_current = "locale/**/*.po"
    
    # find entries that are both empty in current and broken, yet nonempty in fixed
    for current_path in glob(glob_current):
        with open(current_path, 'r', encoding='utf-8') as f:
            content = f.read()
        with open(current_path, 'w', encoding='utf-8') as f:
            f.write(content + '\n')

main()