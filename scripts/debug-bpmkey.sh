#!/usr/bin/env bash
# Debug Spotify BPM/Key lookup as used by BpmKey.qml
# - Supports bearer token or client credentials (client id/secret)
# - Accepts artist/title/album via args or auto-detects using playerctl
# - Prints detailed logs, HTTP status, and parsed BPM/Key
#
# Usage examples:
#   scripts/debug-bpmkey.sh --bearer "$TOKEN" --artist "Daft Punk" --title "Get Lucky" --album "Random Access Memories"
#   scripts/debug-bpmkey.sh --cid "$SPOTIFY_CLIENT_ID" --secret "$SPOTIFY_CLIENT_SECRET" --artist "Daft Punk" --title "Get Lucky"
#   scripts/debug-bpmkey.sh --from-player  # uses playerctl to read current track
#
# Requirements: curl, jq; optional: playerctl (for --from-player)

set -Eeuo pipefail
IFS=$'\n\t'

log()  { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
err()  { printf "[%s] ERROR: %s\n" "$(date +%H:%M:%S)" "$*" >&2; }
die()  { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

if ! have curl; then die "curl not found"; fi
if ! have jq;   then die "jq not found"; fi
# Simple JSON cache helpers
save_token_cache() {
  local f="$1" access="$2" refresh="$3" expires_in="$4"
  [[ -n "$f" ]] || return 0
  jq -n --arg access "$access" --arg refresh "${refresh:-}" --argjson exp ${expires_in:-0} \
    '{access_token:$access, refresh_token:$refresh, expires_in:$exp, saved_at: now|floor}' > "$f.tmp"
  mv "$f.tmp" "$f"
}

load_token_cache() {
  local f="$1"
  [[ -n "$f" && -f "$f" ]] || return 1
  ACCESS_CACHED=$(jq -r '.access_token // empty' "$f")
  REFRESH_CACHED=$(jq -r '.refresh_token // empty' "$f")
  EXPIRES_CACHED=$(jq -r '.expires_in // 0' "$f")
  SAVED_AT=$(jq -r '.saved_at // 0' "$f")
  return 0
}

is_token_expired() {
  # Consider expired if saved_at + expires_in - 30s < now
  local now=$(date +%s)
  local expires_at=$(( SAVED_AT + EXPIRES_CACHED - 30 ))
  [[ $now -ge $expires_at ]]
}

refresh_user_token() {
  local cid="$CID" refresh="$1"
  [[ -n "$refresh" ]] || die "No refresh token available"
  resp=$(curl -sS --max-time 15 -u "$cid:$SECRET" -d grant_type=refresh_token \
                -d refresh_token="$refresh" https://accounts.spotify.com/api/token \
                -w "\nHTTP_STATUS:%{http_code}")
  status=${resp##*HTTP_STATUS:}
  body=${resp%HTTP_STATUS:*}
  log "Refresh token status: $status"
  if [[ "$status" -ge 400 ]]; then
    err "Refresh error ($status): $(echo "$body" | head -c 200)"; return 1
  fi
  USER_ACCESS_TOKEN=$(echo "$body" | jq -r '.access_token // empty')
  USER_EXPIRES_IN=$(echo "$body" | jq -r '.expires_in // 0')
  NEW_REFRESH=$(echo "$body" | jq -r '.refresh_token // empty')
  [[ -n "$USER_ACCESS_TOKEN" ]] || die "No access_token in refresh response"
  if [[ -n "$TOKEN_FILE" ]]; then
    save_token_cache "$TOKEN_FILE" "$USER_ACCESS_TOKEN" "${NEW_REFRESH:-$refresh}" "$USER_EXPIRES_IN"
  fi
  TOKEN="$USER_ACCESS_TOKEN"
  EXP_HINT="user_auth(${USER_EXPIRES_IN}s,refreshed)"
}

# Minimal local HTTP server to capture OAuth code
start_local_listener() {
  if ! have python3; then die "--listen requires python3"; fi
  local port path temp
  # Extract port and path from REDIRECT_URI; default port 9876, path '/'
  port=$(echo "$REDIRECT_URI" | sed -nE 's#.*:([0-9]+).*#\1#p')
  [[ -n "$port" ]] || port=9876
  path=$(echo "$REDIRECT_URI" | sed -nE 's#https?://[^/]+(/.*)#\1#p')
  [[ -n "$path" ]] || path="/"
  CODE_FILE=$(mktemp)
  log "Starting local HTTP listener on 127.0.0.1:${port} to capture OAuth code (path $path)"
  python3 - <<PY >/dev/null 2>&1 &
import http.server, socketserver, urllib.parse, threading
PORT=$port
OUT_FILE=r"$CODE_FILE"
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            u=urllib.parse.urlparse(self.path)
            qs=urllib.parse.parse_qs(u.query)
            code=qs.get('code',[''])[0]
            with open(OUT_FILE,'w') as f:
                f.write(code)
            self.send_response(200)
            self.send_header('Content-Type','text/plain')
            self.end_headers()
            self.wfile.write(b'You can close this window now.')
        finally:
            threading.Thread(target=self.server.shutdown, daemon=True).start()
    def log_message(self, *args):
        pass
with socketserver.TCPServer(("127.0.0.1", PORT), H) as httpd:
    httpd.serve_forever()
PY
  SERVER_PID=$!
}

# Inputs
ARTIST=""
TITLE=""
ALBUM=""
CID=""
SECRET=""
BEARER=""
FROM_PLAYER=0
USER_AGENT=""
AUTH_USER=0
REDIRECT_URI=""
SCOPES=""
DEBUG_TOKENS=0
TOKEN_FILE=""
LISTEN=0
MARKET_FROM_TOKEN=0

# Env var fallbacks for client credentials
CID=${CID:-${SPOTIFY_CLIENT_ID:-}}
SECRET=${SECRET:-${SPOTIFY_CLIENT_SECRET:-}}

urlenc() {
  # URL-encode via jq
  jq -rn --arg s "$1" '$s|@uri'
}

key_from_numeric() {
  local n mode
  n=$1; mode=$2
  case $n in
    0)  local tonic=C ;;
    1)  local tonic=C# ;;
    2)  local tonic=D ;;
    3)  local tonic=D# ;;
    4)  local tonic=E ;;
    5)  local tonic=F ;;
    6)  local tonic=F# ;;
    7)  local tonic=G ;;
    8)  local tonic=G# ;;
    9)  local tonic=A ;;
    10) local tonic=A# ;;
    11) local tonic=B ;;
    *)  echo ""; return 0 ;;
  esac
  if [[ "$mode" == "0" ]]; then
    echo "${tonic}m"
  else
    echo "${tonic}"
  fi
}

