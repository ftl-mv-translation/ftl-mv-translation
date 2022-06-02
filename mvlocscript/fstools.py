from pathlib import Path
import os
import sys
from glob import glob

def ensureparent(filepath):
    Path(filepath).parent.mkdir(parents=True, exist_ok=True)

def simulate_pythonioencoding_for_pyinstaller():
    '''pyinstaller ignores PYTHONIOENCODING; redirect them when freezed.'''

    if getattr(sys, 'frozen', False):
        pythonioencoding = os.environ.get('PYTHONIOENCODING', None)
        if pythonioencoding:
            idx = pythonioencoding.find(':')
            if idx == -1:
                encoding = pythonioencoding or None
                errors = None
            else:
                encoding = pythonioencoding[:idx] or None
                errors = pythonioencoding[idx + 1:] or None

            kwargs = {}
            if encoding:
                kwargs['encoding'] = encoding
            if errors:
                kwargs['errors'] = errors

            if kwargs:
                sys.stdin = open(sys.stdin.fileno(), 'r', closefd=False, **kwargs)
                sys.stdout = open(sys.stdout.fileno(), 'w', closefd=False, **kwargs)
                sys.stderr = open(sys.stderr.fileno(), 'w', closefd=False, **kwargs)

def glob_posix(pattern, *args, **kwargs):
    '''
    An opinionated glob.glob():
    * recursive=True by default
    * Glob only files, not directories.
    '''
    if any(kwarg not in ('pathname', 'root_dir', 'recursive') for kwarg in kwargs):
        # We don't support dir_fd
        raise RuntimeError('Unsupported kwarg passed')
    
    new_kwargs = {"recursive": True}
    new_kwargs.update(kwargs)
    
    root_dir = Path(kwargs.get('root_dir', '.'))

    results = glob(pattern, *args, **new_kwargs)
    return list(filter(
        lambda p: (root_dir / p).is_file(),
        (Path(result).as_posix() for result in results)
    ))
