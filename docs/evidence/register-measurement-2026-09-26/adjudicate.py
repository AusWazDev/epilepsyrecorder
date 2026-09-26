import subprocess, sys
sys.stdout.reconfigure(encoding='utf-8')
R = 'C:/dev/epilepsyrecorder'
PROBES = {
    1: ['code-fence count', 'heading counts'],
    2: ['wm size'],
    3: ['447598', '3.38:1'],
    4: ['offerable', 'scores zero'],
    5: ['relabel'],
    6: ['byType(BoundedWrap).first'],
    7: ['Dizzy or spinning'],
    8: ['JUSTIFICATION is corrected', 'documentation accuracy on a provable fact'],
    9: ['20 pt status bar', '20pt status bar'],
    10: ['permission-asking', 'asking permission'],
    11: ['MINIMUM ITSELF', 'minimum itself'],
    12: ['REAL PAST STATE', 'wrong cause and date'],
    13: ['ClickUp normalises', 'shared\\_preferences'],
    14: ['post-ictal set', 'leg 3'],
    15: ['exclusive chain', 'zero data risk'],
    16: ['louder than it was'],
    17: ['one half is inert', 'inert on the list'],
    18: ['Total saved: 0'],
    19: ['reads as authoritative precisely because'],
    20: ['OEM-capped', 'TextScaler` is linear', 'non-linear per style'],
    21: ['Second proposed fix', 'disproved on scoping'],
    22: ['direction with no number', 'guess dressed as a constant'],
    23: ['presyncope'],
    24: ['SPANNING DUPLICATION', 'prodromal and postdromal'],
    25: ['is never touched, by anything, ever'],
    26: ['export REPRESENTS', 'what the export represents'],
    27: ['can only under-report', 'ONLY UNDER-REPORT'],
    28: ['renameEntry'],
    29: ['pallor'],
    30: ['COMPLETENESS IS THE RIGHT AXIS', 'completeness is the right axis'],
}
for i, terms in PROBES.items():
    out = []
    for t in terms:
        f = subprocess.run(['git', '-C', R, 'grep', '-i', '-F', '-l', '-e', t],
                           capture_output=True, text=True, encoding='utf-8').stdout.split()
        lg = subprocess.run(['git', '-C', R, 'log', '--all', '-i', '-F', '--format=%h', '--grep', t],
                            capture_output=True, text=True, encoding='utf-8').stdout.split()
        out.append(f'"{t}": files={f[:3]}{"+" if len(f) > 3 else ""} commits={lg[:2]}')
    print(f'[{i}] ' + ' | '.join(out))
