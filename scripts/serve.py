"""Bounded local server supervisor. Loopback only; no publication or paid service."""
import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import UTC, datetime, timedelta
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port',type=int,default=8765)
    parser.add_argument('--minutes',type=int,default=240)
    args=parser.parse_args()
    if not 1<=args.minutes<=480 or not 1024<=args.port<=65535:raise ValueError('Invalid bounded runtime')
    try:
        urllib.request.urlopen(f'http://127.0.0.1:{args.port}/health',timeout=2)
    except (urllib.error.URLError,TimeoutError):pass
    else:raise SystemExit('Port already serves HTTP. Validate the existing process before starting another.')
    directory=ROOT/'runs/local';directory.mkdir(parents=True,exist_ok=True)
    child=subprocess.Popen([sys.executable,'-m','uvicorn','backend.app.main:app','--host','127.0.0.1','--port',str(args.port),'--no-access-log'],cwd=ROOT)
    now=datetime.now(UTC)
    receipt={'pid':child.pid,'started_at':now.isoformat(),'deadline':(now+timedelta(minutes=args.minutes)).isoformat(),'url':f'http://127.0.0.1:{args.port}/app/','scope':'local-synthetic-loopback','working_directory':str(ROOT)}
    (directory/'server.json').write_text(json.dumps(receipt,indent=2))
    try:code=child.wait(timeout=args.minutes*60)
    except subprocess.TimeoutExpired:
        child.terminate()
        try:child.wait(timeout=10)
        except subprocess.TimeoutExpired:child.kill()
        code=124
    receipt['exit_code']=code;receipt['ended_at']=datetime.now(UTC).isoformat()
    (directory/'server.json').write_text(json.dumps(receipt,indent=2))
    raise SystemExit(code)
