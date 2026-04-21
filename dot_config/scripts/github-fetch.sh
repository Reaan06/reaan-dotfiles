#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# github-fetch.sh — GitHub data fetcher (GraphQL v4 primary)
# ═══════════════════════════════════════════════════════════════
# Usage: github-fetch.sh <username> [token]
#   - With token:  Uses GraphQL API v4 for ALL data (single query)
#   - Without token: Falls back to REST API v3 (public data only)
# Output: Unified JSON to stdout
# ═══════════════════════════════════════════════════════════════

USERNAME="$1"
TOKEN="$2"

if [ -z "$USERNAME" ]; then
    echo '{"error":"no_username"}'
    exit 1
fi

# Temp dir for storing API responses safely
TMPDIR=$(mktemp -d /tmp/gh-fetch.XXXXXX)
trap "rm -rf $TMPDIR" EXIT

# ─────────────────────────────────────────────────────────
# PATH A: GraphQL v4 (preferred — requires PAT)
# One single query fetches everything we need.
# ─────────────────────────────────────────────────────────
if [ -n "$TOKEN" ]; then

    # GraphQL query — all data in a single request
    cat > "$TMPDIR/query.json" << ENDJSON
{
  "query": "query(\$u:String!){user(login:\$u){login name avatarUrl bio publicRepos:repositories(privacy:PUBLIC){totalCount}privateRepos:repositories(privacy:PRIVATE){totalCount}followers{totalCount}following{totalCount}repositories(first:6,orderBy:{field:PUSHED_AT,direction:DESC},ownerAffiliations:OWNER){nodes{name nameWithOwner isPrivate stargazerCount forkCount description pushedAt url primaryLanguage{name color}defaultBranchRef{target{...on Commit{history(first:1){nodes{message committedDate oid}}}}}}}contributionsCollection{contributionCalendar{totalContributions colors weeks{contributionDays{contributionCount date color weekday}}}totalCommitContributions totalPullRequestContributions totalIssueContributions totalPullRequestReviewContributions totalRepositoriesWithContributedCommits commitContributionsByRepository(maxRepositories:8){repository{nameWithOwner url primaryLanguage{name color}stargazerCount}contributions{totalCount}}}}}",
  "variables": {"u": "$USERNAME"}
}
ENDJSON

    # Execute single GraphQL request
    curl -s -m 15 \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$TMPDIR/query.json" \
        "https://api.github.com/graphql" > "$TMPDIR/graphql.json" 2>/dev/null

    # Events via REST (not available in GraphQL)
    curl -s -m 10 \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/users/$USERNAME/events?per_page=15" > "$TMPDIR/events.json" 2>/dev/null

    # Notifications via REST
    curl -s -m 10 \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/notifications?per_page=15" > "$TMPDIR/notifications.json" 2>/dev/null

    # Parse and unify via Python
    TMPDIR_PATH="$TMPDIR" python3 << 'PYEOF'
import json, sys, os

tmpdir = os.environ.get("TMPDIR_PATH", "/tmp")

def load(path, fallback):
    try:
        with open(path) as f:
            return json.load(f)
    except:
        return fallback

gql = load(os.path.join(tmpdir, "graphql.json"), {})
events_data = load(os.path.join(tmpdir, "events.json"), [])
notifications_data = load(os.path.join(tmpdir, "notifications.json"), [])

# Check for errors
if "errors" in gql:
    msg = gql["errors"][0].get("message", "GraphQL error")
    print(json.dumps({"error": "graphql_error", "message": msg}))
    sys.exit(0)

if "message" in gql:
    print(json.dumps({"error": "api_error", "message": gql["message"]}))
    sys.exit(0)

user = gql.get("data", {}).get("user")
if not user:
    print(json.dumps({"error": "user_not_found", "message": "User not found"}))
    sys.exit(0)

# ── Profile ──
profile = {
    "login": user.get("login", ""),
    "name": user.get("name", "") or user.get("login", ""),
    "avatar_url": user.get("avatarUrl", ""),
    "bio": user.get("bio", "") or "",
    "public_repos": user.get("publicRepos", {}).get("totalCount", 0),
    "private_repos": user.get("privateRepos", {}).get("totalCount", 0),
    "followers": user.get("followers", {}).get("totalCount", 0),
    "following": user.get("following", {}).get("totalCount", 0),
}

