# Duck Hunt Online

Recriação do clássico **Duck Hunt**, desenvolvida em **Godot Engine 4.7**, com um twist: o modo online é **assimétrico** — um jogador entra na pele do caçador (mira e atira) enquanto outro(s) jogam como os próprios patos, tentando fugir dos tiros.

## 🎮 Sobre o jogo

Duck Hunt Online reimagina o clássico de NES como uma disputa **jogador contra jogador**, e não apenas jogador contra IA:

- **Alvo (Hunter)** — o papel clássico: mira com o mouse/toque e atira nos patos antes que fujam. Tem munição limitada por rodada (3 tiros por espingarda, multiplicados pela quantidade de caçadores na sala).
- **Pato (Duck)** — controla um dos patos em campo, tentando escapar dos tiros dos "Alvos" em vez de ser controlado pela IA do jogo original.

Cada rodada tem 4 patos no total — os que não forem controlados por jogadores humanos são preenchidos por IA. A cada 2 rodadas vencidas pelos caçadores, a velocidade dos patos aumenta, elevando a dificuldade.

## 🌐 Como funciona o online

O multiplayer usa a **API de alto nível de multiplayer do Godot**, com `ENetMultiplayerPeer` como transporte:

1. **Hospedar partida** — no lobby, um jogador informa IP e porta e cria o servidor (`GameManager.create_server`). Esse jogador vira automaticamente o *host* (autoridade da partida).
2. **Entrar na partida** — os demais jogadores digitam o IP/porta do host e escolhem entrar como **Alvo** ou **Pato** (`GameManager.join_server`).
3. **Limite de patos jogáveis** — no máximo **2 jogadores humanos** podem ser patos ao mesmo tempo. Se a sala já estiver cheia de patos, o próximo jogador que tentar entrar como pato é automaticamente realocado para o papel de Alvo (com aviso na tela).
4. **Sincronização de estado** — a lista de jogadores conectados (nome + papel) é replicada para todos via **RPC** (`@rpc`), atualizando a lista em tempo real no lobby.
5. **Autoridade do servidor** — toda a lógica de rodada (spawn de patos, contagem de tiros, pontuação, avanço de round, aumento de dificuldade) roda no host e é replicada para os clientes por RPCs (`any_peer`, `call_local`, `reliable`), mantendo a partida sincronizada.
6. **Desconexão** — se um jogador cai da partida, o servidor detecta o evento (`peer_disconnected`), remove o jogador da lista e notifica os demais clientes.

Ou seja, não é matchmaking automático (sem servidor de lobby central) — é **host direto por IP/porta**, no estilo LAN/peer-to-peer clássico de jogos Godot com ENet.

## 🕹️ Controles

| Ação | Entrada |
|---|---|
| Atirar (papel Alvo) | Clique do mouse / toque na tela |

## 🛠️ Tecnologias

- **Engine:** Godot 4.7
- **Multiplayer:** High-Level Multiplayer API do Godot (`ENetMultiplayerPeer`) + RPCs
- **Renderer:** GL Compatibility (mobile + desktop)
- **Resolução base:** 770x720 (stretch mode `canvas_items`)
- Suporte a **emulação de toque via mouse**, permitindo jogar em dispositivos móveis

## 📁 Estrutura do projeto

```
duck-hunt-online/
├── assets/          # Sprites, sons e demais recursos
├── scenes/
│   ├── lobby/        # Cena de lobby (entrada para partidas online)
│   └── gamemanager.gd # Autoload que gerencia o estado do jogo
├── build 1.0/        # Build/exportação já gerada
├── icon.svg
└── project.godot     # Configuração do projeto Godot
```

O autoload `GameManager` é responsável por gerenciar o estado global da partida, e a cena inicial do jogo é o **lobby** (`scenes/lobby/lobby.tscn`), usado para reunir/organizar jogadores antes das partidas online.

## 🚀 Como rodar

1. Instale o [Godot Engine 4.7+](https://godotengine.org/download).
2. Clone este repositório:
   ```bash
   git clone https://github.com/LeandroRogalaBritez/duck-hunt-online.git
   ```
3. Abra a pasta do projeto pelo Project Manager do Godot.
4. Pressione `F5` (ou o botão de Play) para executar — o jogo inicia direto na tela de lobby.

## 📌 Status

Projeto com build 1.0 já disponível no repositório; sistema de lobby e mecânica de tiro implementados.

## 📄 Licença

Ainda não definida.