# GET helper with single 401 retry via refresh_token (if available)
api_get() {
  local url="$1" stage="${2:-request}" capture_headers="${3:-0}"
  local hdrfile=""
  if [[ "$capture_headers" == "1" ]]; then hdrfile=$(mktemp); fi
  if [[ -n "$hdrfile" ]]; then
    RESP=$(curl -sS --max-time 10 -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' "${UA_ARGS[@]}" -D "$hdrfile" "$url" -w "\nHTTP_STATUS:%{http_code}")
  else
    RESP=$(curl -sS --max-time 10 -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' "${UA_ARGS[@]}" "$url" -w "\nHTTP_STATUS:%{http_code}")
  fi
  STATUS=${RESP##*HTTP_STATUS:}
  BODY=${RESP%HTTP_STATUS:*}
  HEADERS=""
  if [[ -n "$hdrfile" ]]; then
    HEADERS=$(cat "$hdrfile")
    rm -f "$hdrfile" || true
  fi
  if [[ "$STATUS" == "401" && -n "$TOKEN_FILE" && -f "$TOKEN_FILE" && -n "$CID" && -n "$SECRET" ]]; then
    # Attempt refresh and retry once
    if load_token_cache "$TOKEN_FILE" && [[ -n "${REFRESH_CACHED:-}" ]]; then
      log "401 on $stage; attempting token refresh and retry"
      if refresh_user_token "$REFRESH_CACHED"; then
        if [[ -n "$hdrfile" ]]; then hdrfile=$(mktemp); fi
        if [[ -n "$hdrfile" ]]; then
          RESP=$(curl -sS --max-time 10 -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' "${UA_ARGS[@]}" -D "$hdrfile" "$url" -w "\nHTTP_STATUS:%{http_code}")
        else
          RESP=$(curl -sS --max-time 10 -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' "${UA_ARGS[@]}" "$url" -w "\nHTTP_STATUS:%{http_code}")
        fi
        STATUS=${RESP##*HTTP_STATUS:}
        BODY=${RESP%HTTP_STATUS:*}
        HEADERS=""
        if [[ -n "$hdrfile" ]]; then HEADERS=$(cat "$hdrfile"); rm -f "$hdrfile" || true; fi
        log "$stage retry status: $STATUS, bytes: ${#BODY}"
      else
        err "Token refresh failed after 401; continuing with original response"
      fi
    fi
  fi
}

# Perform Authorization Code flow by guiding the user through opening a browser and pasting the code
auth_code_flow() {
  local cid="$CID" redirect="$REDIRECT_URI" scopes="$SCOPES"
  [[ -n "$cid" && -n "$SECRET" ]] || die "--auth-user requires --cid and --secret"
  [[ -n "$redirect" ]] || die "--auth-user requires --redirect-uri"
  local scope_enc
  if [[ -n "$scopes" ]]; then scope_enc=$(jq -rn --arg s "$scopes" '$s|@uri'); else scope_enc=""; fi
  local authorize_url="https://accounts.spotify.com/authorize?client_id=$(jq -rn --arg s "$cid" '$s|@uri')&response_type=code&redirect_uri=$(jq -rn --arg s "$redirect" '$s|@uri')&show_dialog=true"
  if [[ -n "$scope_enc" ]]; then authorize_url+="&scope=$scope_enc"; fi
  if [[ $LISTEN -eq 1 ]]; then
    start_local_listener
    printf "\nOpen this URL in your browser to authorize (listening on %s):\n%s\n\n" "$REDIRECT_URI" "$authorize_url"
    # Try to open browser automatically (best-effort)
    if have xdg-open; then xdg-open "$authorize_url" >/dev/null 2>&1 || true; fi
    # Wait up to 120s for code file
    for i in $(seq 1 120); do
      if [[ -s "$CODE_FILE" ]]; then break; fi
      if (( i % 10 == 0 )); then log "Waiting for OAuth redirect... ($i s)"; fi
      sleep 1
    done
    AUTH_CODE=""
    if [[ -s "$CODE_FILE" ]]; then AUTH_CODE=$(tr -d '\r\n' < "$CODE_FILE"); fi
    if [[ -n "$AUTH_CODE" ]]; then
      log "Captured auth code (len=${#AUTH_CODE}). Exchanging for token..."
    fi
    [[ -n "$AUTH_CODE" ]] || die "Did not capture auth code on $REDIRECT_URI"
    # Stop listener if still running and clean up temp file
    if [[ -n "${SERVER_PID:-}" ]]; then kill "$SERVER_PID" >/dev/null 2>&1 || true; fi
    rm -f "$CODE_FILE" || true
  else
    printf "\nOpen this URL in your browser, authorize the app, and paste the 'code' query param below:\n%s\n\n" "$authorize_url"
    read -r -p "Enter code=: " AUTH_CODE
    [[ -n "$AUTH_CODE" ]] || die "Empty auth code"
  fi
  # Exchange code for tokens
  local resp status body
  resp=$(curl -sS --max-time 15 -u "$cid:$SECRET" -d grant_type=authorization_code \
                -d code="$AUTH_CODE" -d redirect_uri="$redirect" https://accounts.spotify.com/api/token \
                -w "\nHTTP_STATUS:%{http_code}")
  status=${resp##*HTTP_STATUS:}
  body=${resp%HTTP_STATUS:*}
  log "User token exchange status: $status"
  if [[ "$status" -ge 400 ]]; then
    err "User token error ($status): $(echo "$body" | head -c 200)"; exit 1
  fi
  USER_ACCESS_TOKEN=$(echo "$body" | jq -r '.access_token // empty')
  USER_REFRESH_TOKEN=$(echo "$body" | jq -r '.refresh_token // empty')
  USER_EXPIRES_IN=$(echo "$body" | jq -r '.expires_in // 0')
  [[ -n "$USER_ACCESS_TOKEN" ]] || die "No access_token in user token response"
  if [[ $DEBUG_TOKENS -eq 1 ]]; then
    log "User access token: $USER_ACCESS_TOKEN"
    log "User refresh token: ${USER_REFRESH_TOKEN:-<none>}"
  fi
  if [[ -n "$TOKEN_FILE" ]]; then
    save_token_cache "$TOKEN_FILE" "$USER_ACCESS_TOKEN" "$USER_REFRESH_TOKEN" "$USER_EXPIRES_IN"
  fi
  EXP_HINT="user_auth(${USER_EXPIRES_IN}s)"
  TOKEN="$USER_ACCESS_TOKEN"
}

print_help() {
  cat <<'EOF'
Usage: debug-bpmkey.sh [options]
  --artist NAME          Track artist
  --title NAME           Track title
  --album NAME           Track album (optional)
  --cid ID               Spotify Client ID
  --secret SECRET        Spotify Client Secret
  --bearer TOKEN         Spotify Bearer token (overrides client credentials)
  --auth-user            Perform interactive Authorization Code flow to get a user bearer token
  --redirect-uri URL     Redirect URI registered in your Spotify app (required with --auth-user)
  --scopes "S1 S2"       Space-separated scopes for user auth (optional; none needed for audio-features)
  --token-file FILE      Cache access/refresh tokens in FILE (JSON). Auto-refresh when expired.
  --market-from-token    Add market=from_token to /search (opt-in; can cause 403 on some tokens)
  --listen               Run a tiny local HTTP server to capture the OAuth code automatically (requires redirect to localhost with a port)
  --from-player          Use playerctl to detect current artist/title/album
  --user-agent UA        Set a custom User-Agent header for API calls
  --debug-tokens         Print tokens in logs (security risk; for local debugging only)
  -h, --help             Show this help

Order of auth preference:
  1) --bearer TOKEN
  2) --auth-user (Authorization Code flow)
  3) --cid/--secret -> client credentials flow

Examples:
  debug-bpmkey.sh --bearer "$TOKEN" --artist "Daft Punk" --title "Get Lucky" --album "Random Access Memories"
  debug-bpmkey.sh --cid "$ID" --secret "$SEC" --artist "Pink Floyd" --title "Money"
  debug-bpmkey.sh --auth-user --cid "$ID" --secret "$SEC" --redirect-uri "http://localhost/callback" --artist "Daft Punk" --title "Get Lucky"
  debug-bpmkey.sh --from-player
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --artist) ARTIST=${2-}; shift 2 ;;
    --title)  TITLE=${2-}; shift 2 ;;
    --album)  ALBUM=${2-}; shift 2 ;;
    --cid)    CID=${2-}; shift 2 ;;
    --secret) SECRET=${2-}; shift 2 ;;
    --bearer) BEARER=${2-}; shift 2 ;;
  --token-file) TOKEN_FILE=${2-}; shift 2 ;;
  --market-from-token) MARKET_FROM_TOKEN=1; shift ;;
  --auth-user) AUTH_USER=1; shift ;;
  --redirect-uri) REDIRECT_URI=${2-}; shift 2 ;;
  --scopes) SCOPES=${2-}; shift 2 ;;
  --listen) LISTEN=1; shift ;;
    --from-player) FROM_PLAYER=1; shift ;;
    --user-agent) USER_AGENT=${2-}; shift 2 ;;
  --debug-tokens) DEBUG_TOKENS=1; shift ;;
    -h|--help) print_help; exit 0 ;;
    *) err "Unknown arg: $1"; print_help; exit 2 ;;
  esac
