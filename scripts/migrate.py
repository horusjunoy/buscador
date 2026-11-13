import os
from pathlib import Path
from backend.app.database import DATABASE_URL, make_engine, migrate
from sqlalchemy import text

if __name__ == '__main__':
    if DATABASE_URL.startswith('sqlite:///'):
        Path(DATABASE_URL.removeprefix('sqlite:///')).parent.mkdir(parents=True,exist_ok=True)
    engine=make_engine(DATABASE_URL)
    migrate(engine)
    if engine.dialect.name=='postgresql' and os.getenv('GRANT_APP_ROLE')=='buscador_app':
        with engine.begin() as connection:
            connection.execute(text('GRANT USAGE ON SCHEMA public TO buscador_app'))
            connection.execute(text('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO buscador_app'))
    print('Schema revisions 0001/0002 applied; no credentials printed.')
