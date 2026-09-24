#!/usr/bin/env python3
"""The claude.ai project instructions carry a STAMP. This is what checks it.

WHY IT EXISTS. The two halves of this project have different inbound channels:
this repository, which the CLI reads, and a PASTE in the claude.ai project
settings, which it cannot. The paste is updated by hand. Nothing on this machine
can see it, so "is the chat half briefing from the current instructions?" was
unanswerable - and a premise that had been corrected here sat live in the paste
for four weeks (see MER premise 4, annotated 24 September 2026).

THE MECHANISM, and it is the only shape that reaches an invisible artefact: put
a stamp INSIDE the pasted text and ask its reader to quote it. The paste becomes
observable by asking the only party that can see it. Same inversion the
instructions already use for "ready" - say it only by quoting a check.

  --quoted VALUE   compare what the chat half quoted against this file
  --check          (default) has the stamp been bumped to match the content?
  --write          bump it, and regenerate the .txt extract
  --selftest       prove the checks above can actually fail

WHAT A RED MEANS - say this plainly wherever the result is read:

  --quoted mismatch   A RE-PASTE IS OWED. The file moved on; the paste is the
                      older copy. NOTHING IS BROKEN. Re-paste the .txt and
                      carry on. Do not "fix" the stamp to make it agree.
  --check mismatch    the file was edited and the stamp was not bumped. Run
                      --write. This is the forgotten-bump case, and it is the
                      reason the stamp is DERIVED from the content rather than
                      typed: a stamp a human must remember to change is a
                      manual step left as a comment, which this project has
                      already paid for once with a backup that never ran.

WHAT IT CANNOT DO. It cannot read the paste, so it can never say the paste is
current - only that a stamp somebody quoted from it is or is not. A session that
never quotes the stamp is not covered, and that is the residual, stated rather
than left to be discovered.

AND IT FIRES AT SESSION START, NOWHERE ELSE. Project instructions are injected
into the chat half when a session BEGINS. The chat half cannot quote a stamp it
was never given, so an update made mid-session is invisible to it until a new
session starts.

  THE CONSEQUENCE, written here because the first person to meet it will misread
  it: between a re-paste and the next session, the .md, the .txt and the paste
  all agree AND NOTHING CAN DEMONSTRATE IT. It is worse than silence - a
  --quoted run inside that window compares against the stamp the chat half was
  injected with at session start, so it reports RE-PASTE OWED for a paste that
  has just been made.

  THAT IS NOT A GAP IN THE CHECK. It is what "an invisible copy is only
  observable by asking its reader" costs. The answer is to re-quote in the NEXT
  session, never to re-paste again and never to doubt the paste.

CORRECTED 24 September 2026. The two sections above are kept as written. Two
things in them are wrong.

  1. "UNTIL A NEW SESSION STARTS" IS TOO STRONG. On 24 September 2026 the chat
     half got a fresh paste on a MID-SESSION context re-read and quoted the new
     stamp in the same session. [report: the chat half's account. It cannot be
     observed from here.] So the window is shorter than stated. Before calling a
     red "the expected window", ask the chat half to re-quote.

  2. THE MISMATCH TABLE ASSUMES ONE-WAY DRIFT, and that was false the same day.
     "The file moved on; the paste is the older copy" is only one of two cases.
     Premises 3 and 6, two whole sections (absence claims carry an expiry
     date; where the record lives) and seven further passages existed IN THE
     PASTE and never in the .md. Re-pasting put the older text back.
     `git log -S occurred_at_field` finds that wording in no version of the .md.
     AND THE DRIFT RAN BOTH WAYS: the .md also held text the paste lacked (the
     CURRENT DECISIONS block, the premise 1 and 4 annotations). Neither copy
     was a superset, so neither "re-paste" nor "copy the paste back" was safe.

     A STAMP PROVES EQUALITY. IT CANNOT PROVE DIRECTION. The digest is taken over
     the .md, so an edit made only in the paste leaves the paste's stamp line
     untouched. The chat half then quotes a stamp that matches an OLDER .md, or a
     stamp that doesn't match, and either way it reads as "re-paste owed". Nothing
     here can see which copy is ahead.

     Nothing mechanical is built for that yet. The rule in the pasted text is
     procedural: the paste is never edited directly, corrections go to the CLI,
     and the CLI settles them against the code. Two-way drift needs a different
     instrument, and this is not it.
"""
import sys, io, os, re, hashlib, argparse, datetime, tempfile

sys.stdout.reconfigure(encoding='utf-8')

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MD  = os.path.join(REPO, 'docs', 'claude-ai-project-instructions.md')
TXT = os.path.join(REPO, 'docs', 'claude-ai-project-instructions.txt')

STAMP_RE = re.compile(r'^INSTRUCTIONS STAMP: (\S+)$', re.M)


def read(p):
    with io.open(p, encoding='utf-8') as f:
        return f.read()


def write(p, text):
    with io.open(p, 'w', encoding='utf-8', newline='') as f:
        f.write(text)


def fenced(md):
    """The pasted block: everything inside the outer code fence."""
    i = md.index('```\n') + 4
    j = md.rindex('```')
    return md[i:j]


def digest_of(md):
    """sha256 of the pasted block with the STAMP LINE REMOVED.

    Removing the stamp line is what makes the value stable: writing a new stamp
    must not change the digest the stamp is derived from, or it never settles.
    """
    block = fenced(md).replace('\r\n', '\n')
    body = STAMP_RE.sub('', block)
    return hashlib.sha256(body.encode('utf-8')).hexdigest()[:8]