# ── Repos (from GraphQL — includes last commit) ──
repos = []
for r in (user.get("repositories", {}).get("nodes") or []):
    lang = r.get("primaryLanguage") or {}
    last_commit = ""
    last_commit_msg = ""
    branch = r.get("defaultBranchRef")
    if branch and branch.get("target"):
        history = branch["target"].get("history", {}).get("nodes", [])
        if history:
            last_commit = history[0].get("committedDate", "")
            last_commit_msg = history[0].get("message", "").split("\n")[0][:60]
    repos.append({
        "name": r.get("name", ""),
        "full_name": r.get("nameWithOwner", ""),
        "private": r.get("isPrivate", False),
        "stars": r.get("stargazerCount", 0),
        "forks": r.get("forkCount", 0),
        "description": (r.get("description") or "")[:80],
        "updated_at": r.get("pushedAt", ""),
        "language": lang.get("name", ""),
        "lang_color": lang.get("color", "#6c7086"),
        "last_commit": last_commit,
        "last_commit_msg": last_commit_msg,
        "url": r.get("url", f"https://github.com/{r.get('nameWithOwner', '')}"),
    })

# ── Contributions (from GraphQL — heatmap + stats) ──
cc = user.get("contributionsCollection", {})
cal = cc.get("contributionCalendar", {})
contributions = {
    "total": cal.get("totalContributions", 0),
    "commits": cc.get("totalCommitContributions", 0),
    "prs": cc.get("totalPullRequestContributions", 0),
    "issues": cc.get("totalIssueContributions", 0),
    "reviews": cc.get("totalPullRequestReviewContributions", 0),
    "repos_contributed": cc.get("totalRepositoriesWithContributedCommits", 0),
    "weeks": cal.get("weeks", []),
    "colors": cal.get("colors", []),
    "top_repos": []
}
for cr in cc.get("commitContributionsByRepository", []):
    repo = cr.get("repository", {})
    lang = repo.get("primaryLanguage") or {}
    contributions["top_repos"].append({
        "name": repo.get("nameWithOwner", ""),
        "commits": cr.get("contributions", {}).get("totalCount", 0),
        "language": lang.get("name", ""),
        "lang_color": lang.get("color", "#6c7086"),
        "stars": repo.get("stargazerCount", 0),
    })

# ── Events (from REST — not available in GraphQL) ──
events = []
for e in (events_data if isinstance(events_data, list) else [])[:15]:
    item = {
        "type": e.get("type", ""),
        "repo": e.get("repo", {}).get("name", ""),
        "created_at": e.get("created_at", ""),
        "url": f"https://github.com/{e.get('repo', {}).get('name', '')}",
    }
    p = e.get("payload", {})
    t = e.get("type", "")
    if t == "PushEvent":
        commits = p.get("commits", [])
        item["detail"] = commits[-1].get("message", "").split("\n")[0][:60] if commits else ""
        item["count"] = len(commits)
    elif t in ("PullRequestEvent", "IssuesEvent"):
        act = p.get("action", "")
        pr = p.get("pull_request", p.get("issue", {}))
        item["detail"] = f"{act}: {pr.get('title', '')}"[:60]
    elif t == "CreateEvent":
        item["detail"] = f"created {p.get('ref_type', '')} {p.get('ref', '')}"
    elif t == "WatchEvent":
        item["detail"] = "starred"
    elif t == "ForkEvent":
        item["detail"] = "forked → " + p.get("forkee", {}).get("full_name", "")
    elif t == "DeleteEvent":
        item["detail"] = f"deleted {p.get('ref_type', '')} {p.get('ref', '')}"
    elif t == "ReleaseEvent":
        item["detail"] = f"released {p.get('release', {}).get('tag_name', '')}"
    else:
        item["detail"] = ""
    events.append(item)

# ── Notifications (from REST) ──
notifications = []
for n in (notifications_data if isinstance(notifications_data, list) else [])[:15]:
    # Parse notification reason and title
    subject = n.get("subject", {})
    item = {
        "id": n.get("id", ""),
        "reason": n.get("reason", ""),
        "title": subject.get("title", ""),
        "type": subject.get("type", ""),
        "repo": n.get("repository", {}).get("full_name", ""),
        "updated_at": n.get("updated_at", ""),
    }
    
    # Construct a clickable URL since GitHub's raw subject URL is an API endpoint
    api_url = subject.get("url", "")
    html_url = ""
    repo_url = f"https://github.com/{item['repo']}"
    if api_url:
        # Simplistic conversion from api to html url (e.g. issues, pull requests)
        html_url = api_url.replace("api.github.com/repos/", "github.com/").replace("/pulls/", "/pull/")
    item["url"] = html_url if html_url else repo_url
    notifications.append(item)

# ── Streak calculation ──
all_days = []
for w in cal.get("weeks", []):
    for d in w.get("contributionDays", []):
        all_days.append(d)

