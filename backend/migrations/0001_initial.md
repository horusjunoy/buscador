# 0001 — Fundação e eventos imutáveis

Implementação executável: `backend/app/database.py:migrate` e `backend/app/models.py`.
Aplicação: `python -m scripts.migrate`. Revisão registrada em `schema_revisions`.
UUIDs, FKs, unicidade de ocorrência/versão/idempotência/evento/reversão; NUMERIC(14,3); índices por pessoa/data e lote; triggers de UPDATE/DELETE negados em movimentos, eventos, versões e auditoria.

Rollback destrutivo somente em banco efêmero de teste: recriar o banco de teste. Não há downgrade destrutivo automático em dados persistentes. Para evolução, acrescentar `0002` sem editar a revisão já aplicada.
