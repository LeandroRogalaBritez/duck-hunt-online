# Implementação de Alerta: Terra

Data: 07/10/2026. Base: protótipo aprovado pelo criador. Esta entrega implementa gameplay, identidade, arte e áudio para testes, mantendo solo, ENet e WebRTC.

## Divisão pelas skills do pacote

| Responsabilidade | Skills aplicadas | Resultado |
| --- | --- | --- |
| Roteamento e arquitetura | studio-router, studio-godot-technical-director | Cena principal própria, atores e apresentação separados; estado da partida no host |
| Gameplay e feeling | studio-gameplay-lead, gamedev-game-feel, godot-input-handling, godot-gdscript-mastery, game-design | Pulso anunciado, cargas limitadas, dash com buffer, captura/recolhimento, ondas e relatório |
| Arte e animação | godot-2d-animation | Sprites e animações PixelLab, grade consistente, nearest e feedback visual |
| Interface | studio-ui-ux-game-lead, godot-ui-containers, godot-ui-theming | Lobby próprio, HUD por papel, opções de som/movimento e apresentação de resultados |
| Áudio | gamedev-audio-design, godot-audio-systems | 12 SFX e ambiente ElevenLabs, buses SFX/Ambience/UI, seis vozes e limiter no Master |
| Rede | godot-multiplayer-networking | Ações validadas no host, snapshots a 20 Hz, canais separados, rate limit e validação de rodada/ownership |
| QA | studio-qa-playtest-lead, godot-testing-patterns | Testes determinísticos, quatro processos em LAN/WebRTC, áudio decodificado, renderização e pacote Windows |

As skills orientaram essas partes; não foram criados agentes ou chats separados.

## Comportamento entregue

- Solo como Agente ou ET contra IA, cinco ondas; multiplayer até quatro participantes, no máximo dois ETs humanos, melhor de cinco.
- Dois ETs por onda, três cargas por agente, pulso de 150 ms, intervalo de 600 ms, 14 s de defesa e 1,2 s de desembarque.
- Impulso de 200 ms a 2×, cooldown de 2 s, buffer de 120 ms, sem invulnerabilidade.
- 500 pontos por captura, 250 por onda perfeita; pontos permanecem mesmo em derrota parcial.
- Sem espera sem finalidade: a última carga resolvida adianta o desembarque se ainda houver invasores.
- ET contido é recolhido por bolha; uma onda perfeita mostra os agentes levantando o ET com “Tá aqui a prova!”.
- Recursos são validados no host: clientes não concedem pontos, capturas, posições arbitrárias ou disparos fora do seu papel.
- Movimento humano tem previsão local e correção por snapshots. Esta entrega não implementa rollback ou compensação avançada de latência.
- Um ET desconectado passa à IA; perda do anfitrião retorna ao lobby.
- No multiplayer, opções não pausam a simulação; apenas o anfitrião reinicia a sessão.

## Arte e limpeza

Foram produzidos nove jobs no PixelLab: base do ET, cenário, dupla apresentando um ET, nave, animação do ET, animação da apresentação, dupla em falha, ícone e bolha. As duas animações têm cinco imagens, incluindo a pose inicial.

Assets ficam em `assets/alien/art/`; o manifesto contém IDs, origem e termos do serviço. Nenhum asset anterior foi fornecido como referência de geração.

A limpeza retirou 90 arquivos de sprites/áudios antigos e sidecars de importação. Uma exclusão recursiva ampla foi rejeitada pela revisão automática por incluir código e testes. A alternativa adotada preservou esses caminhos: cenas antigas viraram entradas de compatibilidade para componentes novos, e somente a mídia legada foi apagada. Pastas de compatibilidade e backups não entram na build.

O histórico Git não foi reescrito. Caso o histórico antigo já seja público, sua limpeza exige uma decisão separada por alterar commits compartilhados.

## Áudio e condição de publicação

Todos os 13 arquivos finais foram gerados pela API do ElevenLabs usando a chave existente no ambiente. O criador escolheu explicitamente áudio gratuito provisório apenas para testes, para refazer antes de publicar. Isso está marcado em cada entrada de `assets/alien/audio/manifest.json`.

A decodificação foi verificada no mixer do Godot. Carga vazia, UI e ambiente foram refeitos após medição revelar gravações quase inaudíveis. A gravação final do ambiente tem cerca de -17,3 dB RMS antes do ganho do jogo; o player aplica -18 dB. Efeitos e UI possuem controle separado do ambiente, e um hard limiter limita o Master a -1 dB.

O áudio não determina cooldown ou avanço da rodada. Os sons de recolhimento são ligados a um sinal cosmético emitido uma única vez pelo ator; as regras de captura já foram resolvidas antes desse sinal.

Para publicar comercialmente: ativar uma assinatura adequada, refazer todos os sons com `tools/generate_invasion_audio.ps1 -Force`, conferir os registros e só então usar `tools/export_game.ps1 -Commercial`. O helper não altera a licença de um arquivo antigo só porque a assinatura mudou. [Condições do ElevenLabs](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform).

A arte segue os [termos do PixelLab](https://www.pixellab.ai/termsofservice), sujeitos a direitos de terceiros. O nome de trabalho ainda requer pesquisa de disponibilidade; este documento não é certificação jurídica.

## Evidências de validação

| Verificação | Resultado |
| --- | --- |
| `tests/test_invasion.tscn` | PASS: entrada, cooldown, limite de cargas, um alvo por pulso, esquiva do ponto anunciado, pontuação única, desembarque, relatório, dash e IA |
| ENet com 3 e 4 processos | PASS: handshake, movimento humano, disparo remoto, resultados iguais, reinício, ações inválidas/atrasadas, saída de ET e retorno após perda do host |
| WebRTC com 4 processos e sinalização local | PASS para os mesmos casos, incluindo malha completa |
| WebRTC com 3 processos e servidor público configurado | PASS para os mesmos casos, em sala temporária exclusiva |
| Decodificação dos 13 áudios | PASS: duração, frames PCM, pico e RMS registrados em `tests/evidence/audio_metrics.json` |
| Renderização Compatibility | Introdução, gameplay, ET, celebração e lobby inspecionados |
| Executável Windows | Exportado para `build/testes/AlertaTerra.exe`; smoke headless com saída 0 |
| Inspeção do PCK | Recursos necessários presentes; sem caminhos de mídia legada |

Os participantes desses testes de rede rodaram neste computador. A sinalização pública também foi exercitada, mas isso não substitui um playtest entre redes distintas, com latência e NAT reais. Sem TURN próprio, algumas redes podem impedir a conexão direta.

Durante a validação, o WebRTC apresentou falta do canal confiável adicional; a malha passou a criar o canal 1 para eventos. A primeira configuração de exportação por seleção de cenas deixou assets importados de fora; o preset foi corrigido para incluir os recursos atuais e excluir mídia/código legado, documentos, testes, fonte antiga e temporários. A build reconstruída carregou corretamente.

## Próximo playtest

Abrir a build, testar captura perfeita, derrota parcial e os dois papéis. Fazer uma sessão entre dois computadores e depois entre redes diferentes. Ajustar atraso, velocidade e orçamento em função da leitura e justiça percebidas; a identidade visual e as regras principais já estão implementadas.