done

if [[ $FROM_PLAYER -eq 1 ]]; then
  if ! have playerctl; then die "--from-player requested but playerctl not found"; fi
  # Try active player first, then any metadata
  ARTIST=${ARTIST:-$(playerctl metadata xesam:artist 2>/dev/null | head -n1 || true)}
  TITLE=${TITLE:-$(playerctl metadata xesam:title  2>/dev/null | head -n1 || true)}
  ALBUM=${ALBUM:-$(playerctl metadata xesam:album  2>/dev/null | head -n1 || true)}
fi

ARTIST=${ARTIST:-}
TITLE=${TITLE:-}
ALBUM=${ALBUM:-}

log "Artist: ${ARTIST:-<none>}"
log "Title : ${TITLE:-<none>}"
log "Album : ${ALBUM:-<none>}"

if [[ -z "$ARTIST" || -z "$TITLE" ]]; then
  die "artist and title are required (use --from-player or pass --artist/--title)"
fi

# Acquire token if needed
TOKEN=""
EXP_HINT=""
# Auth priority (progressive fallthrough): explicit bearer -> token-file (auto-refresh) -> --auth-user -> client credentials
if [[ -n "$BEARER" ]]; then
  TOKEN="$BEARER"; EXP_HINT="bearer(assume ~1h)"; log "Using provided bearer token"
