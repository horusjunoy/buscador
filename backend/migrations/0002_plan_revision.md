# 0002 — Revisão de estado e versão ativa

`treatment_plans.active_revision` identifica a versão imutável da orientação. `revision` é o controle otimista do agregado e também avança em suspensão/conclusão. Retomar exige uma versão explicitamente revisada. A migração preserva `active_revision=revision` nas linhas anteriores, sem editar versões ou eventos.

Implementação: `backend/app/database.py:migrate`. Aplicação idempotente e registro em `schema_revisions`. Sem downgrade destrutivo de dados clínicos.
