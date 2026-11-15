#!/usr/bin/env python3
"""(3.126.0) THE SMALL UPDATES OF A RELEASE (see tool/apk_patch.py; called by .github/workflows/release.yml, the job "publish").

For each processor's app file of the new release (out/rcl-erp-<VER>-<BN>.<abi>.apk) and each of the newest builds released before
it (stable and beta – the newest KEEP of them that have that file): a file with only what changed,
  out/rcl-erp-<VER>-<BN>.<abi>.from-<build>.patch
Every patch is APPLIED here to the earlier file and the result compared with the new file (SHA-256): only a patch that makes exactly
the released file is kept. Prints {"<abi>": [builds…]} into out/patches.json – release.yml writes it into the release ("patch").
A patch that cannot be made is left out (a warning): that phone downloads the whole file, as before – the release never fails for it.

  needs: GH_TOKEN, GITHUB_REPOSITORY, VER, BN; "pip install bsdiff4"; the gh CLI
(15-11-2026) TWO APPS: RCL_APP=beta (beta.yml – the Sketchline Beta app) takes only the earlier Beta app's files (their line is
<!-- rclb:… -->); otherwise (release.yml) only the Sketchline app's (<!-- rcl:… -->) – a file of the other app is never on that phone.
"""
import hashlib, json, os, re, subprocess, sys
from concurrent.futures import ProcessPoolExecutor

KEEP = 5
ABIS = ['arm64-v8a', 'armeabi-v7a']
HERE = os.path.dirname(os.path.abspath(__file__))


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for part in iter(lambda: f.read(1 << 20), b''):
            h.update(part)
    return h.hexdigest()


def one(job):
    abi, build, old, new, out = job
    tmp = out + '.check'
    try:
        subprocess.run([sys.executable, os.path.join(HERE, 'apk_patch.py'), 'make', old, new, out], check=True, timeout=900)
        subprocess.run([sys.executable, os.path.join(HERE, 'apk_patch.py'), 'apply', old, out, tmp], check=True, timeout=300)
        if sha(tmp) != sha(new):
            raise RuntimeError('the file made from the patch is not the released one')
        return abi, build, os.path.getsize(out), ''
    except Exception as e:  # this one is left out – the whole file for that build
        if os.path.exists(out):
            os.remove(out)
        return abi, build, 0, str(e)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def main():
    repo, ver, bn = os.environ['GITHUB_REPOSITORY'], os.environ['VER'], int(os.environ['BN'])
    mine = '<!-- rclb:' if os.environ.get('RCL_APP') == 'beta' else '<!-- rcl:'
    rels = json.loads(subprocess.run(['gh', 'api', f'repos/{repo}/releases?per_page=40'], check=True, capture_output=True, text=True, timeout=120).stdout)
    jobs = []
    os.makedirs('old', exist_ok=True)
    for abi in ABIS:
        new = f'out/rcl-erp-{ver}-{bn}.{abi}.apk'
        if not os.path.exists(new):
            continue
        before = []
        for r in rels:
            m = re.match(r'^v.*-(\d+)$', r.get('tag_name') or '')
            names = [(a['name'], a['id']) for a in r.get('assets', []) if a['name'].endswith(f'.{abi}.apk')]
            if m and not r.get('draft') and int(m.group(1)) < bn and names and mine in (r.get('body') or ''):
                before.append((int(m.group(1)), names[0][0], names[0][1]))
        for build, name, asset in sorted(before, reverse=True)[:KEEP]:
            d = f'old/{abi}-{build}'
            try:
                os.makedirs(d, exist_ok=True)
                with open(f'{d}/{name}', 'wb') as f:      # the file itself, by its number (the REST API)
                    subprocess.run(['gh', 'api', '-H', 'Accept: application/octet-stream', f'repos/{repo}/releases/assets/{asset}'], check=True, stdout=f, timeout=300)
            except Exception as e:
                print(f'::warning::The app file of build {build} ({abi}) could not be fetched – no small update from it: {e}')
                continue
            jobs.append((abi, build, f'{d}/{name}', new, f'out/rcl-erp-{ver}-{bn}.{abi}.from-{build}.patch'))
    made = {}
    with ProcessPoolExecutor(max_workers=3) as pool:
        for abi, build, size, problem in pool.map(one, jobs):
            if problem:
                print(f'::warning::No small update from build {build} ({abi}) – that phone downloads the whole file: {problem}')
            else:
                made.setdefault(abi, []).append(build)
                print(f'::notice::Small update from build {build} ({abi}): {size / 1048576:.2f} MB')
    json.dump(made, open('out/patches.json', 'w'))


if __name__ == '__main__':
    main()
