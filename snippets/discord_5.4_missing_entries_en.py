from collections import defaultdict
from mvlocscript.potools import readpo, writepo, parsekey
from mvlocscript.fstools import glob_posix as glob
from pathlib import Path
import shutil

def main():
    glob_current = "locale/**/en.po"
    
    # find entries that are both empty in current and broken, yet nonempty in fixed
    for current_path in glob(glob_current):
        fixed_path = current_path.replace('locale', 'locale-fixed-secondpass')
        shutil.copy(fixed_path, current_path)

main()