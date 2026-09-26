"""What does the Change Register hold that the repo does not?

Unit: SENTENCES of at least MIN_WORDS words, normalised. A sentence counts as IN THE REPO when at
least SENT_THRESHOLD of its 8-word shingles appear in the repo corpus (tracked text files, and
separately commit messages). Verbatim-shingle matching MISSES PARAPHRASE, so it can only
OVER-report "Register-only". Every Register-only verdict quoted is adjudicated by hand.
"""
import json, re, subprocess, sys, os
sys.stdout.reconfigure(encoding='utf-8')

REPO = 'C:/dev/epilepsyrecorder'
CR = 'C:/Users/wjl25/OneDrive/Projects/App Dev/Claude/Medical Event Recorder — Change Register.md'
N = 8
MIN_WORDS = 12
SENT_THRESHOLD = 0.8
SLICE = 40
SKIP_EXT = re.compile(r'\.(png|jpg|jpeg|ico|gif|webp|pdf|ttf|otf|jks|keystore|plist|apns|sha256|zip|bin|a|so|dylib|mp4|mov|lock)$', re.I)

def norm(text):
    text = re.sub(r'^\s*(///|//|#+|>+|\*|-|\|)\s?', ' ', text, flags=re.M)  # comment/markdown prefixes
    text = re.sub(r'[*`_|>#]', ' ', text)
    text = text.replace('—', ' ').replace('–', ' ')
    text = re.sub(r'[^\w\s%./:()+-]', ' ', text.lower())
    return text.split()

def shingles(words):
    return {hash(tuple(words[i:i + N])) for i in range(len(words) - N + 1)}

def sentences(body):
    body = re.sub(r'\s+', ' ', body)
    return [s for s in re.split(r'(?<=[.!?])\**\s+', body) if len(norm(s)) >= MIN_WORDS]

def score(sent, corpus):
    sh = shingles(norm(sent))
    return (sum(1 for x in sh if x in corpus) / len(sh)) if sh else 0.0

# ── the repo corpus ────────────────────────────────────────────────────────────
files = subprocess.run(['git', '-C', REPO, 'ls-files'], capture_output=True, text=True,
                       encoding='utf-8').stdout.splitlines()
files = [f for f in files if not SKIP_EXT.search(f)]
repo_sh, read = set(), 0
for f in files:
    try:
        with open(os.path.join(REPO, f), encoding='utf-8') as fh:
            repo_sh |= shingles(norm(fh.read()))
        read += 1
    except (UnicodeDecodeError, OSError):
        pass
log = subprocess.run(['git', '-C', REPO, 'log', '--all', '--format=%B'], capture_output=True,
                     text=True, encoding='utf-8').stdout
log_sh = shingles(norm(log))
print(f'corpus: {read} of {len(files)} text files read, {len(repo_sh)} file shingles, '
      f'{len(log_sh)} commit-message shingles')

# ── the Register slice ─────────────────────────────────────────────────────────
cr = open(CR, encoding='utf-8').read()
parts = re.split(r'(?m)^(?=## )', cr)
entries = [p for p in parts if p.startswith('## ')]
cut = next(i for i, e in enumerate(entries) if e.startswith('## Tier A: a restore'))
sl = entries[cut - SLICE:cut]
print(f'register: {len(entries)} entries; slice = entries {cut - SLICE + 1}..{cut} '
      f'({sl[0].splitlines()[0][3:80]} .. {sl[-1].splitlines()[0][3:80]})')

# ── apparatus controls ────────────────────────────────────────────────────────
status = open(os.path.join(REPO, 'STATUS.md'), encoding='utf-8').read()
known_in = sentences(status)[40]
known_out = 'zebra quantum marmalade orbit lantern violin cactus ember harbour tundra piano glacier.'
print(f'CONTROL apparatus: a STATUS.md sentence scores {score(known_in, repo_sh):.2f} (must be 1.00); '
      f'nonsense scores {score(known_out, repo_sh):.2f} (must be 0.00)')

# ── per entry ──────────────────────────────────────────────────────────────────
rows = []
for e in sl:
    title = e.splitlines()[0][3:]
    ss = sentences(e)
    in_files = [s for s in ss if score(s, repo_sh) >= SENT_THRESHOLD]
    in_log = [s for s in ss if s not in in_files and score(s, log_sh) >= SENT_THRESHOLD]
    only = [s for s in ss if s not in in_files and s not in in_log]
    rows.append(dict(title=title, n=len(ss), files=len(in_files), log=len(in_log),
                     only=len(only), only_s=only))

tot = {k: sum(r[k] for r in rows) for k in ('n', 'files', 'log', 'only')}
print(f"\nSENTENCES: {tot['n']} in slice; in repo files {tot['files']}; only in commit messages "
      f"{tot['log']}; in NEITHER {tot['only']}")
def cls(r):
    f = (r['files'] + r['log']) / r['n'] if r['n'] else 0
    return 'DUPLICATED' if f >= 0.8 else 'REGISTER-ONLY' if f <= 0.2 else 'MIXED'
from collections import Counter
print('ENTRIES:', dict(Counter(cls(r) for r in rows)), f'of {len(rows)}')
print()
for r in rows:
    print(f"{cls(r):13} {r['files']:3}+{r['log']:3} of {r['n']:3} in repo  {r['title'][:95]}")
json.dump(rows, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cr_rows.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
