import math
import requests
from loguru import logger
from mvlocscript.potools import parsekey, readpo, writepo

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

results = fetch_paginated_results(
    'https://weblate.hyperq.be/api/components/',
    params={'q': 'state:needs-editing project:ftl-multiverse'},
    headers=AUTH_HEADER
)
results = [
    component['project']['slug'] + '/' + component['slug']
    for component in results
    if component['project']['slug'] in ('ftl-multiverse', 'the-renegade-collection')
        and component['commit_pending_age'] != 2
]
for segment in results:
    with requests.patch(
        f'https://weblate.hyperq.be/api/components/{segment}/',
        json={'commit_pending_age': 2},
        headers=AUTH_HEADER
    ) as req:
        req.raise_for_status()
        logger.info(f'Set commit_pending_age to 2 for {segment}')
