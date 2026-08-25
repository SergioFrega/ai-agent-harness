# Instruções Compartilhadas dos Agentes

Este arquivo é a fonte canônica de instruções compartilhadas entre Codex, Claude Code e qualquer outro agente que trabalhe neste repositório. É gerido pelo ai-agent-harness e é sobrescrito em atualizações do harness — não edite regras de projeto aqui; elas vivem em `_ai/PROJECT.md`.

## Fonte de verdade

- `AGENTS.md` (este arquivo) = protocolo universal. `CLAUDE.md` só importa este arquivo com `@AGENTS.md`.
- `_ai/PROJECT.md` = contexto e regras específicas deste projeto; tem precedência sobre este protocolo quando houver conflito explícito.
- `_ai/project.json` = configuração operacional (nome do projeto, onde ficam as frentes, fonte de verdade do projeto). É para os scripts lerem — não é preciso interpretá-lo manualmente; `_ai/PROJECT.md` já resume o que importa.
- Memórias privadas de qualquer agente não são memória compartilhada do projeto. Histórico profundo fica no Git; handoffs registram só o estado operacional mais recente. `_ai/WORKING.md` é checkpoint vivo, não fonte de verdade — hipóteses ali são provisórias. `_ai/FRONTS.md` é índice de roteamento, não substitui `CONTEXTO.md`/handoff da frente.

## Início de tarefa

1. Leia `_ai/PROJECT.md` (curto, específico do projeto) antes de decidir roteamento ou continuidade.
2. Identifique a intenção:
   - **Continuidade** ("continue", "onde paramos", sem assunto novo explícito): leia primeiro `_ai/NOW.md` e `_ai/WORKING.md`. Se `WORKING.md` estiver `EM ANDAMENTO`, considere-o na retomada, mas confira o timestamp contra `NOW.md` e o handoff da frente para descartar estado obsoleto.
   - **Assunto novo** (usuário nomeia tema/feature/problema, sem pedir continuidade): consulte `_ai/FRONTS.md` primeiro para achar a frente certa.
   - **Sinal misto** (ex.: "continue no GA4"): se `WORKING.md` (`EM ANDAMENTO`) já cobrir esse assunto, trate como continuidade; senão, trate como assunto novo e roteie via `FRONTS.md`.
3. Depois de identificar a frente, leia o `CONTEXTO.md` e o handoff dela. Não leia `CONTEXTO.md`/handoff de outras frentes sem necessidade.
4. Busque documentos adicionais só conforme a tarefa exigir.

## Roteamento e criação de frentes

`_ai/FRONTS.md` é um índice curto — uma linha por frente, só o suficiente para mapear um assunto a uma frente.

- Encaixe claro → roteie sozinho, sem perguntar.
- Assunto toca mais de uma frente → escolha a principal, consulte a secundária só se necessário.
- Ambiguidade real → uma pergunta curta antes de agir.
- Antes de tratar como frente nova, confirme que não é uma frente existente com outro nome. Não crie duplicata.
- Se nenhuma frente existente couber, aponte isso ao usuário como possível frente nova — não crie sozinho.
- Crie frente nova só sob pedido explícito, usando `scripts/nova-frente.sh <slug> "<descrição>"`. Ele cria a estrutura mínima (`CONTEXTO.md`, handoff, entrada em `FRONTS.md`) com segurança.

## Fim de tarefa

Após trabalho substancial:

- Atualize o handoff da frente relevante: o que foi feito, descobertas, arquivos alterados, pendências, próximo passo recomendado. Não copie histórico antigo (ele já está no Git).
- Atualize `_ai/NOW.md` só se a frente ativa, objetivo atual ou próximo passo mudaram.
- Marque `_ai/WORKING.md` como `CONCLUÍDO` só quando o objetivo da tarefa estiver de fato encerrado (ver regra de status abaixo); ao fazer isso, consolide o necessário no handoff da frente e atualize `_ai/NOW.md` se necessário. Não é preciso apagar o arquivo — ele pode permanecer com `Status: CONCLUÍDO` até ser sobrescrito pelo próximo checkpoint de trabalho.

## Uso de contexto

Não carregue o repositório inteiro automaticamente. Prefira o contexto específico da frente. Atualize só os arquivos diretamente relacionados à tarefa pedida. Não corrija, reorganize ou atualize contexto existente sem pedido explícito.

## Handoffs (`_ai/handoffs/<frente>.md`)

Cada handoff é curto e contém só: Última atualização, Último agente, Objetivo, O que foi feito, Descobertas, Pendências, Próximo passo. Reflete apenas o estado operacional mais recente da frente.

## Trabalho em andamento (`_ai/WORKING.md`)

Checkpoint vivo — existe para que, se a sessão morrer no meio (limite de contexto, travamento, fechamento inesperado, erro de ferramenta), o próximo agente recupere o último estado útil, mesmo sem handoff formal.

- Ao iniciar trabalho substancial, atualize antes de começar.
- Durante o trabalho, atualize após eventos significativos: descoberta que muda direção, decisão relevante, resultado importante de teste, ou antes de operação longa/complexa/arriscada. Não faça checkpoint por tempo fixo, só por evento.
- Cada checkpoint sobrescreve o anterior — reflete o presente, não um log. Registre só o necessário para outro agente retomar; não transcreva conversa nem raciocínio passo a passo.

### Regra de status (crítica para a resiliência)

Fim de uma etapa, resposta ou investigação **não é** o mesmo que fim do trabalho.

- `EM ANDAMENTO`: há continuidade prevista — próximo passo definido, implementação pendente, espera por decisão/autorização do usuário, possibilidade de outro agente assumir, ou objetivo maior ainda não alcançado.
- `CONCLUÍDO`: objetivo da tarefa efetivamente encerrado, sem próxima ação da mesma tarefa, resultado já consolidado no handoff — e não é apenas aguardar aprovação para continuar.
- `ABANDONADO`: trabalho explicitamente interrompido, não deve ser retomado.

Campos: Status, Último checkpoint (timestamp local ISO), Agente, Frente, Objetivo, Estado atual, Hipóteses/decisões provisórias relevantes, Último resultado relevante, Próxima ação, Arquivos em trabalho.

## Git

Não faça commit ou push sem pedido explícito. Verifique o estado do Git antes de editar quando for relevante. Não reverta alterações existentes que não tenham sido feitas pelo agente atual.
