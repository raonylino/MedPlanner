# MedPlanner

Aplicativo Flutter para planejamento financeiro pessoal, com armazenamento local em SQLite e funcionamento totalmente offline.

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
- Operação local, sem integração bancária ou dependência de internet

## Tecnologias

- Flutter
- SQLite
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

- O aplicativo não faz chamadas de rede
- Não há integração bancária
- Os dados ficam armazenados localmente em SQLite no dispositivo
- Os lembretes de vencimento são notificações locais; o sistema pode solicitar permissão para exibi-las
- Backup JSON e exportação em planilha são feitos via compartilhamento do sistema
- A restauração substitui os dados locais atuais

> Atenção: o protótipo ainda não cifra o arquivo SQLite. Para uso com dados financeiros sensíveis em produção, a próxima etapa sugerida é adicionar criptografia do banco e proteção por biometria/PIN.

## Status

Projeto em desenvolvimento, com foco em planejamento financeiro pessoal e uso local/offline.

## Próximos passos sugeridos

- criptografia do banco SQLite
- autenticação por biometria ou PIN
- refinamento da experiência de uso e UX
- mais relatórios e filtros financeiros
- melhorias de exportação e importação
