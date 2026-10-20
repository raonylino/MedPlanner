# Supabase no MedPlanner

A pasta `supabase/` fica na raiz deste repositório. Na integração GitHub do Supabase, use `.` como **Working directory**.

A migração `migrations/20261020170000_initial_finance_schema.sql` cria o esquema PostgreSQL correspondente às tabelas locais, protege as linhas por `user_id` com RLS e prepara os valores padrão ao cadastrar uma conta Supabase Auth.

## Atenção antes do primeiro deploy

Esta é uma migração inicial para um banco Supabase vazio. Ela cria tabelas que já existem no SQLite do aplicativo. Se o projeto Supabase de destino já tiver tabelas com esses nomes, não aplique essa migração diretamente: primeiro gere uma migração de baseline a partir do esquema remoto.

A integração GitHub executa migrações novas quando elas chegam à branch de produção configurada. Confira o projeto Supabase de destino e revise a migração antes de habilitar **Deploy to production**.

A migração cria o banco no Supabase; ela não conecta o app Flutter à API nem envia os dados SQLite já existentes. Isso requer uma etapa posterior de autenticação, repositórios remotos e sincronização.
