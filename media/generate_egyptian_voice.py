"""Generate an AI voice audition first. No keys are saved or printed.

Usage: python media/generate_egyptian_voice.py
       python media/generate_egyptian_voice.py --all
Requires OPENAI_API_KEY in the process environment.
"""
import argparse, ast, getpass, json, os, pathlib, sys, urllib.request, urllib.error

ROOT = pathlib.Path(__file__).resolve().parent
INSTRUCTIONS = '''Speak as a native Egyptian man from Cairo, approximately 30-35 years old,
in everyday Egyptian Arabic, for a modern software-company advertisement.
Confident, friendly, calm and conversational, with medium pace and clear phrase breaks.
Use Egyptian colloquial pronunciation throughout; no formal newsreader delivery,
no Modern Standard Arabic case endings, no Gulf or Levantine accent, no exaggerated acting.
Egyptian ج is a hard g. Read the provided words exactly; never translate, omit or add words.
Brand: لوك سيس = two clear words, look sees. سوليوشنز = solutions.
إس إم إس = three separately articulated English letter names, S M S.
خليك متصل = Egyptian khallik mottasel, warm natural closing.
Keep all consonants clear. Pause briefly at commas and longer between sentences.
Read موظفينك and عملاءك naturally in Egyptian Arabic, not as formal declamation.'''

def script_lines():
    tree = ast.parse((ROOT / 'generate_voice.py').read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'LINES' for t in node.targets):
            return ast.literal_eval(node.value)
    raise RuntimeError('Narration script not found')

def synthesize(text, destination, key):
    body = json.dumps({'model': 'gpt-4o-mini-tts', 'voice': 'cedar',
                       'input': text, 'instructions': INSTRUCTIONS,
                       'response_format': 'mp3', 'speed': 1.0}).encode('utf-8')
    request = urllib.request.Request('https://api.openai.com/v1/audio/speech', data=body,
                                    headers={'Authorization': 'Bearer ' + key,
                                             'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            audio = response.read()
    except urllib.error.HTTPError as error:
        try:
            error_code = json.loads(error.read()).get('error', {}).get('code')
        except (ValueError, AttributeError):
            error_code = None
        if error_code == 'insufficient_quota':
            raise SystemExit('TTS blocked: insufficient_quota. Add API credits or check the project spend limit.') from None
        if error_code == 'rate_limit_exceeded':
            raise SystemExit('TTS blocked: rate_limit_exceeded. Retry after the service cooldown.') from None
        raise SystemExit(f'TTS request failed (HTTP {error.code}). Check API access and billing.') from None
    except urllib.error.URLError:
        raise SystemExit('TTS network connection failed. Run with permitted network access.') from None
    if len(audio) < 1000:
        raise SystemExit('TTS returned an invalid audio file.')
    destination.write_bytes(audio)
    print('Saved:', destination)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--all', action='store_true', help='Generate all lines after audition review')
    parser.add_argument('--key-stdin', action='store_true', help='Read key from stdin without saving it')
    args = parser.parse_args()
    key = getpass.getpass('API credential (hidden): ').strip() if args.key_stdin else os.environ.get('OPENAI_API_KEY')
    if not key:
        raise SystemExit('Missing OPENAI_API_KEY. Set it locally; do not paste it into chat.')
    output = ROOT / 'voice_revision'
    output.mkdir(exist_ok=True)
    lines = script_lines()
    if args.all:
        for i, line in enumerate(lines, 1):
            synthesize(line, output / f'voice_{i}.mp3', key)
    else:
        synthesize('\n\n'.join([lines[0], lines[1], lines[-1]]), output / 'Egyptian_Male_Audition.mp3', key)

if __name__ == '__main__':
    main()
