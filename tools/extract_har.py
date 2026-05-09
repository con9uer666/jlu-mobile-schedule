"""Extract key API calls from HAR file for jwapp analysis."""
import json
import sys
from urllib.parse import urlparse

HAR_PATH = r'e:\PROJECTS\schedule\iedu.jlu.edu.cn.har'
INTERESTING = [
    'cxxszhxqkb',  # suspected schedule query
    'xsdkkc',
    'cxjcs',
    'jc.do',
    'cxjcgxxx',
    'login',
    'authserver',
    'cas',
    'sso',
    'setJwCommon',
    'kbckIndexPage',
    'wdkb',
    'wptk',
    'cxxljc',
    'cxxsjbxx',  # student basic info
    'dqzc',
    'dqxnxq',  # current term
]

def short_headers(hdrs):
    keep = {'Cookie', 'cookie', 'Referer', 'referer', 'Content-Type',
            'content-type', 'X-Requested-With', 'x-requested-with',
            'Origin', 'origin'}
    return [h for h in hdrs if h.get('name') in keep]

def trim_text(t, n=2000):
    if not t:
        return t
    if len(t) <= n:
        return t
    return t[:n] + f'...[truncated, total {len(t)}]'

def main():
    with open(HAR_PATH, 'r', encoding='utf-8') as f:
        har = json.load(f)
    entries = har['log']['entries']
    print(f'total entries: {len(entries)}')
    by_url = {}
    for e in entries:
        url = e['request']['url']
        path = urlparse(url).path
        name = path.rsplit('/', 1)[-1]
        for key in INTERESTING:
            if key.lower() in url.lower():
                by_url.setdefault(name, []).append(e)
                break
    for name, items in by_url.items():
        print(f'\n{name}: {len(items)} requests')

    if len(sys.argv) > 1:
        target = sys.argv[1]
        for name, items in by_url.items():
            if target in name:
                print(f'\n===== {name} =====')
                for i, e in enumerate(items):
                    req = e['request']
                    resp = e['response']
                    print(f'\n--- {name} #{i} ---')
                    print(f'  URL: {req["url"]}')
                    print(f'  Method: {req["method"]}')
                    print(f'  Status: {resp["status"]}')
                    print(f'  Req headers:')
                    for h in short_headers(req.get('headers', [])):
                        v = h['value']
                        if h['name'].lower() == 'cookie':
                            v = v[:200] + '...' if len(v) > 200 else v
                        print(f'    {h["name"]}: {v}')
                    if req.get('postData'):
                        pd = req['postData']
                        print(f'  Post mimeType: {pd.get("mimeType")}')
                        print(f'  Post text: {trim_text(pd.get("text", ""), 1000)}')
                        if pd.get('params'):
                            print(f'  Post params:')
                            for p in pd['params']:
                                print(f'    {p.get("name")} = {p.get("value")}')
                    if req.get('queryString'):
                        print(f'  Query:')
                        for q in req['queryString']:
                            print(f'    {q["name"]} = {q["value"]}')
                    print(f'  Resp ct: {resp.get("content", {}).get("mimeType")}')
                    body = resp.get('content', {}).get('text', '')
                    print(f'  Resp body: {trim_text(body, 3000)}')

if __name__ == '__main__':
    main()