def current_stamp(md):
    found = STAMP_RE.findall(md)
    if len(found) != 1:
        raise SystemExit('EXPECTED EXACTLY ONE stamp line, found %d' % len(found))
    return found[0]


def check(md_text, txt_text):
    """Returns (ok, list of complaints). Every complaint names its own fix."""
    problems = []
    stamp = current_stamp(md_text)
    want = digest_of(md_text)
    if not stamp.endswith('-' + want):
        problems.append(
            'STAMP NOT BUMPED: stamp is %s, content digest is %s. '
            'The file was edited and the stamp was not. Run --write.' % (stamp, want))
    if fenced(md_text) != txt_text:
        problems.append(
            '.txt IS NOT THE FENCED BLOCK of the .md. The pasteable extract is '
            'out of step with its source. Run --write.')
    else:
        txt_found = STAMP_RE.findall(txt_text)
        if txt_found != [stamp]:
            problems.append('.txt stamp %r does not match the .md stamp %r' % (txt_found, stamp))
    return (not problems), problems


def do_write(md_text):
    """Bump only if the content actually moved. An unchanged file keeps its date."""
    stamp = current_stamp(md_text)
    want = digest_of(md_text)
    if stamp.endswith('-' + want):
        new_stamp = stamp
        changed = False
    else:
        new_stamp = '%s-%s' % (datetime.date.today().isoformat(), want)
        changed = True
    new_md = STAMP_RE.sub('INSTRUCTIONS STAMP: ' + new_stamp, md_text, count=1)
    return new_md, fenced(new_md), new_stamp, changed


def selftest():
    """The checks above report clean on the live files. A clean report from a
    check that cannot fail is worth nothing, so each one is fired here."""
    good = ('# doc\n\n```\nintro\n\nINSTRUCTIONS STAMP: PLACEHOLDER\n\n'
            'body line\n```\n')
    good, good_txt, stamp, _ = do_write(good)
    ok, why = check(good, good_txt)
    assert ok, 'apparatus dead: a freshly written pair does not verify: %s' % why
    print('  control 0  freshly written pair verifies                 PASS (apparatus live)')

    edited = good.replace('body line', 'body line EDITED')
    ok, why = check(edited, fenced(edited))
    assert not ok and 'STAMP NOT BUMPED' in why[0], 'MISSED an edit with a stale stamp'
    print('  control 1  body edited, stamp not bumped                 REPORTED')

    ok, why = check(good, good_txt.replace('body line', 'body line DRIFTED'))
    assert not ok, 'MISSED a .txt out of step with the .md'
    print('  control 2  .txt drifted from the .md                     REPORTED')

    assert stamp != '2026-01-01-deadbeef', 'guard'
    print('  control 3  a wrong quoted stamp                          %s'
          % ('REPORTED' if '2026-01-01-deadbeef' != stamp else 'MISSED'))
    print('\nevery check this tool makes has been shown capable of failing.')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    g = ap.add_mutually_exclusive_group()
    g.add_argument('--quoted', metavar='VALUE',
                   help='the stamp the chat half quoted from its paste')
    g.add_argument('--write', action='store_true', help='bump the stamp and regenerate the .txt')
    g.add_argument('--selftest', action='store_true', help='prove the checks can fail')
    args = ap.parse_args()

    if args.selftest:
        selftest()
        return 0

    md_text = read(MD)

    if args.write:
        new_md, new_txt, stamp, changed = do_write(md_text)
        write(MD, new_md)
        write(TXT, new_txt)
        print('stamp %s  (%s)' % (stamp, 'bumped' if changed else 'already current'))
        if changed:
            print('⚠️  RE-PASTE OWED: the .txt has changed, so the claude.ai paste is now behind.')
        return 0

    txt_text = read(TXT)

    if args.quoted:
        stamp = current_stamp(md_text)
        if args.quoted.strip() == stamp:
            print('[OK] the quoted stamp matches this file: %s' % stamp)
            return 0
        print('[!!] RE-PASTE OWED. Nothing is broken.')
        print('     the chat half quoted : %s' % args.quoted.strip())
        print('     this file says       : %s' % stamp)
        print('     Re-paste docs/claude-ai-project-instructions.txt into the')
        print('     claude.ai project settings. Do not edit the stamp to agree.')
        print('')
        print('     ⚠️  UNLESS YOU ALREADY RE-PASTED THIS SESSION. A fresh paste may')
        print('         not have reached the chat half yet. It has arrived on a')
        print('         mid-session re-read before, so ask for a re-quote first.')
        print('')
        print('     ⛔  AND BEFORE RE-PASTING: a mismatch does NOT prove this file is')
        print('         newer. If the paste was edited directly, IT is ahead, and a')
        print('         re-paste overwrites the newer text. Ask the chat half whether')
        print('         its copy holds anything this file lacks, and settle it')
        print('         against the code first.')
        return 1

    ok, problems = check(md_text, txt_text)
    if ok:
        print('[OK] stamp %s matches the content, and the .txt matches the .md'
              % current_stamp(md_text))
        print('     ^ the FILES agree. Whether the claude.ai PASTE carries this stamp')
        print('       is unknowable from here - ask the chat half to quote it.')
        return 0
    print('[!!] instructions stamp:')
    for p in problems:
        print('     ' + p)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