fi

if [[ -z "$TOKEN" && -n "$TOKEN_FILE" && -f "$TOKEN_FILE" ]]; then
  log "Loading cached tokens from $TOKEN_FILE"
  if load_token_cache "$TOKEN_FILE"; then
    if [[ -n "${ACCESS_CACHED:-}" ]]; then
      SAVED_AT=${SAVED_AT:-0}; EXPIRES_CACHED=${EXPIRES_CACHED:-0}
      if is_token_expired; then
        log "Cached access token appears expired"
        if [[ -n "${REFRESH_CACHED:-}" && -n "$CID" && -n "$SECRET" ]]; then
          log "Attempting to refresh using refresh_token"
          refresh_user_token "$REFRESH_CACHED" || true
        else
          log "No refresh_token or client credentials available to refresh"
        fi
      else
        TOKEN="$ACCESS_CACHED"; EXP_HINT="user_auth(cached)"
      fi
    else
      log "Token cache present but no access_token"
      if [[ -n "${REFRESH_CACHED:-}" && -n "$CID" && -n "$SECRET" ]]; then
        log "Attempting to exchange refresh_token for a new access token"
        refresh_user_token "$REFRESH_CACHED" || true
      fi
    fi
  fi
fi

if [[ -z "$TOKEN" && $AUTH_USER -eq 1 ]]; then
  # If a token cache exists, try to use/refresh it
  if [[ -n "$TOKEN_FILE" && -f "$TOKEN_FILE" ]]; then
    log "Loading cached tokens from $TOKEN_FILE"
    if load_token_cache "$TOKEN_FILE"; then
      if [[ -n "$ACCESS_CACHED" && -n "$REFRESH_CACHED" ]]; then
        SAVED_AT=${SAVED_AT:-0}; EXPIRES_CACHED=${EXPIRES_CACHED:-0}
        if is_token_expired; then
          log "Cached access token expired; refreshing"
          if refresh_user_token "$REFRESH_CACHED"; then :; else log "Refresh failed; performing full auth"; auth_code_flow; fi
        else
          TOKEN="$ACCESS_CACHED"; EXP_HINT="user_auth(cached)"
        fi
      else
        log "Cache missing access/refresh; performing full auth"
        auth_code_flow
      fi
    else
      auth_code_flow
    fi
  else
    auth_code_flow
  fi
