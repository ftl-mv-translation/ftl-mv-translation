# Crawls Weblate. Mark po entries fuzzy if they're marked as fuzzy in Weblate as well.
# Usage:
# 1. Create a file called .weblate-token at the root of the repo,
#    with content being your Weblate token that starts with `wlu_`.
# 2. Run the script.
# 3. Run the script with `process` argument.

import json
import math
import sys
import requests
from loguru import logger
from mvlocscript.potools import parsekey, readpo, writepo

CRAWL = len(sys.argv) <= 1 or sys.argv[1] != 'process'

with open('.weblate-token', 'r') as f:
    AUTH_HEADER = {'Authorization': f'Token {f.read().strip()}'}

def fetch_paginated_results(url, params=None, *args, **kwargs):
    pageno = 1
    logger.info(f'Fetching page {pageno} from {url}...')
    with requests.get(url, params=params, *args, **kwargs) as req:
        result = req.json()
    
    count = result['count']
    if count == 0:
        logger.info('- Note: the query result seems empty')
    
    ret = result['results']
    assert ret
    logger.info(f'- Estimated number of pages: {math.ceil(count / len(ret))}')
    
    while True:
        next = result.get('next', None)
        if next is None:
            return ret
        
        pageno += 1
        logger.info(f'Fetching page {pageno} from {next}...')
        with requests.get(next, *args, **kwargs) as req:
            result = req.json()
        ret += result['results']

if CRAWL:
    results = fetch_paginated_results(
        'https://weblate.hyperq.be/api/units/',
        params={'q': 'state:needs-editing project:ftl-multiverse'},
        headers=AUTH_HEADER
    )
    with open('fuzzy.json', 'w', encoding='utf-8') as f:
        json.dump(results, f)
    sys.exit()

with open('fuzzy.json', 'r', encoding='utf-8') as f:
    results = json.load(f)

logger.info(f'Fuzzy entries: {len(results)}')

CACHE = {}
changed = set()

def getpo(path):
    res = CACHE.get(path, None)
    if res is None:
        CACHE[path] = poresult = readpo(path)
        return poresult
    return res

fixed = 0
for unit in results:
    assert unit['fuzzy']
    
    # extract fn
    key = unit['context']
    fn, _ = parsekey(key)
    assert fn
    fn = fn[:-1]
    
    # extract lang
    lang = unit['translation'].split('/')[-2]

    path = f'locale/{fn}/{lang}.po'
    dict_translated, _, _ = getpo(path)
    v = dict_translated[key]
    if not v.fuzzy:
        dict_translated[key] = v._replace(fuzzy=True)
        fixed += 1
        changed.add(path)

for path in changed:
    d, _, s = CACHE[path]
    writepo(path, d.values(), s)

logger.info(f'{fixed}/{len(results)} entries fixed.')
