# Alerta: Terra

Arcade de defesa terrestre em Godot 4.7.2, baseado no protótipo aprovado de invasão alienígena.

Dois ETs chegam por onda. Agentes usam três pulsos de contenção por jogador; os invasores tentam esquivar e desembarcar na cidade. Quando todos são capturados, dois agentes apresentam um ET como prova da invasão.

## Jogar

Abra `build/testes/AlertaTerra.exe` mantendo o PCK e a pasta de bibliotecas ao lado. No projeto Godot, use F5; a entrada é `scenes/lobby/lobby.tscn`.

- **Solo:** selecione Agente ou ET e clique em Jogar Sozinho. As vagas restantes usam IA.
- **Local:** até quatro jogadores na mesma rede, via ENet. O anfitrião é Agente; até duas pessoas podem ser ETs.
- **Online:** código de sala via WebRTC e servidor de sinalização. O anfitrião é Agente; a sala é fechada para novas entradas ao começar.

| Papel/ação | Controle |
| --- | --- |
| Agente: mirar/disparar | Mouse / clique esquerdo |
| ET: mover | WASD ou setas |
| ET: impulso | Espaço; cooldown de 2 s |
| Reiniciar | R; somente anfitrião no multiplayer |
| Trocar papel no solo | Tab |
| Pausa/opções | Esc; no multiplayer a partida continua |
| Hitboxes de diagnóstico | H |

O pulso marca o ponto por 150 ms antes de resolver. Cada clique gasta uma carga; segurar não dispara continuamente. Captura vale 500 pontos e uma onda inteiramente contida acrescenta 250. Se todos os agentes esgotam as cargas, o desembarque é antecipado após resolver o último pulso.

Solo tem cinco ondas; multiplayer é melhor de cinco, encerrando quando um time chega a três vitórias. O movimento do ET é validado e simulado pelo host. Clientes enviam ações; captura, cargas e pontuação são decisões do host.

## Arte e áudio

A pixel art original foi produzida no **PixelLab**, incluindo ET, nave, cidade noturna, agentes, bolha de contenção, ícone e animações de flutuação/apresentação. O áudio inclui **12 SFX e um ambiente de 20 segundos em loop, gerados com ElevenLabs (elevenlabs.io)**.

**Esta versão usa áudio do plano gratuito do ElevenLabs, autorizado pelo criador apenas para testes. Não publicar comercialmente estes sons. Eles precisam ser gerados novamente durante uma assinatura com licença comercial.** O script de exportação bloqueia o modo comercial enquanto o manifesto marcar sons de desenvolvimento. [Condições de publicação do ElevenLabs](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform).

A arte usa os [termos do PixelLab](https://www.pixellab.ai/termsofservice); origem, IDs e datas estão em `assets/alien/art/manifest.json`. Os prompts e a licença de cada áudio estão em `assets/alien/audio/manifest.json`.

Sprites e sons antigos foram retirados da árvore de assets. Caminhos de cenas anteriores permanecem como compatibilidade, sem imagens anteriores, e são excluídos da build. O histórico Git não foi reescrito. O nome Alerta: Terra segue sendo um nome de trabalho, sujeito a pesquisa de disponibilidade antes do lançamento.

## Verificação e build

Executar da pasta do projeto:

```powershell
& 'E:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . 'res://tests/test_invasion.tscn'
& '.\tests\run_network_tests.ps1' -Transport lan -Players 4
& '.\tools\export_game.ps1'
```

Os testes de WebRTC podem usar a sinalização pública padrão ou a fixture local `tests/signaling_fixture.cjs`, configurando `ALERTA_TERRA_SIGNALING_URL`. O servidor público pode hibernar e certas redes/NATs podem impedir uma conexão direta; esta versão mantém STUN e não possui serviço TURN próprio.

Para refazer áudio após ativar um plano adequado, use `tools/generate_invasion_audio.ps1 -Force` com `ELEVENLABS_API_KEY` no ambiente. A chave não é armazenada no projeto. Sem `-Force`, arquivos existentes conservam seu registro de licença original.

Os recursos antigos, testes, documentos, fonte antiga e arquivos temporários são excluídos do pacote. A build é inspecionada por `tools/inspect_export.gd`.

## Organização

- `scenes/invasion/`: regras, atores, HUD, mundo e áudio.
- `scenes/lobby/`: entrada para os modos solo/local/online.
- `scenes/network/`: WebRTC/sinalização.
- `scenes/gamemanager.gd`: sessão, roster e transições.
- `assets/alien/`: arte, animações, áudio e manifestos.
- `tests/`: verificações de mecânica, áudio e rede.
- `docs/implementacao_invasao.md`: decisões e evidências desta entrega.

Godot Engine e addons mantêm suas licenças próprias; notices do addon WebRTC acompanham o pacote. O código do projeto ainda não recebeu uma licença pública de distribuição.
