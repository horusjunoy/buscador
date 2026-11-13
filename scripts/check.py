"""Run backend checks and optional Flutter checks."""
import argparse,os,subprocess,sys
from pathlib import Path

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--mobile',action='store_true');args=parser.parse_args()
    root=Path(__file__).resolve().parents[1]
    subprocess.run([sys.executable,'-m','pytest','backend/tests','-q'],cwd=root,check=True)
    if args.mobile:
        flutter='flutter.bat' if os.name=='nt' else 'flutter'
        for command in ([flutter,'analyze','--no-pub'],[flutter,'test','--no-pub']):subprocess.run(command,cwd=root/'mobile',check=True)
