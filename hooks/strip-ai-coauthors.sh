#!/usr/bin/env bash
# Strip AI-injected attribution from a commit message before the commit is created.
#
# Runs at the commit-msg stage and rewrites the message in place. It never fails the
# commit: matching the SHA-pinning hook's philosophy, it silently fixes rather than
# blocks, so an agent that writes a trailer cannot be stopped by ignoring an error.
#
# Removes:
#   - Co-Authored-By: lines naming a known AI vendor or agent address.
#   - "Generated with/by <AI tool>" promo footers, with or without a leading robot emoji.
#
# Human co-authors are left alone. Two rules keep it that way, and both have already
# been got wrong once:
#
#   1. NO bare `github` token in the vendor list. It matches the literal string inside
#      `users.noreply.github.com`, so it strips every human GitHub co-author while
#      leaving `openhands@all-hands.dev` untouched, which is exactly backwards. Match
#      `copilot` and the agent addresses instead.
#   2. Vendor tokens are matched only AFTER the `Co-Authored-By:` anchor, so a human
#      called Claudia or a company called Cursor Ltd is not caught by their name.
#
# WHAT THIS HOOK CANNOT DO. It only runs where pre-commit is installed, which means a
# developer workstation. It is absent from CI and from agent containers, and it cannot
# see a `Co-authored-by:` trailer that GitHub composes server-side when it squash-merges
# a pull request: GitHub credits every distinct commit-author email in the PR, and no
# client-side hook exists at that point. If trailers are appearing on your default
# branch, check `git log -1 --format=%cn` on the offending commit first. `GitHub` as the
# committer means this hook was never in the path, and the fix is to stop feeding the
# merge a second author identity, not to tighten the pattern here.
#
# Argument: $1 = path to the commit message file, as passed by the commit-msg hook.

set -Eeuo pipefail

STRIP_AI_VERBOSE=${STRIP_AI_VERBOSE:-1}   # 0=quiet, 1=announce when something is stripped

msg_file="${1:-}"
[[ -n "$msg_file" && -f "$msg_file" ]] || exit 0

# AI co-author trailers, case-insensitive, anchored to the trailer so vendor tokens
# can only match inside the address or the agent's own name.
ai_coauthor='^[[:space:]]*Co-Authored-By:.*('\
'anthropic|noreply@anthropic|claude'\
'|openai|noreply@openai|codex|chatgpt'\
'|openhands|all-hands[.]dev'\
'|warp[.]dev|oz-agent'\
'|copilot|copilot-swe-agent'\
'|devin|cognition[.]ai|cursor[.](com|sh)|windsurf|codeium'\
'|jules[.]google|aider|sourcegraph|sweep-ai|factory[.]ai'\
')'

# "Generated with/by <AI tool>" promo lines.
ai_generated='Generated[[:space:]]+(with|by).*(claude|codex|copilot|chatgpt|anthropic|openai|openhands|all-hands|cursor|windsurf|devin|warp)'

# Fast path: nothing to do.
if ! grep -iEq "$ai_coauthor|$ai_generated" "$msg_file"; then
  exit 0
fi

tmp="$(mktemp)"
# Drop the offending lines. `|| true` because grep exits 1 when every line is stripped.
grep -ivE "$ai_coauthor|$ai_generated" "$msg_file" > "$tmp" || true

# Collapse trailing blank lines the removal leaves behind, keeping internal blanks
# intact: blanks are buffered and only flushed once real content follows.
awk 'BEGIN{b=0} /^[[:space:]]*$/{b++; next} {while(b>0){print ""; b--}; print}' "$tmp" > "$msg_file"
rm -f "$tmp"

if [[ "${STRIP_AI_VERBOSE}" -ge 1 ]]; then
  echo "strip-ai-coauthors: removed AI co-author / generated-with trailer(s) from the commit message" >&2
fi