current_streak = 0
longest_streak = 0
streak = 0
for d in reversed(all_days):
    if d.get("contributionCount", 0) > 0:
        streak += 1
        if streak > longest_streak:
            longest_streak = streak
    else:
        if current_streak == 0:
            current_streak = streak
        streak = 0
if current_streak == 0:
    current_streak = streak

contributions["current_streak"] = current_streak
contributions["longest_streak"] = longest_streak

print(json.dumps({
    "profile": profile,
    "events": events,
    "repos": repos,
    "notifications": notifications,
    "contributions": contributions,
    "has_token": True,
    "api": "graphql_v4",
}))
PYEOF

# ─────────────────────────────────────────────────────────
# PATH B: REST API v3 fallback (no token — public data only)
# ─────────────────────────────────────────────────────────
else
    curl -s -m 10 -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/users/$USERNAME" > "$TMPDIR/profile.json" 2>/dev/null

    # Check for errors early
    if grep -q '"message"' "$TMPDIR/profile.json" 2>/dev/null; then
        MSG=$(python3 -c "import json; print(json.load(open('$TMPDIR/profile.json')).get('message','error'))" 2>/dev/null)
        echo "{\"error\":\"api_error\",\"message\":\"$MSG\"}"
        exit 0
    fi

    curl -s -m 10 -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/users/$USERNAME/events/public?per_page=15" > "$TMPDIR/events.json" 2>/dev/null

    curl -s -m 10 -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/users/$USERNAME/repos?sort=pushed&per_page=6&direction=desc" > "$TMPDIR/repos.json" 2>/dev/null

    TMPDIR_PATH="$TMPDIR" python3 << 'PYEOF'
import json, os

tmpdir = os.environ.get("TMPDIR_PATH", "/tmp")

def load(path, fallback):
    try:
        with open(path) as f:
            return json.load(f)
    except:
        return fallback

pf = load(os.path.join(tmpdir, "profile.json"), {})
ev_data = load(os.path.join(tmpdir, "events.json"), [])
rp_data = load(os.path.join(tmpdir, "repos.json"), [])

profile = {
    "login": pf.get("login", ""),
    "name": pf.get("name", "") or pf.get("login", ""),
    "avatar_url": pf.get("avatar_url", ""),
    "bio": pf.get("bio", "") or "",
    "public_repos": pf.get("public_repos", 0),
    "private_repos": 0,
    "followers": pf.get("followers", 0),
    "following": pf.get("following", 0),
}

repos = []
for r in (rp_data if isinstance(rp_data, list) else [])[:6]:
    if isinstance(r, dict):
        repos.append({
            "name": r.get("name", ""),
            "full_name": r.get("full_name", ""),
            "private": r.get("private", False),
            "stars": r.get("stargazers_count", 0),
            "forks": r.get("forks_count", 0),
            "description": (r.get("description") or "")[:80],
            "updated_at": r.get("pushed_at", ""),
            "language": r.get("language") or "",
            "lang_color": "#6c7086",
            "last_commit": "",
            "last_commit_msg": "",
            "url": r.get("html_url", f"https://github.com/{r.get('full_name', '')}"),
        })

events = []
for e in (ev_data if isinstance(ev_data, list) else [])[:15]:
    item = {
        "type": e.get("type", ""),
        "repo": e.get("repo", {}).get("name", ""),
        "created_at": e.get("created_at", ""),
        "url": f"https://github.com/{e.get('repo', {}).get('name', '')}",
    }
    p = e.get("payload", {})
    t = e.get("type", "")
    if t == "PushEvent":
        commits = p.get("commits", [])
        item["detail"] = commits[-1].get("message", "").split("\n")[0][:60] if commits else ""
        item["count"] = len(commits)
    elif t in ("PullRequestEvent", "IssuesEvent"):
        act = p.get("action", "")
        pr = p.get("pull_request", p.get("issue", {}))
        item["detail"] = f"{act}: {pr.get('title', '')}"[:60]
    elif t == "CreateEvent":
        item["detail"] = f"created {p.get('ref_type', '')} {p.get('ref', '')}"
    elif t == "WatchEvent":
        item["detail"] = "starred"
    elif t == "ForkEvent":
        item["detail"] = "forked → " + p.get("forkee", {}).get("full_name", "")
    else:
        item["detail"] = ""
    events.append(item)

print(json.dumps({
    "profile": profile,
    "events": events,
    "repos": repos,
    "notifications": [],
    "contributions": None,
    "has_token": False,
    "api": "rest_v3",
}))
PYEOF

fi
