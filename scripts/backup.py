"""Consistent SQLite DEV backup, protected with Windows user-bound DPAPI.

This is not the PostgreSQL production backup procedure. No plaintext staging file.
"""
import argparse
import ctypes
import json
import os
import sqlite3
from pathlib import Path

MAGIC=b'BUSCADOR_DPAPI_V1\0'

class Blob(ctypes.Structure):
    _fields_=[('size',ctypes.c_ulong),('data',ctypes.POINTER(ctypes.c_ubyte))]

def protect(data: bytes, decrypt=False):
    if os.name!='nt': raise RuntimeError('Este procedimento DEV requer DPAPI do Windows. Não foi definido backup portátil neste ciclo.')
    source_buffer=ctypes.create_string_buffer(data)
    entropy_buffer=ctypes.create_string_buffer(b'br.com.buscador.backup.v1')
    source=Blob(len(data),ctypes.cast(source_buffer,ctypes.POINTER(ctypes.c_ubyte)))
    entropy=Blob(len(entropy_buffer)-1,ctypes.cast(entropy_buffer,ctypes.POINTER(ctypes.c_ubyte)))
    output=Blob()
    crypt=ctypes.windll.crypt32
    function=crypt.CryptUnprotectData if decrypt else crypt.CryptProtectData
    result=function(ctypes.byref(source),None,ctypes.byref(entropy),None,None,1,ctypes.byref(output))
    if not result: raise RuntimeError('Não foi possível proteger/restaurar o backup para este usuário Windows.')
    try:return ctypes.string_at(output.data,output.size)
    finally:ctypes.windll.kernel32.LocalFree(output.data)

def inspect_snapshot(db):
    if db.execute('PRAGMA integrity_check').fetchone()[0]!='ok': raise ValueError('Falha de integridade SQLite')
    if db.execute('PRAGMA foreign_key_check').fetchone(): raise ValueError('Referências inválidas no snapshot')
    if db.execute('SELECT lot_id FROM inventory_movements GROUP BY lot_id HAVING ROUND(SUM(delta),3)<0').fetchone():
        raise ValueError('Saldo negativo no livro-razão')
    tables=('accounts','persons','medications','stock_lots','inventory_movements','dose_events')
    return {'integrity':'ok','counts':{table:db.execute(f'SELECT count(*) FROM {table}').fetchone()[0] for table in tables},'schema_revisions':[r[0] for r in db.execute('SELECT revision FROM schema_revisions ORDER BY revision')]}

def backup(source: Path, output: Path):
    if output.exists():raise FileExistsError('O destino já existe; não será sobrescrito.')
    with sqlite3.connect(source.resolve().as_uri()+'?mode=ro',uri=True) as origin,sqlite3.connect(':memory:') as memory:
        origin.backup(memory)
        report=inspect_snapshot(memory)
        encrypted=MAGIC+protect(memory.serialize())
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open('xb') as target:target.write(encrypted)
    return {**report,'format':'DPAPI-user-bound','environment':'local-synthetic'}

def restore(source: Path, output: Path):
    if output.exists():raise FileExistsError('O destino já existe; restauração só é permitida em novo arquivo.')
    encrypted=source.read_bytes()
    if not encrypted.startswith(MAGIC):raise ValueError('Formato de backup inválido')
    plain=protect(encrypted[len(MAGIC):],decrypt=True)
    with sqlite3.connect(':memory:') as memory:
        memory.deserialize(plain)
        report=inspect_snapshot(memory)
        output.parent.mkdir(parents=True,exist_ok=True)
        # Reserve the destination exclusively before SQLite opens it.
        with output.open('xb'):pass
        with sqlite3.connect(output) as destination:memory.backup(destination)
    return {**report,'restored':True,'environment':'local-synthetic'}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['create','restore'])
    parser.add_argument('--source',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    print(json.dumps((backup if args.action=='create' else restore)(args.source,args.output),indent=2))
