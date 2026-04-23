"""
Quick connectivity check for OpenRouter.
Tests: (1) text completion, (2) vision with a 1x1 red PNG.
Run: python test_openrouter.py
"""

import json
import urllib.request
import base64

with open(".env.json") as f:
    env = json.load(f)

API_KEY  = env["OPENROUTER_API_KEY"]
BASE_URL = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
MODEL    = "qwen/qwen3.5-flash-02-23"

HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

def post(path, body):
    data = json.dumps(body).encode()
    req  = urllib.request.Request(BASE_URL + path, data=data, headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())

# ── 1. Text completion ────────────────────────────────────────────────────────
print(f"Base URL : {BASE_URL}")
print(f"Model    : {MODEL}")
print(f"Key      : {API_KEY[:8]}...")
print()

print("-- Test 1: text completion --")
status, resp = post("/chat/completions", {
    "model": MODEL,
    "messages": [{"role": "user", "content": "Reply with the single word: OK"}],
    "max_tokens": 10,
})
if status == 200 and "choices" in resp:
    reply = resp["choices"][0]["message"]["content"].strip()
    print(f"  OK {status}  reply: {reply!r}")
else:
    print(f"  FAIL {status}")
    print(f"     {json.dumps(resp, indent=2)}")

# ── 2. Vision (image in chat) ─────────────────────────────────────────────────
# 16x16 red PNG generated inline (Qwen requires >10px each side).
import zlib, struct

def _make_png(w, h, r, g, b):
    raw = b"".join(b"\x00" + bytes([r, g, b] * w) for _ in range(h))
    def chunk(tag, data):
        c = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", c)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))

RED_PNG_B64 = base64.b64encode(_make_png(16, 16, 255, 0, 0)).decode()

print()
print("-- Test 2: vision (1x1 image) --")
status, resp = post("/chat/completions", {
    "model": MODEL,
    "messages": [{
        "role": "user",
        "content": [
            {"type": "text",      "text": "What colour is this image? One word."},
            {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{RED_PNG_B64}"}},
        ],
    }],
    "max_tokens": 10,
})
if status == 200 and "choices" in resp:
    reply = resp["choices"][0]["message"]["content"].strip()
    print(f"  OK {status}  reply: {reply!r}")
else:
    print(f"  FAIL {status}")
    print(f"     {json.dumps(resp, indent=2)}")
