# Arquitetura implementada

Flutter → FastAPI → serviços transacionais → SQLAlchemy/PostgreSQL. O modo SQLite atende desenvolvimento e testes rápidos. Os clientes compartilham domínio, API e estado; Android/iOS fornecem proteção e lembretes por canais nativos.

Uma confirmação valida sessão, permissão, revisão e idempotência antes de criar evento, movimento alocável e auditoria na mesma transação. A resposta de sucesso só sai depois do commit. Saldo insuficiente preserva a declaração e solicita conciliação. Lote é escolhido explicitamente. Projeção não altera o ledger; correções usam eventos e movimentos compensatórios.

Valores usam Decimal e NUMERIC(14,3). A agenda mantém UTC e fuso IANA, IDs determinísticos por versão/instante, rejeita horário DST inexistente e usa a primeira ocorrência no horário ambíguo no default de desenvolvimento. Suporta horários explícitos e dias da semana; outras recorrências permanecem futuras.

Sessões opacas são revogáveis e expiram. Senhas usam scrypt. Autorizações são verificadas por família, pessoa e ação, inclusive antes de replay. Histórico e versões têm triggers de imutabilidade. Migração usa conta owner; API usa conta sem DDL.

O cliente mantém comandos de dose e chaves duráveis antes do envio, rejeita leituras atrasadas de outro perfil e apresenta rejeições para conferência. Web usa AES-GCM/WebCrypto/IndexedDB, Android usa Keystore e iOS usa Keychain/CryptoKit. Chave não exportável não protege contra comprometimento da mesma origem.

Lembretes discretos cobrem uma janela de até sete dias/60 avisos e não confirmam ingestão. Entrega depende do sistema operacional e exige testes físicos. Web não promete lembretes nativos. Código iOS ainda não foi compilado.

O contrato efetivo contém 39 caminhos em `openapi/implemented-openapi.json`. O YAML anterior é uma referência de requisitos. Integrações comerciais não estão habilitadas. Revisão jurídica, fontes reais, testes físicos e publicação externa exigem trabalho adicional.
