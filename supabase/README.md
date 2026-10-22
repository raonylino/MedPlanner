# Supabase no MedPlanner

A pasta `supabase/` fica na raiz deste repositório. Na integração GitHub do Supabase, use `.` como **Working directory**.

A integração GitHub está conectada ao projeto Supabase `MedPlanner`, sincronizando a branch `main`.

A migração `migrations/20261020170000_initial_finance_schema.sql` cria o esquema PostgreSQL correspondente às tabelas locais, protege as linhas por `user_id` com RLS e prepara os valores padrão ao cadastrar uma conta Supabase Auth.

A migração `migrations/20261020193000_add_private_finance_json_backups.sql` cria `finance_backups`, uma cópia JSON privada por usuário. O app autentica por e-mail e senha, mantém SQLite como armazenamento local e sincroniza automaticamente essa cópia quando há conexão. Configurações também permite forçar o envio ou restaurar os dados manualmente.

## Atenção antes do primeiro deploy

Esta é uma migração inicial para um banco Supabase vazio. Ela cria tabelas que já existem no SQLite do aplicativo. Se o projeto Supabase de destino já tiver tabelas com esses nomes, não aplique essa migração diretamente: primeiro gere uma migração de baseline a partir do esquema remoto.

A integração GitHub executa migrações novas quando elas chegam à branch de produção configurada. Confira o projeto Supabase de destino e revise a migração antes de habilitar **Deploy to production**.

O sincronizador automático usa o JSON privado `finance_backups`; não grava as alterações nas tabelas normalizadas. O site web MedPlanner usa o mesmo snapshot para ler e gravar entradas. Cada registro enviado pelo app inclui `sync_id`, `updated_at`, `is_synced` e `deleted_at`; o app consulta `finance_backups.updated_at` antes de baixar o JSON e salva localmente o marco `last_sync_at`. Como o backend compartilhado continua sendo um snapshot, quando há mudanças o JSON completo é baixado/enviado; não há delta real por tabela.

A migração `20261020210000_enable_finance_backup_realtime.sql` habilita eventos Realtime para atualizar o app quando o site ou outro aparelho altera o snapshot. Se duas cópias offline alterarem o mesmo registro, a alteração local prevalece. O site precisa preservar `sync_id`/`card_sync_id` ao regravar registros e ignorar registros cujo `deleted_at` esteja preenchido. O SQLite local continua disponível offline; ao abrir o app, entrar na conta, retomar o app, recuperar conexão, receber um evento Realtime ou alterar dados online, a sincronização tenta reconciliar o snapshot.
