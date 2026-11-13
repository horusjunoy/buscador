# Buscador e Gestor de Medicamentos

Aplicativo em português para organizar orientações informadas pelo responsável, registrar doses, controlar estoque por lote e planejar reposição. Flutter para Android/iOS/web, API FastAPI e PostgreSQL. Versão de desenvolvimento 0.1.0, com interface verde/turquesa e assets integrados.

## Executar com Docker

Requer Docker Compose e Python 3.12 para gerar a configuração local. A versão web compilada está em `dist/web`.

```sh
python scripts/configure_local.py
docker compose up --build -d
```

Acesse http://127.0.0.1:8765/app/ e crie sua conta. A API usa `/v1`, o contrato está em `/openapi.json` e a verificação em `/health`. O banco inicia vazio; as migrações são aplicadas por uma conta separada e a aplicação usa uma conta com permissões de dados. Credenciais são geradas localmente em `.env`. O volume `buscador_data` mantém o banco. `docker compose down` encerra os serviços sem apagar o volume.

O Compose destina-se a desenvolvimento local. A imagem completa da API Linux ainda não foi exercitada; os testes PostgreSQL foram executados com a API no host e o banco em container. Use dados sintéticos até concluir revisão de privacidade, segurança e operação. Publicação externa requer configuração própria de HTTPS e revisão das políticas do produto.

## Desenvolver e testar

```sh
python -m venv .venv
# Ative .venv conforme seu sistema operacional.
python -m pip install -r backend/requirements-dev.txt
python scripts/check.py
python scripts/serve.py --port 8765 --minutes 240
```

Esse caminho utiliza SQLite para desenvolvimento. Para PostgreSQL, configure `DATABASE_URL` e execute `python -m scripts.migrate` antes de iniciar com `AUTO_MIGRATE=0`. Os testes de integração aceitam `BUSCADOR_TEST_POSTGRES_URL` apontando para uma instância exclusiva em `127.0.0.1`, driver `postgresql+pg8000`, banco administrativo `buscador`; criam e removem bancos efêmeros próprios. Nunca use essa variável em um banco compartilhado.

Em `mobile/`, com Flutter 3.44.2/Dart 3.12.2:

```sh
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href /app/ --no-web-resources-cdn
flutter build apk --debug --target-platform android-arm64
```

Copie o conteúdo de `mobile/build/web/` para `dist/web/` após recompilar o cliente web. Android usa Gradle 8.14.3, AGP 8.13.1 e Kotlin 2.2.20; mínimo API 26. iOS requer macOS/Xcode. `--dart-define=API_URL=<URL>` configura o endereço da API nos clientes nativos. O debug Android permite HTTP local; release deve usar HTTPS.

## Funcionalidades e limites

- Conta, sessão revogável, perfis familiares e permissões por pessoa/ação.
- Apresentações cadastradas manualmente, lotes, validade e histórico imutável de movimentos.
- Orientações versionadas, calendário, confirmação explícita, adiamento, correção auditável e conciliação.
- Fila persistente e cache cifrado, sincronização idempotente e recuperação de resposta perdida.
- Projeção separada do saldo físico, alertas, lista de compras e recebimento confirmado.
- Exportação e solicitação de exclusão para análise. Exclusão efetiva e recuperação por canal externo continuam pendentes.

O aplicativo não diagnostica, prescreve, ajusta doses ou recomenda substituição/compensação. Não há catálogo comercial nem fontes de preços conectados; a busca de ofertas informa indisponibilidade. Estoque compartilhado, recorrências especiais, revisão jurídica/menores/retenção e piloto continuam pendentes. Nenhuma oferta simulada é apresentada como real.

## Validação

35 testes backend passaram em SQLite e na trilha PostgreSQL; 12 testes Flutter passaram, com análise sem issues e build web release. Foram exercitados concorrência entre titular/cuidador, última unidade de estoque, replay de migrações, restrição de DDL e restore PostgreSQL cifrado com DPAPI Windows. O APK ARM64 debug compilou e teve integridade/assinatura verificadas. iOS e aparelhos físicos ainda não foram testados. Build não comprova funcionamento de notificações, bateria, reinício, acessibilidade ou armazenamento nativo em hardware.

Documentação do produto em `docs/`, contrato efetivo em `openapi/implemented-openapi.json`, modelo em `backend/app/models.py`, migrações em `backend/app/database.py` e assets em `assets/production` e `mobile/assets`. Os documentos de requisitos descrevem também capacidades futuras; o contrato efetivo e os limites acima refletem a implementação atual. A fonte Roboto inclui licença Apache-2.0 em `mobile/assets/fonts/LICENSE.txt`.
