# MedPlanner

Aplicativo Flutter para planejamento financeiro de profissionais PJ. Os dados ficam em SQLite no aparelho para o app funcionar offline e são sincronizados com a conta Supabase quando existe conexão.

## Visão geral

O MedPlanner foi criado para ajudar no controle de finanças pessoais com foco em:

- planejamento mensal
- acompanhamento de receitas e despesas
- organização de cartões e parcelas
- controle de metas e categorias
- exportação de dados em planilha ou backup

## Funcionalidades

### Dashboard e planejamento
- Painel mensal com entradas líquidas projetadas, despesas e cartões
- Seletor mensal em carrossel com meses anteriores e seguintes
- Planejamento por categoria com subtotal, percentual do mês, vencimento e marcação de pagamento
- Repetição de despesas por uma quantidade definida de meses (até 120 ocorrências, incluindo a primeira)
- Notificações às 9h no dia anterior e no dia do vencimento para despesas não pagas

### Receitas e recebimentos
- Organização de recebimentos em abas como Trabalhados e Recebidos
- Cadastro reutilizável de serviços
- Edição de dados como data, quantidade de plantões (incluindo frações como 0,5), imposto estimado e mês previsto de recebimento

### Investimentos e cartões
- Regras de investimento percentuais ou fixas
- Gestão de cartões com limite, categorias e compras parceladas agrupadas por cartão
- Consulta das parcelas ao abrir cada cartão e edição de uma parcela ou da compra inteira
- Cálculo de parcelas em aberto e liberação de limite após pagamento

### Metas e categorias
- Metas agrupadas por categoria com descrição, quantidade, subtotal e edição
- Categorias separadas por área: Planejamento, Cartões e Metas
- Criação rápida de novas categorias diretamente no seletor de cada módulo

### Exportação e backup
- Exportação em Excel
- Backup e restauração em JSON
- Sincronização offline-first do snapshot JSON privado por usuário no Supabase
- Operação offline: alterações ficam locais e entram na sincronização quando houver conexão

## Tecnologias

- Flutter
- Riverpod e Command pattern
- SQLite
- Supabase Auth e sincronização JSON
- Notificações locais
- Excel
- Share Plus
- Circle Nav Bar

## Estrutura do projeto

```text
.
├── android/          # Configuração do projeto Android
├── ios/              # Configuração do projeto iOS
├── assets/           # Arquivos estáticos e ícones
├── lib/              # Código principal da aplicação
│   ├── core/         # Banco, temas e utilitários
│   ├── features/     # Módulos da aplicação
│   └── main.dart     # Ponto de entrada
├── test/             # Testes
├── README.md         # Documentação do projeto
├── analysis_options.yaml
├── pubspec.yaml      # Dependências e configuração do Flutter
└── pubspec.lock      # Lockfile das dependências
```

## Como rodar

### Pré-requisitos
- Flutter SDK instalado
- Android Studio ou VS Code com emulador/configuração Android
- Dispositivo Android conectado com depuração USB ou emulador em execução

### Instalação e execução

1. Abra a pasta do projeto no VS Code ou Android Studio.
2. Instale as dependências:

```powershell
flutter pub get
```

3. Execute a aplicação:

```powershell
flutter run
```

### Se você usa o Puro

```powershell
puro --env=stable flutter pub get
puro --env=stable flutter run
```

## Dados e privacidade

- As telas financeiras leem e gravam primeiro no SQLite local
- Cada registro local mantém um `sync_id` estável, `updated_at`, `is_synced` e `deleted_at`; exclusões são lógicas para poderem ser propagadas a outros aparelhos
- Com uma sessão Supabase, o app verifica a conectividade, envia alterações pendentes e consulta o `updated_at` remoto ao entrar, voltar ao primeiro plano, recuperar a conexão, receber alterações em tempo real ou usar **Sincronizar agora**
- O app baixa o snapshot JSON somente quando a nuvem mudou desde `last_sync_at` (ou quando a sincronização é forçada), aplica a reconciliação em transação e só confirma o estado após a operação remota concluir
- `finance_backups` continua sendo um snapshot JSON compartilhado com o site: a verificação de novidade é incremental, mas o payload ainda é transferido por inteiro, não como delta de linhas
- O site independente `medplanner-web` lê e grava o mesmo snapshot para apresentar Início, Entradas e Cálculos
- Se dois aparelhos offline editarem o mesmo registro, o sincronizador mantém a alteração local da cópia que sincroniza; registros distintos são combinados por ID
- O site deve preservar `sync_id`/`card_sync_id` ao salvar e ignorar registros com `deleted_at` preenchido para refletir exclusões lógicas
- Não há integração bancária
- O primeiro envio associa os dados locais atuais à conta que estiver autenticada
- Após uma sincronização, o aparelho fica vinculado àquela conta; a tela financeira é bloqueada se outra conta entrar no mesmo aparelho, para impedir que os dados locais sejam misturados entre usuários
- Os lembretes de vencimento são notificações locais; o sistema pode solicitar permissão para exibi-las
- Backup JSON e exportação em planilha são feitos via compartilhamento do sistema
- A tabela `finance_backups` precisa existir no projeto Supabase para sincronizar

> Atenção: o protótipo ainda não cifra o arquivo SQLite. Para uso com dados financeiros sensíveis em produção, a próxima etapa sugerida é adicionar criptografia do banco e proteção por biometria/PIN.

## Status

Projeto em desenvolvimento, com foco em planejamento financeiro pessoal e uso local/offline.

## Próximos passos sugeridos

- criptografia do banco SQLite
- autenticação por biometria ou PIN
- refinamento da experiência de uso e UX
- mais relatórios e filtros financeiros
- melhorias de exportação e importação
