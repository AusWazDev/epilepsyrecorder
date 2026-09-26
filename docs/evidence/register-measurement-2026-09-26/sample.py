"""Draw the 30-sentence sample for pass 2. Run AFTER measure_cr.py, which writes cr_rows.json.

The pool is every sentence pass 1 found in NEITHER the repo files NOR the commit messages, in
Register order (entry order, then sentence order). random.seed(26) then random.sample(pool, 30)
reproduces the sample exactly, as long as the slice and pass 1 are unchanged.
"""
import json, os, random, sys
sys.stdout.reconfigure(encoding='utf-8')

HERE = os.path.dirname(os.path.abspath(__file__))
rows = json.load(open(os.path.join(HERE, 'cr_rows.json'), encoding='utf-8'))
pool = [(r['title'][:60], s) for r in rows for s in r['only_s']]
print('pool', len(pool))
random.seed(26)
for i, (t, s) in enumerate(random.sample(pool, 30), 1):
    print(f'[{i}] <{t}>\n    {s[:330]}\n')
