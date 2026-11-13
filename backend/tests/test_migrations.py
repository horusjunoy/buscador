from sqlalchemy import inspect, text
from backend.app.database import make_engine, migrate


def test_replaying_migrations_preserves_immutable_triggers(app):
    migrate(app.state.engine);migrate(app.state.engine)
    with app.state.engine.connect() as connection:
        assert set(connection.execute(text('SELECT revision FROM schema_revisions')).scalars())=={'0001','0002'}
        if app.state.engine.dialect.name=='postgresql':
            names=connection.execute(text("SELECT tgname FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE 'immutable_%' ORDER BY tgname")).scalars().all()
            assert names==['immutable_audit_events','immutable_dose_events','immutable_inventory_movements','immutable_plan_versions']
        else:
            assert len(connection.execute(text("SELECT name FROM sqlite_master WHERE type='trigger'")).all())==8

def test_migration_replay_and_legacy_plan_upgrade(tmp_path):
    engine=make_engine(f'sqlite:///{tmp_path}/migration.db')
    migrate(engine);migrate(engine)
    assert 'active_revision' in {c['name'] for c in inspect(engine).get_columns('treatment_plans')}
    with engine.connect() as connection:
        assert set(connection.execute(text('SELECT revision FROM schema_revisions')).scalars())=={'0001','0002'}
        triggers=connection.execute(text("SELECT name FROM sqlite_master WHERE type='trigger'")).scalars().all()
        assert len(triggers)==8
    engine.dispose()
