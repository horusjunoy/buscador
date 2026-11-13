import os
import sqlite3
import pytest
from backend.app.database import make_engine,migrate
from scripts.backup import backup,restore

@pytest.mark.skipif(os.name!='nt',reason='DEV backup explicitly uses Windows user-bound DPAPI')
def test_encrypted_backup_restore_integrity_and_no_overwrite(tmp_path):
    source=tmp_path/'source.db';engine=make_engine(f'sqlite:///{source}');migrate(engine);engine.dispose()
    with sqlite3.connect(source) as db:
        db.execute("INSERT INTO accounts(id,email,password_hash,created_at) VALUES ('synthetic','qa@synthetic.invalid','test-hash','2026-11-12T00:00:00')")
    encrypted=tmp_path/'backup.dpapi';restored=tmp_path/'restored.db'
    before=backup(source,encrypted)
    assert b'qa@synthetic.invalid' not in encrypted.read_bytes()
    after=restore(encrypted,restored)
    assert before['counts']==after['counts'] and after['integrity']=='ok'
    with sqlite3.connect(restored) as db:assert db.execute('SELECT email FROM accounts').fetchone()[0]=='qa@synthetic.invalid'
    with pytest.raises(FileExistsError):restore(encrypted,restored)
    damaged=tmp_path/'damaged.dpapi';data=bytearray(encrypted.read_bytes());data[-1]^=1;damaged.write_bytes(data)
    with pytest.raises(RuntimeError):restore(damaged,tmp_path/'rejected.db')
