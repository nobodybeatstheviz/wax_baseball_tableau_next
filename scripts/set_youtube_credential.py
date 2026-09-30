"""Set the YouTube Data API key on the YouTube_API External Credential principal.

The key lives in ~/.gcs/keeping-score-youtube-key.json (gcloud api-keys create
--format=json output; never in source, never printed). The `sf api request rest`
shim 404s Connect endpoints on this machine, so this goes direct HTTP with the
CLI's own token (SF_TEMP_SHOW_SECRETS pattern, same as the 9/4 probes).

Usage: python scripts/set_youtube_credential.py [org-alias]   (default keeping-score-w6a)
"""

import json
import os
import subprocess
import sys
import urllib.request

ORG = sys.argv[1] if len(sys.argv) > 1 else "keeping-score-w6a"
KEY_FILE = os.path.expanduser("~/.gcs/keeping-score-youtube-key.json")
API = "v67.0"


def org_auth(alias: str):
    out = subprocess.run(
        ["sf", "org", "display", "-o", alias, "--json"],
        capture_output=True, text=True, shell=(os.name == "nt"),
        env={**os.environ, "SF_TEMP_SHOW_SECRETS": "true"},
    )
    r = json.loads(out.stdout)["result"]
    return r["instanceUrl"].rstrip("/"), r["accessToken"]


def main():
    key_doc = json.load(open(KEY_FILE))
    key = key_doc.get("response", key_doc)["keyString"]
    instance, token = org_auth(ORG)

    body = {
        "externalCredential": "YouTube_API",
        "principalType": "NamedPrincipal",
        "principalName": "YouTube_Principal",
        "authenticationProtocol": "Custom",
        "credentials": {"ApiKey": {"value": key, "encrypted": True}},
    }
    url = f"{instance}/services/data/{API}/named-credentials/credential"
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            doc = json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        detail = e.read().decode()
        # An existing principal credential wants PUT, not POST.
        if e.code == 400 and "already exists" in detail.lower():
            req = urllib.request.Request(
                url, data=json.dumps(body).encode(), method="PUT",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req) as resp:
                doc = json.loads(resp.read() or b"{}")
        else:
            print(f"HTTP {e.code}: {detail}", file=sys.stderr)
            sys.exit(1)

    # Never echo credential values back; report shape only.
    creds = doc.get("credentials", {})
    print(f"principal set: {doc.get('principalName')} on {doc.get('externalCredential')}")
    print(f"credential names stored: {sorted(creds.keys())}")


if __name__ == "__main__":
    main()
