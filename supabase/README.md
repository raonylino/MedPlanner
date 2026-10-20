# Supabase no MedPlanner

A pasta `supabase/` fica na raiz deste repositório. Na integração GitHub do Supabase, use `.` como **Working directory**.

A integração GitHub está conectada ao projeto Supabase `MedPlanner`, sincronizando a branch `main`.

A migração `migrations/20261020170000_initial_finance_schema.sql` cria o esquema PostgreSQL correspondente às tabelas locais, protege as linhas por `user_id` com RLS e prepara os valores padrão ao cadastrar uma conta Supabase Auth.

A migração `migrations/20261020193000_add_private_finance_json_backups.sql` cria `finance_backups`, uma cópia JSON privada por usuário. O app autentica por e-mail e senha; em Configurações, a pessoa escolhe quando enviar ou restaurar essa cópia. O envio substitui a cópia anterior da mesma conta e mantém o SQLite local.

## Atenção antes do primeiro deploy

Esta é uma migração inicial para um banco Supabase vazio. Ela cria tabelas que já existem no SQLite do aplicativo. Se o projeto Supabase de destino já tiver tabelas com esses nomes, não aplique essa migração diretamente: primeiro gere uma migração de baseline a partir do esquema remoto.

A integração GitHub executa migrações novas quando elas chegam à branch de produção configurada. Confira o projeto Supabase de destino e revise a migração antes de habilitar **Deploy to production**.

O upload da cópia JSON não sincroniza cada alteração automaticamente e não importa os registros para as tabelas normalizadas. Para enviar a base local existente, abra o app no aparelho que contém esses dados, entre/crie uma conta e toque em **Enviar dados locais para a nuvem**.
