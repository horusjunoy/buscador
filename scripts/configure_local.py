"""Generate private local configuration without overwriting an existing file."""
import os,secrets
from pathlib import Path

if __name__=='__main__':
    target=Path(__file__).resolve().parents[1]/'.env'
    owner,app=secrets.token_hex(24),secrets.token_hex(24)
    content=f"POSTGRES_OWNER_PASSWORD={owner}\nAPP_DB_PASSWORD={app}\nOWNER_DATABASE_URL=postgresql+pg8000://buscador_owner:{owner}@db:5432/buscador\nAPP_DATABASE_URL=postgresql+pg8000://buscador_app:{app}@db:5432/buscador\nAPP_PORT=8765\n"
    with target.open('x',encoding='utf-8',newline='\n') as output:output.write(content)
    if os.name!='nt':target.chmod(0o600)
    print('Local .env created. Credentials were not printed; keep this file private.')