fi

if [[ -z "$TOKEN" ]]; then
  if [[ -n "$CID" && -n "$SECRET" ]]; then
    log "Requesting Spotify bearer token via client credentials flow (no scopes allowed)"
    AUTH=$(printf '%s:%s' "$CID" "$SECRET" | base64 -w0)
    RESP=$(curl -sS --max-time 8 -H "Authorization: Basic $AUTH" -H 'Accept: application/json' \
                 -d grant_type=client_credentials https://accounts.spotify.com/api/token \
                 -w "\nHTTP_STATUS:%{http_code}")
    STATUS=${RESP##*HTTP_STATUS:}
    BODY=${RESP%HTTP_STATUS:*}
    log "Token status: $STATUS"
    if [[ "$STATUS" -ge 400 ]]; then
      err "Token error ($STATUS): $(echo "$BODY" | head -c 200)"; exit 1
    fi
    TOKEN=$(echo "$BODY" | jq -r '.access_token // empty')
    EXPIRES=$(echo "$BODY" | jq -r '.expires_in // 0')
    [[ -n "$TOKEN" ]] || die "No access_token in response"
    EXP_HINT="client_credentials(${EXPIRES}s)"
  else
    die "No auth: provide --bearer, --auth-user, or --cid/--secret"
  fi
fi

# Token debug summary
if [[ -n "$TOKEN" ]]; then
  local_len=${#TOKEN}
  tail6=${TOKEN: -6}
  log "Using bearer token (len=${local_len}, tail=***${tail6})"
fi

UA_ARGS=()
if [[ -n "$USER_AGENT" ]]; then
  UA_ARGS+=( -H "User-Agent: $USER_AGENT" )
fi

log_sanitized_auth() {
  local local_len=${#TOKEN}
  local tail6=${TOKEN: -6}
  log "Request headers (sanitized):"
  log "  Accept: application/json"
  log "  Authorization: Bearer ***${tail6} (len=${local_len})"
  if [[ -n "$USER_AGENT" ]]; then log "  User-Agent: $USER_AGENT"; fi
}

log_sanitized_auth

# Quick probe of /v1/me using the same header to validate token type/validity
api_get "https://api.spotify.com/v1/me" "me" 1
log "Me status: $STATUS, bytes: ${#BODY}"
if [[ -n "$HEADERS" ]]; then
  MH=$(echo "$HEADERS" | sed -n '1p; s/^/  /; /www-authenticate:/Ip; /retry-after:/Ip; /content-type:/Ip; /content-length:/Ip')
  log "Me headers:\n$MH"
fi
if [[ "$STATUS" == "200" ]]; then
  ME_NAME=$(echo "$BODY" | jq -r '.display_name // empty')
  ME_ID=$(echo "$BODY" | jq -r '.id // empty')
  if [[ -n "$ME_ID" || -n "$ME_NAME" ]]; then log "Me entity: ${ME_NAME:-<no-name>} (id=${ME_ID:-<n/a>})"; fi
else
  log "Note: 401 on /v1/me is expected with client-credentials tokens; 403/429 indicate server-side restrictions."
fi

# Search track (try with album first, then without)
q_artist=$(urlenc "$ARTIST")
q_title=$(urlenc "$TITLE")
q_album=""
if [[ -n "$ALBUM" ]]; then q_album="+album:$(urlenc "$ALBUM")"; fi

# market=from_token is opt-in; default off to avoid 403 on some tokens
MARKET_ARG=""
if [[ $MARKET_FROM_TOKEN -eq 1 ]]; then MARKET_ARG="&market=from_token"; fi

SEARCH_URL="https://api.spotify.com/v1/search?q=track:${q_title}+artist:${q_artist}${q_album}&type=track${MARKET_ARG}&limit=1"
log "Search URL: $SEARCH_URL"
api_get "$SEARCH_URL" "search"
log "Search status: $STATUS, bytes: ${#BODY}"

# Log selected fields of the top search result (if any)
SEL_NAME=$(echo "$BODY" | jq -r '.tracks.items[0].name // empty')
SEL_ARTS=$(echo "$BODY" | jq -r '[.tracks.items[0].artists[].name] | join(", ") // empty')
SEL_ALB=$(echo "$BODY" | jq -r '.tracks.items[0].album.name // empty')
SEL_REL=$(echo "$BODY" | jq -r '.tracks.items[0].album.release_date // empty')
if [[ -n "$SEL_NAME" ]]; then
  log "Selected track: $SEL_NAME — $SEL_ARTS | album: $SEL_ALB ($SEL_REL)"
fi

# If /search failed with 403 (often due to market=from_token), retry once without market
if [[ "$STATUS" -ge 400 ]]; then
  short_body=$(echo "$BODY" | head -c 200)
  log "Search error ($STATUS): $short_body"
  if [[ $MARKET_FROM_TOKEN -eq 1 ]]; then
    log "Retrying search without market=from_token"
    MARKET_ARG=""
    SEARCH_URL="https://api.spotify.com/v1/search?q=track:${q_title}+artist:${q_artist}${q_album}&type=track&limit=1"
    log "Search URL (retry1): $SEARCH_URL"
    api_get "$SEARCH_URL" "search(retry1)"
    log "Search(retry1) status: $STATUS, bytes: ${#BODY}"
  fi
fi

# Extract track id (if any)
TRACK_ID=$(echo "$BODY" | jq -r '.tracks.items[0].id // empty')
if [[ -z "$TRACK_ID" && -n "$ALBUM" ]]; then
  log "No result with album; retrying without album"
  SEARCH_URL="https://api.spotify.com/v1/search?q=track:${q_title}+artist:${q_artist}&type=track${MARKET_ARG}&limit=1"
  api_get "$SEARCH_URL" "search(no-album)"
  log "Search(no-album) status: $STATUS, bytes: ${#BODY}"
  TRACK_ID=$(echo "$BODY" | jq -r '.tracks.items[0].id // empty')
fi

if [[ -z "$TRACK_ID" ]]; then
  err "No track found. Body (truncated): $(echo "$BODY" | head -c 200)"
  exit 2
fi

log "Track ID: $TRACK_ID"

# Fetch audio features
FEATURES_URL="https://api.spotify.com/v1/audio-features/$TRACK_ID"
log "Features URL: $FEATURES_URL"
api_get "$FEATURES_URL" "features" 1
log "Features status: $STATUS, bytes: ${#BODY}"
if [[ -n "$HEADERS" ]]; then
  # Log a few useful response headers (trimmed)
  WH=$(echo "$HEADERS" | sed -n '1p; s/^/  /; /www-authenticate:/Ip; /retry-after:/Ip; /content-type:/Ip; /content-length:/Ip')
  log "Features headers:\n$WH"
fi

if [[ "$STATUS" -ge 400 ]]; then
  err "Features error ($STATUS): $(echo "$BODY" | head -c 400)"
  # Sanity check track accessibility
  TRACKS_URL="https://api.spotify.com/v1/tracks/$TRACK_ID"
  log "Verifying track endpoint: $TRACKS_URL"
  api_get "$TRACKS_URL" "tracks" 1
  log "Tracks status: $STATUS, bytes: ${#BODY}"
  if [[ -n "$HEADERS" ]]; then
    TH=$(echo "$HEADERS" | sed -n '1p; s/^/  /; /www-authenticate:/Ip; /retry-after:/Ip; /content-type:/Ip; /content-length:/Ip')
    log "Tracks headers:\n$TH"
  fi
  T_NAME=$(echo "$BODY" | jq -r '.name // empty')
  T_ARTS=$(echo "$BODY" | jq -r '[.artists[].name] | join(", ") // empty')
  if [[ -n "$T_NAME" ]]; then log "Tracks entity: $T_NAME — $T_ARTS"; fi

  # Fallback attempt via batch endpoint
  BATCH_URL="https://api.spotify.com/v1/audio-features?ids=$TRACK_ID"
  log "Attempting batch features endpoint: $BATCH_URL"
  api_get "$BATCH_URL" "features(batch)" 1
  log "Features(batch) status: $STATUS, bytes: ${#BODY}"
  if [[ -n "$HEADERS" ]]; then
    BH=$(echo "$HEADERS" | sed -n '1p; s/^/  /; /www-authenticate:/Ip; /retry-after:/Ip; /content-type:/Ip; /content-length:/Ip')
    log "Features(batch) headers:\n$BH"
  fi
  exit 3
fi

TEMPO=$(echo "$BODY" | jq -r '.tempo // 0' | awk '{printf("%d", $1+0)}')
KEYNUM=$(echo "$BODY" | jq -r '.key // -1')
MODE=$(echo "$BODY" | jq -r '.mode // -1')

HUMAN_KEY=""
if [[ "$KEYNUM" =~ ^[0-9]+$ && "$MODE" =~ ^[0-9]+$ ]]; then
  HUMAN_KEY=$(key_from_numeric "$KEYNUM" "$MODE")
fi

printf "\nResult\n------\n"
printf "Artist : %s\n" "$ARTIST"
printf "Title  : %s\n" "$TITLE"
printf "Album  : %s\n" "${ALBUM:-<n/a>}"
printf "Auth   : %s\n" "$EXP_HINT"
printf "TrackID: %s\n" "$TRACK_ID"
printf "BPM    : %s\n" "${TEMPO:-0}"
printf "Key    : %s\n" "${HUMAN_KEY:-}"
