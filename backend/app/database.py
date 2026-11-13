import os
from sqlalchemy import create_engine, event, text, inspect
from sqlalchemy.orm import sessionmaker
from .models import Base

DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///./runs/local/buscador.db')

def make_engine(url):
    engine = create_engine(url, pool_pre_ping=True, **({'connect_args': {'check_same_thread': False, 'timeout': 30}} if url.startswith('sqlite') else {}))
    if engine.dialect.name == 'sqlite':
        @event.listens_for(engine, 'connect')
        def sqlite_constraints(connection, _):
            connection.execute('PRAGMA foreign_keys=ON')
    return engine

def migrate(engine):
    """Version 0001. DDL only here, never inside an HTTP handler.

    Ledger/event updates and deletes are rejected by database triggers as well as API design.
    """
    Base.metadata.create_all(engine)
    with engine.begin() as connection:
        connection.execute(text('CREATE TABLE IF NOT EXISTS schema_revisions (revision VARCHAR(20) PRIMARY KEY)'))
        revision = connection.execute(text("SELECT revision FROM schema_revisions WHERE revision='0001'")).first()
        for table in (() if revision else ('inventory_movements', 'dose_events', 'audit_events', 'plan_versions')):
            if engine.dialect.name == 'postgresql':
                connection.execute(text("CREATE OR REPLACE FUNCTION reject_immutable_change() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'immutable ledger'; END; $$"))
                connection.execute(text(f'CREATE TRIGGER immutable_{table} BEFORE UPDATE OR DELETE ON {table} FOR EACH ROW EXECUTE FUNCTION reject_immutable_change()'))
            else:
                for op in ('UPDATE', 'DELETE'):
                    connection.execute(text(f"CREATE TRIGGER IF NOT EXISTS immutable_{table}_{op.lower()} BEFORE {op} ON {table} BEGIN SELECT RAISE(ABORT, 'immutable ledger'); END"))
        if not revision:
            connection.execute(text("INSERT INTO schema_revisions(revision) VALUES ('0001')"))
        if not connection.execute(text("SELECT revision FROM schema_revisions WHERE revision='0002'")).first():
            columns={item['name'] for item in inspect(connection).get_columns('treatment_plans')}
            if 'active_revision' not in columns:
                connection.execute(text('ALTER TABLE treatment_plans ADD COLUMN active_revision INTEGER NOT NULL DEFAULT 1'))
                connection.execute(text('UPDATE treatment_plans SET active_revision=revision'))
            connection.execute(text("INSERT INTO schema_revisions(revision) VALUES ('0002')"))

def factory(engine):
    return sessionmaker(engine, expire_on_commit=False, autoflush=True)
