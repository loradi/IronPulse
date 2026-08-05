#!/usr/bin/env python3
"""One-time script: generates a pre-recorded .mp3 audio clip for every
phrase x language combination in IronPulse/Resources/FeedbackPhrases.json,
using the ElevenLabs text-to-speech API, and saves them to
IronPulse/Resources/SmartAssistantAudio/<id>_<language>.mp3.

Run again only if phrases are added/changed in FeedbackPhrases.json --
this is NOT part of the Xcode build, it's a manual asset-generation step.

Requires:
    ELEVENLABS_API_KEY          - your ElevenLabs API key (required)
    ELEVENLABS_VOICE_ID_ES      - voice ID to use for Spanish
    ELEVENLABS_VOICE_ID_EN      - voice ID to use for English
    ELEVENLABS_VOICE_ID_FR      - voice ID to use for French

If any ELEVENLABS_VOICE_ID_* is missing, the script queries
/v1/voices, prints every available premade voice with its metadata,
and exits so you can pick real, currently-available voice IDs rather
than relying on hardcoded names that might not exist on your account.

Usage:
    export ELEVENLABS_API_KEY=...
    export ELEVENLABS_VOICE_ID_ES=...
    export ELEVENLABS_VOICE_ID_EN=...
    export ELEVENLABS_VOICE_ID_FR=...
    python3 scripts/generate_smart_assistant_audio.py [--dry-run]
"""
import json
import os
import sys
import urllib.error
import urllib.request

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHRASES_PATH = os.path.join(REPO_ROOT, "IronPulse", "Resources", "FeedbackPhrases.json")
OUTPUT_DIR = os.path.join(REPO_ROOT, "IronPulse", "Resources", "SmartAssistantAudio")
API_BASE = "https://api.elevenlabs.io/v1"

LANGUAGES = ("es", "en", "fr")
VOICE_ID_ENV_VARS = {
    "es": "ELEVENLABS_VOICE_ID_ES",
    "en": "ELEVENLABS_VOICE_ID_EN",
    "fr": "ELEVENLABS_VOICE_ID_FR",
}


def load_jobs():
    with open(PHRASES_PATH, encoding="utf-8") as f:
        bank = json.load(f)
    jobs = []
    for phrases in bank.values():
        for phrase in phrases:
            for lang in LANGUAGES:
                jobs.append((phrase["id"], lang, phrase[lang]))
    return jobs


def api_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        print("ERROR: set the ELEVENLABS_API_KEY environment variable first.", file=sys.stderr)
        sys.exit(1)
    return key


def list_voices(key: str) -> list:
    req = urllib.request.Request(f"{API_BASE}/voices", headers={"xi-api-key": key})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)["voices"]


def resolve_voice_ids(key: str) -> dict:
    resolved = {}
    missing = []
    for lang, env_name in VOICE_ID_ENV_VARS.items():
        voice_id = os.environ.get(env_name)
        if voice_id:
            resolved[lang] = voice_id
        else:
            missing.append(lang)

    if missing:
        print(f"Missing voice ID env var(s) for: {', '.join(missing)}")
        print("Available premade voices on this account:")
        for v in list_voices(key):
            print(f"  {v['voice_id']}  {v.get('name')}  labels={v.get('labels', {})}")
        print("\nSet the corresponding ELEVENLABS_VOICE_ID_<LANG> env var(s) and re-run.")
        sys.exit(1)

    return resolved


def generate_clip(key: str, voice_id: str, text: str, out_path: str) -> None:
    url = f"{API_BASE}/text-to-speech/{voice_id}"
    body = json.dumps({
        "text": text,
        "model_id": "eleven_multilingual_v2",
    }).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST", headers={
        "xi-api-key": key,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    })
    with urllib.request.urlopen(req) as resp:
        audio = resp.read()
    with open(out_path, "wb") as f:
        f.write(audio)


def main() -> None:
    jobs = load_jobs()
    print(f"{len(jobs)} clips to generate.")

    if "--dry-run" in sys.argv:
        # Self-check: confirms the JSON parses and every job has
        # non-empty id/text before touching the network at all.
        assert len(jobs) > 0, "no phrases found in FeedbackPhrases.json"
        for phrase_id, lang, text in jobs:
            assert phrase_id, "found a phrase with an empty id"
            assert text.strip(), f"empty {lang} text for {phrase_id}"
        for phrase_id, lang, text in jobs[:5]:
            print(f"  [dry-run] {phrase_id}_{lang}.mp3 <- \"{text}\"")
        print("Dry run OK - no API calls made, no files written.")
        return

    key = api_key()
    voice_ids = resolve_voice_ids(key)
    for lang, voice_id in voice_ids.items():
        print(f"Using voice for '{lang}': {voice_id}")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    failures = []
    for i, (phrase_id, lang, text) in enumerate(jobs, start=1):
        out_path = os.path.join(OUTPUT_DIR, f"{phrase_id}_{lang}.mp3")
        if os.path.exists(out_path):
            print(f"[{i}/{len(jobs)}] skip (exists): {phrase_id}_{lang}.mp3")
            continue
        try:
            generate_clip(key, voice_ids[lang], text, out_path)
            print(f"[{i}/{len(jobs)}] wrote {phrase_id}_{lang}.mp3")
        except urllib.error.HTTPError as e:
            failures.append(f"{phrase_id}_{lang}.mp3: {e.code} {e.read().decode(errors='replace')}")
            print(f"[{i}/{len(jobs)}] FAILED {phrase_id}_{lang}.mp3: {e.code}", file=sys.stderr)

    print(f"Done. {len(jobs) - len(failures)}/{len(jobs)} succeeded.")
    if failures:
        print("Failures:", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
