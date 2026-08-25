# ai-agent-harness

Agentes de IA (Codex, Claude Code, e outros) não têm memória entre sessões nem entre ferramentas diferentes — cada retomada de trabalho, cada troca de agente, perde o contexto do que já foi decidido e onde o trabalho parou. O ai-agent-harness resolve isso com um protocolo simples baseado em arquivos versionados no próprio repositório do projeto: memória compartilhada entre agentes, retomada segura após uma sessão morrer no meio, roteamento automático entre frentes de trabalho e handoffs — sem depender de memória proprietária de nenhuma ferramenta.

## Pré-requisitos

- `bash`, `jq`, `shasum` (ou `sha256sum`) — todos padrão ou fáceis de instalar em macOS/Linux (`brew install jq` se faltar).

## Como funciona: Codex + Claude Code compartilhando contexto

O protocolo vive num único arquivo, `AGENTS.md`, que o Codex CLI já lê nativamente como suas instruções. O Claude Code lê `CLAUDE.md`, então esse arquivo contém só `@AGENTS.md` (sintaxe de import do Claude Code) — os dois agentes acabam lendo exatamente o mesmo protocolo, sem duplicação. Qualquer outro agente que suporte um arquivo de instruções na raiz do projeto pode ser apontado para `AGENTS.md` da mesma forma.

## Conceitos principais

- **Frente**: um recorte de trabalho do projeto (uma feature, uma área, um módulo), cada uma com seu próprio `CONTEXTO.md` e handoff. `_ai/FRONTS.md` é o índice curto que mapeia um assunto a uma frente.
- **`_ai/NOW.md`**: o estado atual do projeto num relance — frente ativa, objetivo, próximo passo.
- **`_ai/WORKING.md`**: checkpoint vivo do trabalho em andamento. Existe para que, se uma sessão morrer no meio (limite de contexto, travamento, fechamento inesperado), o próximo agente recupere o último estado útil sem precisar de handoff formal. Tem três status — `EM ANDAMENTO`, `CONCLUÍDO`, `ABANDONADO` — que governam se há trabalho para retomar.
- **`_ai/handoffs/<frente>.md`**: registro curto e sempre atual do estado operacional de cada frente (o que foi feito, descobertas, pendências, próximo passo).

O protocolo completo dessas regras está em `core/AGENTS.md` — o arquivo instalado como `AGENTS.md` em cada projeto.

## Uso rápido

Instalar num projeto novo ou existente:

```bash
./install.sh /caminho/do/projeto --name "Nome do Projeto"
```

Sem flags, `install.sh` pergunta interativamente o que precisar. Use `--yes` para aceitar os defaults sem perguntar (nome = nome da pasta, agentes = `codex,claude-code`, frentes em `_ai/fronts/`, sem fonte de verdade interna).

Criar uma frente nova (dentro do projeto instalado):

```bash
./scripts/nova-frente.sh schema-dados "Schema e catálogo de produto."
```

Montar um pacote de contexto portátil de uma frente (dentro do projeto instalado):

```bash
./scripts/montar-contexto.sh schema-dados
```

Atualizar um projeto já instalado para a versão mais recente do harness:

```bash
./update.sh /caminho/do/projeto
```

Se algum arquivo harness-owned foi editado manualmente no projeto, `update.sh` preserva a edição e marca o update como parcial — use `--force` para sobrescrever de propósito.

## Estrutura deste repositório

```
ai-agent-harness/
├── core/                 # arquivos copiados 1:1 para projetos (harness-owned no destino)
│   ├── AGENTS.md          # protocolo universal
│   ├── CLAUDE.md          # "@AGENTS.md"
│   └── scripts/           # montar-contexto.sh, nova-frente.sh, iniciar-repo.sh, atualizar-fonte-verdade.sh
├── templates/             # consumidos uma vez; o resultado vira project-owned no destino
├── lib/common.sh          # funções compartilhadas por install.sh/update.sh (não copiado para projetos)
├── install.sh
└── update.sh
```

## Estrutura de um projeto instalado

```
<projeto>/
├── AGENTS.md                # harness-owned
├── CLAUDE.md                # harness-owned — "@AGENTS.md"
├── scripts/                  # harness-owned
│   ├── montar-contexto.sh
│   ├── nova-frente.sh
│   ├── iniciar-repo.sh
│   └── atualizar-fonte-verdade.sh
└── _ai/
    ├── harness.json           # harness-owned
    ├── templates/              # harness-owned (usados por nova-frente.sh)
    ├── project.json            # project-owned — configuração operacional
    ├── PROJECT.md               # project-owned — contexto e regras do projeto
    ├── NOW.md                    # project-owned
    ├── WORKING.md                 # project-owned
    ├── FRONTS.md                   # project-owned
    ├── handoffs/
    │   └── <frente>.md              # project-owned
    └── fronts/                       # default (--fronts-mode ai-fronts); pastas numeradas
        └── <frente>/                 # na raiz é o modo alternativo (--fronts-mode root-numbered)
            └── CONTEXTO.md            # project-owned
```

## Propriedade dos arquivos num projeto instalado

**harness-owned** (recriados/sobrescritos por `update.sh`; nunca edite à mão sem saber que uma próxima atualização pode sobrescrever): `AGENTS.md`, `CLAUDE.md`, `scripts/*.sh`, `_ai/templates/*.tpl`, `_ai/harness.json`.

**project-owned** (nunca tocados por `update.sh`, mesmo com `--force`): `_ai/PROJECT.md`, `_ai/project.json`, `_ai/FRONTS.md`, `_ai/NOW.md`, `_ai/WORKING.md`, `_ai/handoffs/*.md`, todo `CONTEXTO.md` de qualquer frente.

Se um arquivo harness-owned foi editado manualmente no projeto, `update.sh` detecta pelo checksum e não sobrescreve — marca como pendente em `_ai/harness.json` (`update_status: "partial"`) até rodar com `--force` ou até o conteúdo voltar a bater.

## Versionamento (v0.1.0)

Distribuição por cópia local: `VERSION` neste repositório é a fonte da verdade da versão do harness; cada projeto instalado guarda em `_ai/harness.json` a versão instalada, o caminho deste repositório-fonte e o checksum de cada arquivo harness-owned. Sem submodule, sem gerenciador de pacotes nesta versão.

## Estado atual e limitações conhecidas (v0.1.0)

- Distribuição por cópia local — atualizar um projeto exige apontar `update.sh` para um clone local deste repositório (sem submodule/pacote nesta versão).
- `jq` é dependência obrigatória de todos os scripts, exceto `iniciar-repo.sh`.
- Testado em macOS (bash 3.2 / zsh); não testado em Linux nem Windows/WSL.
- Sem suíte de testes automatizada nem CI configurado — a v0.1.0 foi validada por testes manuais ponta a ponta (instalação nos dois modos de frente, update parcial e forçado, migração de `AGENTS.md`/`CLAUDE.md` pré-existentes, instalação dentro de um projeto de código real).
- Sem licença definida ainda.
- `nova-frente.sh` faz checagem mecânica de colisão de nome; a decisão semântica de "esse assunto já pertence a uma frente existente com outro nome" continua sendo julgamento do agente, não do script.
