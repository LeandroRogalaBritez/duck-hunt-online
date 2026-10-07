# Plano de redesign: Alerta: Terra

Data: 07/10/2026  
Status: especificação inicial; implementação entregue. Ver `docs/implementacao_invasao.md` para comportamento final, testes e condição do áudio.  
Nome de trabalho: **Alerta: Terra**. A disponibilidade comercial do nome ainda precisa ser pesquisada.  
Ferramentas de produção: **PixelLab** para pixel art e **ElevenLabs** para SFX.

## 1. Objetivo e decisões centrais

Transformar o projeto atual em um arcade sobre uma **invasão alienígena à Terra**, com identidade própria. Naves inimigas lançam ETs sobre uma cidade terrestre; os agentes humanos defendem a cidade antes que os invasores desembarquem. Preservar a diversão de mirar, acertar e escapar, especialmente o multiplayer assimétrico já existente. A mudança abrange personagens, cenário, animações, interface, áudio, linguagem, regras de resultado e apresentação comercial.

Direção solicitada pelo criador:

- Os patos passam a ser alienígenas.
- O campo de jogo passa a destacar o céu.
- A temática central é uma invasão da Terra, conforme a orientação adicional do criador. Os ETs são invasores e os agentes são a defesa terrestre.
- O cachorro desaparece completamente.
- Ao capturar todos os ETs, homens de uniforme preto aparecem e levantam um ET para mostrar o resultado.
- Sprites serão refeitos no PixelLab; efeitos sonoros serão produzidos no ElevenLabs.

Interpretação de design: a Terra está sob invasão e uma equipe humana intercepta as tropas aéreas antes do desembarque. O disparo é um pulso de contenção que interrompe o propulsor do ET e o recolhe vivo. A comédia vem da burocracia exagerada dos agentes e da personalidade irritada dos invasores, mantendo a urgência de proteger a cidade.

A celebração conserva a função de mostrar uma captura, mas ganha composição, movimento, personagens e humor próprios. Não reproduzir a sequência do cachorro surgindo do gramado com uma simples troca de sprite.

Este plano reduz dependência de elementos de terceiros; não certifica ausência de infração. A avaliação para publicação depende dos assets finais, das licenças, do nome e dos territórios de distribuição.

## 2. O que existe no projeto

Levantamento feito a partir de scripts, cenas, configuração e recursos locais. Não inclui um playtest da versão atual.

| Área | Evidência atual | Consequência para a mudança |
| --- | --- | --- |
| Engine e tela | `project.godot`: Godot 4.7, Compatibility, 770 × 720, filtro nearest | Manter inicialmente a resolução; refazer a composição dentro dela |
| Entrada | `scenes/lobby/lobby.tscn` mostra DUCK HUNT | Substituir título, tema, instruções e papéis |
| Modos | `gamemanager.gd` e `lobby.gd`: sozinho, LAN/ENet e online/WebRTC | Preservar os três caminhos e atualizar o README, que descreve apenas ENet |
| Participantes | Até quatro pessoas, até duas controlando patos; host entra como atirador | Traduzir papéis para Agente e ET, mantendo o host como Agente nesta primeira entrega |
| Alvos por ciclo | `main.gd` gera `_quantidade_maxima_pato = 2`, mas `_patos_por_round = 4` alimenta o HUD | Usar dois ETs por onda e fazer HUD, contagem e documentação concordarem |
| Munição | Três disparos por atirador | Reaproveitar como três cargas de pulso, sujeito a playtest |
| Movimento | `pato.gd`: IA com mudanças de direção; jogador com setas e dash em `ui_accept` | Reinterpretar como flutuação e impulso do propulsor |
| Fuga | Timer de 15 s; saída por cima; mira ignora entradas com `pode_fugir` | Tornar a desembarque legível e resolver explicitamente quando termina a vulnerabilidade |
| Acerto | Animação de susto, queda e contagem ao atingir área inferior | Substituir por pane do propulsor, bolha de contenção e recolhimento |
| Resultado | `cao.gd` participa tanto da abertura quanto do fim da rodada | Remover essa dependência e criar apresentação específica da onda |
| Dificuldade | Multiplicador de velocidade cresce em 1 a cada duas vitórias, passando de 1 para 2 | Substituir saltos grandes por progressão pequena e com teto |
| Pontuação | Capturas pontuam; rodada incompleta desconta essas capturas | Manter pontos por captura; distinguir vitória da rodada e pontuação acumulada |
| Áudio e tiro | `alvo.gd` aguarda o áudio de recarga terminar para liberar o tiro seguinte | Separar cooldown de gameplay da duração do SFX novo |
| Arte | Atlas identificado como Duck Hunt fornece inclusive peças do HUD | Refazer HUD e ícones, além dos personagens e do fundo |
| Exportação | `export_presets.cfg`: `all_resources`, sem exclusões, nome antigo no executável | Assets antigos soltos também precisam sair do pacote final |

Arquivos de arte nominalmente ligados ao original incluem `assets/Duck_Hunt_Remade_transparent_without_clouds.png`, `assets/PikPng.com_duck-hunt-png_1397308.png` e `assets/NES - Duck Hunt - The Dog.png`. Os demais recursos também precisam ter procedência verificada. Nome de arquivo sozinho não comprova licença nem ausência dela.

## 3. Visão, pilares e loop

**Visão:** um arcade de reflexo e blefe durante uma invasão da Terra, em que agentes humanos tentam conter ETs lançados por naves inimigas antes que desembarquem na cidade, enquanto outros jogadores podem controlar os invasores.

**Mecânica de identidade:** antecipar uma trajetória e usar um pulso anunciado; do outro lado, gastar o impulso no momento certo para escapar.

**Tensão central:** disparar cedo para garantir a oportunidade ou esperar uma trajetória melhor, arriscando uma esquiva e o desembarque inimigo.

| Pilar | Experiência desejada | Limite de escopo |
| --- | --- | --- |
| Reflexo legível | Entender por que acertou, errou ou escapou | Sem fundo ruidoso, flashes globais ou hitboxes invisivelmente enormes |
| Duelo assimétrico | Agentes antecipam; ETs enganam a mira | Sem armas extras, inventário ou árvore de habilidades no primeiro redesign |
| Defesa da Terra com humor | Agentes sérios tentando conter uma invasão absurda | Sem imitar atores, figurinos icônicos ou piadas de uma franquia |
| Partidas curtas | Uma tentativa ensina algo e outra começa rapidamente | Sem cenas longas entre todas as rodadas ou progressão obrigatória |

Aplicação da lente MDA da skill game-design:

- Experiência: tensão curta, satisfação de precisão e humor na resolução.
- Dinâmica: prever mudanças de trajetória, provocar disparos e guardar o impulso para uma ameaça real.
- Mecânicas: cargas limitadas, aviso de pulso, dash com recarga, prazo de desembarque e resultado de onda.

Loop do Agente: observar → posicionar mira → anunciar/disparar pulso → ver acerto ou esquiva → administrar cargas → resolver onda.

Loop do ET: sair da nave → mover → perceber aviso do pulso → escolher entre movimento normal e impulso → sobreviver até abrir o corredor → desembarcar na cidade.

Loop de sessão: alerta de invasão → onda de ETs → resultado e piada → próxima onda → relatório de defesa da cidade → jogar novamente.

As naves lançam tropas pelo alto e o avanço dos ETs em direção à cidade estabelece o perigo. As naves são apresentação nesta entrega, sem chefes, destruição de edifícios ou um segundo sistema de combate.

Rejogabilidade vem de trajetórias, adversários humanos e domínio dos controles. Sem economia, XP ou vantagens permanentes no MVP.

Padrões aplicados: anunciar honestamente as ameaças; aprofundar um verbo principal; alternar tensão e descanso; manter transições recorrentes curtas. Evitar uma estratégia dominante de spam de tiro ou dash contínuo.

## 4. Personagens e mundo próprios

### 4.1 ET principal: Zizi, nome provisório

Pequeno invasor flutuante com corpo de gota assimétrica, três olhos de tamanhos diferentes, antenas curtas curvas e um propulsor circular preso ao quadril. Corpo lavanda, face clara, pequeno peitoral com emblema original da força invasora e energia ciano. Sem asas, bico ou animação de bater asas. A silhueta deve comunicar alienígena e deslocamento aéreo imediatamente.

Após o pulso, o propulsor solta uma fumaça curta e Zizi entra numa bolha de contenção. A captura não apresenta cadáver ou queda de ave: um feixe leva a bolha até a plataforma de recolhimento. Na celebração, o ET está vivo, cruzando os braços ou reclamando com os olhos.

No multiplayer, os ETs compartilham tamanho, velocidade e hitbox. Diferenciar jogadores com emblemas e detalhes visuais de mesmo contraste; nunca dar uma skin mais difícil de enxergar. Um marcador discreto identifica o ET controlado pelo jogador.

### 4.2 Equipe de agentes

Dois agentes humanos da defesa terrestre com uniformes pretos de trabalho, botas largas, luvas, faixas diagonais discretas e distintivos geométricos próprios. Um é alto e magro; outro é baixo e largo. Faces visíveis, penteados e proporções originais. O equipamento parece um aparelho de contenção industrial portátil.

Atender à ideia de homens de preto sem adotar o nome, logo, personagens ou combinação visual reconhecível da franquia **Men in Black**. Evitar terno social, gravata estreita e óculos escuros como conjunto central; evitar dispositivo que imite seu apagador de memória e vozes/rostos de atores.

A equipe pode ser chamada internamente de **Defesa Terrestre**. A identificação é provisória e não representa vínculo com organização real ou franquia.

### 4.3 Cenário

Posto de defesa improvisado num terraço de uma cidade da Terra durante uma invasão noturna. O céu ocupa a maior parte da área de ação: gradiente índigo, estrelas espaçadas, nuvens finas e duas ou três naves inimigas distantes. Uma nave maior, de casco assimétrico original, anuncia a origem das ondas. As naves ficam escuras e não disputam contraste com os ETs.

Prédios, antenas, janelas e luzes de emergência identificam a cidade na borda inferior. Aviso inicial: **“Invasão detectada. Proteja a cidade.”** ETs chegam por feixes no alto; corredores luminosos de desembarque abrem junto aos telhados ao fim da janela de defesa. Não retratar turismo extraterrestre ou uma paisagem de outro planeta.

Uma plataforma de contenção e uma porta lateral justificam a entrada dos agentes no resultado. Sem árvore, gramado, lago ou disposição visual copiada do cenário anterior. O primeiro release terá um cenário bem acabado; variações de clima ficam para depois.

## 5. Gameplay proposto

Os valores abaixo são hipóteses iniciais de tuning. Validar com partidas solo e entre pessoas antes de congelá-los.

### 5.1 Estrutura de uma onda

1. Briefing de aproximadamente 0,8 s: número da onda e aviso de tropas inimigas.
2. Dois ETs entram pelo alto, lançados por uma nave. O host preenche vagas sem jogadores com IA.
3. Janela de defesa de 14 s, com contador visível. Agentes tentam capturar; ETs manobram enquanto a nave prepara o corredor de desembarque.
4. Ao expirar essa janela, o corredor próximo aos telhados abre por cerca de 1,2 s. ETs ainda ativos descem para ele e continuam vulneráveis durante esse trecho.
5. Capturado ou infiltrado, cada ET sai da disputa uma única vez. Resolver assim que todos tiverem destino.
6. Resultado curto e próxima onda. O host conclui o desembarque ao fim do prazo mesmo se um ET não alcançar a posição visual, evitando rodada travada. A descida deve ser animada para normalmente terminar antes desse limite.

Máquina de estados proposta: `briefing → defesa → desembarque → resultado → proxima_onda/relatorio`. Capturar os dois antecipadamente permite ir direto ao resultado. A direção do objetivo muda: invasores chegam do céu e tentam entrar na Terra, em vez de fugir pelo topo.

### 5.2 Pulso de contenção

- Mouse move a mira; clique inicia um disparo. Cada clique gera no máximo um pulso; segurar o botão não esgota automaticamente as cargas.
- Três cargas por Agente a cada onda, sem recarga manual nesta versão.
- Preparação de aproximadamente 0,15 s. O ponto escolhido fica marcado e travado durante esse aviso, permitindo ao ET sair da área anunciada. O pulso resolve naquela posição, não na posição posterior da mira.
- Intervalo mínimo inicial de 0,6 s entre inícios de disparo, contado por timer de gameplay. SFX não controla a regra.
- Acerto neutraliza um ET com um pulso e dispara contenção/recolhimento.
- Se dois ETs estiverem sobrepostos, um pulso captura no máximo um: escolher o centro mais próximo do ponto de impacto; em empate, usar ID estável.
- O aviso visual aparece também para os ETs. Não depender somente do som para permitir esquiva.
- Pulso já iniciado continua até a resolução, mesmo se for a última carga. Proibir novos disparos fora dos estados permitidos.

O aviso e a captura por bolha mudam o ritmo e o significado da ação. Não são exigências jurídicas para usar uma mecânica de mira; são decisões para dar personalidade e fortalecer o duelo.

### 5.3 Movimento e impulso dos ETs

- Movimento em oito direções com setas, mantendo a entrada existente. Criar ação dedicada para impulso e comunicar a tecla Espaço na interface após vinculá-la.
- Base inicial: 300 unidades/s na resolução atual; impulso com cerca de 0,2 s a duas vezes a velocidade; cooldown inicial de 2 s.
- Impulso oferece reposicionamento, sem invulnerabilidade. Durante o desembarque, a nave conduz os ETs pelo corredor e o impulso deixa de estar disponível; comunicar esse estado ao jogador.
- Animação de preparo/recarregamento do propulsor informa a disponibilidade. HUD do ET mostra a mesma informação.
- IA usa trajetórias com curvas e uma pequena antecipação antes de mudar fortemente de direção. Ela não lê inputs ocultos do Agente nem reage instantaneamente ao aviso do pulso.
- Sem mudanças de tamanho ou teleporte invisível na primeira versão.

### 5.4 Resultado, pontos e sessão

| Resultado da onda | Agentes | ETs | Apresentação |
| --- | --- | --- | --- |
| Todos capturados | Vitória | Derrota | Dois agentes levantam um ET e mostram a prova |
| Pelo menos um infiltrado na cidade | Derrota | Vitória | ET desembarca e planta sinalizador; agentes reconhecem a quebra da defesa |

- Cada captura concede 500 pontos ao time de agentes, mantidos mesmo quando outro ET desembarca.
- Onda perfeita concede bônus inicial de 250 pontos ao time de agentes.
- HUD distingue pontuação de capturas e placar de ondas. Evitar anunciar vitória a um ET capturado só porque a animação é cômica.
- Solo: sessão de cinco ondas, pontuação final e botão de nova tentativa; ondas perdidas não impedem chegar ao relatório. Conter pelo menos três significa **“Cidade protegida”**; menos de três, **“Cabeça de ponte inimiga estabelecida”**. Usar o placar da sessão, sem uma barra adicional de vida da cidade.
- Multiplayer: primeiro time a três vitórias, no máximo cinco ondas. Mostrar placar dos dois lados. ETs de IA entram como membros do time invasor.
- Na primeira entrega, o host continua Agente. Troca de papéis entre partidas é uma melhoria posterior, não automática no meio de uma onda.
- O solo começa sempre com dois ETs de IA. Salvar recordes entre sessões é posterior; o relatório inicial não exige sistema de persistência.

### 5.5 Balanceamento e ensino

Solo: primeira onda ensina mira/pulso, segunda introduz curva mais forte e terceira mostra impulso anunciado da IA. As duas últimas combinam comportamentos; sugerir passos de velocidade de aproximadamente 8%, com teto inicial de 1,35×. Não aumentar simultaneamente velocidade, quantidade e complexidade. A aproximação das naves e os alertas comunicam a escalada da invasão sem adicionar novas regras.

Multiplayer: atributos simétricos entre ETs, sem acelerar um jogador apenas porque o time adversário venceu. Testar separadamente 1 Agente/1 ET humano, 1/2, 2/1 e sala com três Agentes/um ET humano; completar sempre o total de dois ETs com IA quando necessário. A distribuição 2 Agentes/2 ETs humanos é a referência de duelo, mas as demais composições precisam continuar jogáveis.

Começar com três cargas por Agente. Se a soma de cargas em salas com mais Agentes eliminar a tensão, testar um orçamento total por equipe ou presets de composição, sem aplicar uma correção invisível durante a partida.

Riscos de design: aviso de pulso longo demais torna todo tiro fácil de esquivar; curto demais remove a leitura. Não ajustar só pelo resultado do time: observar também precisão, uso de impulso e percepção de justiça sob latência.

## 6. Cena de fim da onda

### Captura completa

A equipe apresenta o ET como prova da invasão e comemora ter impedido o desembarque daquela onda.

Storyboard de aproximadamente 2,2 s:

| Tempo | Ação |
| --- | --- |
| 0,00 a 0,40 s | Porta lateral abre; dois agentes entram na plataforma |
| 0,40 a 0,90 s | Um agente segura a bolha; o outro retira e ergue o ET com cuidado, apoiado sob os braços |
| 0,90 a 1,70 s | ET cruza os braços; legenda: **“Tá aqui a prova!”**; carimbo **CONTIDO** |
| 1,70 a 2,20 s | Agentes conduzem o ET para a porta; carimbo **ONDA CONTIDA** abre caminho à próxima onda |

Quando houver dois capturados, a segunda bolha fica na plataforma com indicador de quantidade. A cena não sugere que um único ET equivale à contagem total.

A fala funciona como texto desde o MVP. Dublagem é opcional, feita com voz original e ferramenta de voz apropriada; o gerador de SFX não deve ser usado para prometer uma fala inteligível. Outras legendas possíveis: “Invasor confirmado.” e “A cidade fica com a gente.”

### Desembarque inimigo

Um ET chega ao telhado distante e planta um sinalizador que aponta para a nave. Os agentes olham o ponto de desembarque e mostram **“Eles passaram pela defesa!”** Carimbo **INFILTRAÇÃO DETECTADA**. Não usar risada equivalente à do cachorro. Se houve captura parcial, mostrar as bolhas dos capturados e a quantidade de invasores que conseguiram pousar.

O resultado narrativo é compartilhado pela sala. Título local depende do papel: “Onda contida” para os Agentes vencedores e “Equipe capturada” para os ETs perdedores; no desembarque, “Infiltração concluída” para ETs e “Defesa rompida” para Agentes.

Modo de animação reduzida usa um quadro de resultado com legenda, sem movimento brusco. Online, qualquer duração alternativa deve ser uma configuração comum da sala ou uma redução apenas visual; não deixar cada cliente avançar o estado por conta própria.

## 7. Direção visual e interface

### Paleta e escala

Paleta inicial: fundo `#11162B`, céu `#283460`, nuvens `#505F89`, energia `#67E6E0`, ET `#B79AE8`, destaque quente `#FFB866`, texto `#F3F0E8` e uniforme `#202633`. Validar contraste com os sprites finais; estes valores são direção de arte, não medição de acessibilidade.

Pixel art com contorno de um pixel na escala de desenho, luz superior esquerda, três a quatro tons por material e silhuetas expressivas. Evitar ruído, excesso de dithering e mistura de assets com densidades de pixels diferentes.

Usar grade visual de referência **385 × 360**, apresentada a **2×** na tela atual de 770 × 720. Desenhar sprites nessa grade e preservar escala inteira/nearest. ET de 48 × 56 pixels ocupa aproximadamente 96 × 112 na tela, próximo das dimensões atuais de 96 × 111. O fundo pode precisar de acabamento/corte após geração para obter a dimensão exata; não pressupor que todo endpoint aceita 385 × 360.

Hitbox será ajustada ao núcleo visível de cada pose, inicialmente uma forma simples equivalente a aproximadamente 28 × 32 pixels de desenho. O círculo atual tem raio próximo de 53 unidades na tela: não copiá-lo cegamente para a nova silhueta. Testar sem contorno de debug depois de comparar hitbox e animação com debug ligado.

### Composição da tela

- Céu e área ativa: aproximadamente 75 a 80% superiores, preservando separação entre fundo e alvos.
- Terraço/plataforma: faixa inferior do mundo, sem ocultar hitboxes de ETs ativos.
- Barra de operação: faixa inferior com cargas/impulso, tempo, dois indicadores de ETs e placar.
- Indicadores de captura: símbolos de bolha; de infiltração: sinalizador plantado; de pendência: contorno. Forma e texto acompanham cor.
- Mira: anel quebrado em três segmentos, com pequeno marcador central. Aviso do pulso tem forma distinta da mira móvel.
- HUD do Agente: cargas pessoais; HUD do ET: impulso, tempo até desembarque e cargas restantes do time adversário.

Redesenhar a distribuição do HUD, fontes e painéis, em vez de conservar o atlas, molduras e coordenadas de recorte do original. Escolher fonte legível com licença documentada; a fonte existente deve ser auditada, não presumida irregular.

### Textos e fluxos

| Atual | Proposto |
| --- | --- |
| DUCK HUNT / Duck hunt | Alerta: Terra, provisório |
| ALVO | AGENTE |
| PATO | ET |
| SCORE | PONTOS |
| Round | ONDA |
| Tiros/balas | CARGAS |
| Aperte para começar | DEFENDER A TERRA |

Lobby: nome do jogador, escolha de papel com descrição de uma frase, modos Solo/Local/Online, sala e lista de participantes. Mensagem de realocação: “As duas vagas de ET estão ocupadas. Você entrou como Agente.” Mostrar explicitamente que o anfitrião é Agente.

Primeiro briefing do Agente: “A Terra está sob invasão! Mire e clique para conter os dois ETs antes do desembarque.” Dica seguinte: “O pulso marca o ponto antes de disparar.” Primeiro briefing do ET: “Use as setas para mover e Espaço para impulso. Desvie até abrir o corredor de desembarque.” Confirmar bindings finais antes de gravar essas instruções.

Configurações mínimas da entrega: volume de efeitos e ambiente separados, redução de movimento e ausência de flashes globais. Informação crítica deve continuar compreensível com som desligado. Controles touch para ET ainda precisam ser desenhados se a publicação incluir mobile; emulação de toque existente não substitui essa interface. Windows é o alvo inicial evidenciado pelo preset atual.

## 8. Plano de assets no PixelLab

Produzir assets originais a partir do briefing. Não fornecer atlas de Duck Hunt ou imagens de personagens de franquias como referência de geração. Usar uma pequena prancha original aprovada como referência de estilo para manter consistência nas próximas gerações.

Dimensões abaixo são na escala de desenho; apresentação prevista a 2×. Contagem de quadros é orçamento inicial, ajustável conforme a animação obtida.

| Prioridade | ID de produção | Dimensão/quadros | Entrega e função |
| --- | --- | --- | --- |
| P0 | `et_base` | 48 × 56 | Pose de referência e silhueta aprovada |
| P0 | `et_hover`, `et_move` | 4 + 4 quadros | Flutuação e deslocamento, uma direção com flip quando coerente |
| P0 | `et_dash`, `et_contained`, `et_land` | 4 + 4 + 4 quadros | Impulso, entrada na bolha e desembarque na cidade |
| P0 | `agent_tall`, `agent_short` | 48 × 72 por agente | Poses originais para entrada e celebração |
| P0 | `agents_present_et` | Canvas 144 × 96; 10 a 14 quadros | Sequência conjunta de entrada, levantar, apresentar e sair |
| P0 | `agents_failed` | Canvas 144 × 96; 4 a 6 quadros | Reação com recipiente/bolhas e texto separado |
| P0 | `sky_background` | Composição 385 × 360 | Céu e massas de nuvens sem texto, integrado em camadas |
| P0 | `roof_platform` | Faixa de cerca de 385 × 72 | Terraço, plataforma e porta lateral |
| P0 | `landing_corridor` | 80 × 40; 6 quadros | Corredor inferior de desembarque e ativação legível |
| P0 | `invasion_ships` | Nave maior de cerca de 120 × 56; menores de 48 × 24 | Cascos originais e ponto de lançamento |
| P0 | `invasion_beacon` | 24 × 32; 4 quadros | Sinalizador plantado quando um ET desembarca |
| P0 | `crosshair`, `pulse_marker` | 16 × 16 e 32 × 32 | Mira e área anunciada do pulso |
| P0 | `pulse_hit`, `containment_bubble` | 48 × 56; 4 quadros cada | Efeito de acerto e bolha, sem flash de tela inteira |
| P0 | `hud_icons` | 12 a 16 pixels por ícone | Carga, impulso, pendente, contido e infiltrado |
| P0 | `game_icon` | Fonte de 64 × 64 | Ícone original e versões de exportação |
| P1 | `title_art`, `store_key_art` | Conforme destino | Título tratado e arte comercial após pesquisa do nome |
| P1 | `et_visual_variants` | Mesma grade de 48 × 56 | Variações de identificação sem vantagem competitiva |

A dupla pode ser animada como composição única para reduzir custo e evitar que dois personagens gerados independentemente percam contato ao levantar o ET. A animação conjunta precisa conter o mesmo design de ET da captura. Nomes e legendas serão renderizados em Godot, evitando texto deformado dentro de imagens.

### Prompts-base de produção

Prompts em inglês para uso nas ferramentas; completar dimensões, direções e parâmetros conforme o endpoint disponível. Estes são briefings, não chamadas de API prontas.

**ET:**

> Original comedic alien invasion trooper attacking Earth in a 2D arcade game, side view, floating asymmetrical droplet body, lavender skin, three expressive eyes of different sizes, two short curved antennae, small circular hip-mounted hover thruster, cyan energy accents, clear compact silhouette, clean pixel art, one-pixel dark outline, limited palette, upper-left lighting, transparent background, consistent 48 by 56 pixel animation canvas. No wings, no beak, no existing franchise character, no text.

**Agentes e apresentação:**

> Two original human Earth-defense extraterrestrial containment workers, one tall and thin and one short and broad, black industrial field uniforms, subtle diagonal patches, visible expressive faces, large boots and gloves, original geometric badges. Side view clean pixel art, limited indigo and amber palette, transparent background. The pair carefully lift a small living lavender three-eyed alien under its arms to present evidence; the alien folds its arms in annoyance. Consistent character proportions and upper-left lighting. No celebrity likeness, no formal suit and sunglasses ensemble, no franchise logos, no text.

**Cenário:**

> Original 2D arcade alien invasion above a city on Earth at night, large uncluttered indigo sky, sparse stars, thin low-contrast clouds, original asymmetrical invading mothership and distant landing ships, subtle cyan atmospheric glow, recognizable terrestrial buildings, windows, rooftop defense post and emergency lights near the bottom edge, clean readable pixel art, limited palette, side-view composition, quiet central gameplay space. Separate sky and rooftop foreground layers when possible. No grass field, no tree, no animals, no characters, no text, no copied game scenery.

**Corredor de desembarque e contenção:**

> Original science-fiction containment effect for a comedic 2D pixel-art arcade, soft cyan segmented energy ring and transparent containment bubble, readable outline, short expanding pulse, small local particles, consistent limited palette and animation canvas, transparent background. No full-screen flash, no existing franchise device, no text.

### Ordem e critérios de produção

1. Gerar e escolher uma pose do ET e uma composição dos agentes; conferir personalidade, silhueta e distinção visual.
2. Montar um teste estático com fundo, ET, mira e HUD nas proporções reais.
3. Ajustar contraste e escala antes de gastar gerações com todas as animações.
4. Gerar movimentos usando a referência original escolhida e revisar quadro a quadro.
5. Produzir celebração, falha, naves, sinalizador, corredor de desembarque e FX; por último, derivados de loja e variações cosméticas.

Aceitar somente sprites com origem/pivô estáveis, canvas consistente, ausência de cortes, número de olhos e propulsor coerentes e sem tremor involuntário de escala. PNG com alpha para personagens/FX; camadas opacas quando apropriado para fundos. Não aceitar blur, contornos semitransparentes ou arte que exija reduzir hitboxes para esconder incoerência.

O conector PixelLab está disponível nesta sessão. A produção foi concluída na implementação; job/asset IDs estão no manifesto de arte.

## 9. Plano sonoro no ElevenLabs

Identidade: eletrônica curta, borbulhante e mecânica, com propulsores leves e comédia discreta. Retirar latidos, grasnidos, espingarda e paisagem sonora de lago. Todos os arquivos atuais sem licença comprovada entram em auditoria; nenhum deve ser mantido só por parecer genérico.

| Prioridade | Arquivo planejado | Duração inicial | Evento/prompt de direção |
| --- | --- | --- | --- |
| P0 | `pulse_prepare.wav` | 0,15 s | Tiny electronic capacitor swell, clear rising cue, dry, no speech or music |
| P0 | `pulse_fire.wav` | 0,25 a 0,45 s | Playful compact containment pulse, soft electric pop and short airy tail, no gunshot |
| P0 | `pulse_hit.wav` | 0,3 a 0,5 s | Soft energy bubble snap sealing around a target, light resonant pop, no gore |
| P0 | `charge_empty.wav` | 0,12 a 0,2 s | Short dull electronic rejection click, restrained, no alarm |
| P0 | `thruster_dash.wav` | 0,2 a 0,35 s | Small hover thruster puff with quick airy acceleration, no explosion |
| P0 | `thruster_ready.wav` | 0,2 s | Tiny clean rising two-note readiness chirp, no recognizable melody |
| P0 | `et_contained.wav` | 0,3 a 0,6 s | Original funny alien squeak, nonverbal bubbling grumble, no human imitation |
| P0 | `containment_collect.wav` | 0,5 a 0,8 s | Gentle tractor beam sweep drawing an energy bubble to a platform |
| P0 | `landing_corridor.wav` | 0,8 a 1,2 s | Alien landing corridor opening over Earth rooftops, soft airy shimmer and low energy swell |
| P0 | `et_land.wav` | 0,5 a 0,8 s | Quick descending sci-fi whoosh, landing thruster puff and tiny triumphant nonverbal alien chirp |
| P0 | `wave_start.wav` | 0,5 a 0,8 s | Original compact dispatch notification, crisp and optimistic |
| P0 | `wave_contained.wav` | 0,8 a 1,2 s | Short original playful electronic confirmation stinger, warm mechanical click |
| P0 | `wave_breached.wav` | 0,8 a 1,2 s | Short original awkward electronic descending stinger, comedic without laughter |
| P0 | `agent_door.wav` | 0,4 a 0,7 s | Small industrial sliding hatch opening with restrained mechanical movement |
| P0 | `ui_confirm.wav` | 0,1 a 0,2 s | Soft concise electronic button confirmation, dry |
| P0 | `night_ambience.ogg` | 20 a 30 s, loop | Quiet Earth city rooftop under alien invasion, faint distant ventilation and restrained hovering mothership hum, no birds, voices or music |
| P1 | `et_hover_loop.ogg` | 3 a 5 s, loop | Very soft small hover engine flutter, no harsh high frequencies |

Gerar duas ou três variantes dos SFX frequentes e selecionar pelo contexto de jogo, não apenas ouvindo isoladamente. Tiro e dash devem permanecer reconhecíveis em volume baixo. O aviso do pulso tem prioridade sobre ambiente e vocalizações.

Preferir master WAV e converter somente a distribuição quando necessário. Cortar silêncio inicial, remover estalos nas bordas, manter margem contra clipping e verificar loops de ambiente. Se um master vier em outro formato, converter sem apresentar a conversão como aumento de qualidade.

Separar buses `SFX`, `Ambiente` e, se houver dublagem posterior, `Voz`. Não instanciar o mesmo ambiente em cada ET ou mira. Cada evento sonoro toca uma vez por cliente, mesmo quando há múltiplas confirmações de rede; limiter/cooldown evita repetição do som de carga vazia ao segurar o botão.

Trilha musical fica fora do primeiro pacote. Uma trilha original/licenciada pode ser adicionada depois; o banjo atual não permanece sem procedência comprovada. A fala “Tá aqui a prova!” é legenda suficiente para esta entrega.

ElevenLabs foi utilizado pela API com a chave existente no ambiente. O criador autorizou sons gratuitos provisórios apenas para testes; os sons precisam ser refeitos antes da publicação comercial.

## 10. Integração prevista no Godot

Implementar após revisar esta proposta e fechar a prancha original. Não misturar a troca final de identidade com uma migração indiscriminada de todos os caminhos de rede.

| Arquivo/área atual | Trabalho previsto |
| --- | --- |
| `scenes/pato/pato.gd` e `.tscn` | Novo ET, estados de movimento/contido/infiltrado, animações e hitbox; nomes internos podem ser migrados em etapa própria |
| `scenes/alvo/alvo.gd` e `.tscn` | Mira original, preparação de pulso, cargas e cooldown independente do áudio |
| `scenes/cao/cao.gd` e `.tscn` | Substituir por cena de equipe/resultado; eliminar patrulha, latido e sinal `cachorro_pulou` |
| `scenes/main/main.gd` e `.tscn` | Estados da onda, spawn aéreo, HUD próprio, desembarque, placar e relatório de sessão |
| `scenes/audio/audio.tscn` | Áudio por responsabilidade e buses; remover dependência de sons antigos |
| `scenes/lobby/lobby.gd` e `.tscn` | Papéis Agente/ET, instruções, estilo e nome provisório |
| `scenes/gamemanager.gd` | Textos de papéis e limites coerentes; manter handshake e transporte funcionando |
| `scenes/network/online_network_manager.gd` | Auditar textos/identidade; nenhuma mudança de transporte é necessária para o redesign |
| `project.godot`, `icon.svg`, `export_presets.cfg` | Nome, ícone, metadados e diretório de exportação próprios |
| `README.md` | Apresentar o jogo novo, três modos reais, dois ETs e regras efetivamente implementadas |

Estrutura sugerida para assets novos:

```text
assets/alien_redesign/
  characters/et/
  characters/agents/
  environment/
  fx/
  ui/
  audio/sfx/
  audio/ambience/
```

Novas cenas podem usar `scenes/et/` e `scenes/round_presentation/`. Alterar preloads, spawnable scenes, NodePaths, sinais e replicação no mesmo passo de cada renomeação. Os paths antigos são referências de migração, não a identidade que deve aparecer para o jogador.

### Regras de rede e consistência

- Host determina estado, relógio, cargas válidas, resultado de cada pulso, captura/desembarque e avanço de sessão. Cliente pede ações; não declara vitória ou captura.
- O movimento humano atualmente usa autoridade do cliente. Definir validação mínima no host para velocidade, limites e estado antes de chamar o novo fluxo de competitivo; não presumir que o código atual já valida tudo.
- Eventos levam ID de onda, ID de ação e ID de ET para descartar repetições e mensagens atrasadas.
- Contar captura/desembarque uma vez, por estado lógico. Área inferior ou callback de animação não pode conceder ponto outra vez.
- Separar o recolhimento de capturados e o corredor de desembarque por estado e detecção. Um ET vivo que alcança a cidade não pode ser contado como captura pela antiga área inferior de `main.tscn`.
- Desativar mira ofensiva durante briefing, resultado e relatório. Uma animação cosmética nunca decide quando inicia a próxima rodada.
- Desembarque só se resolve no host; gesto final, legenda e stinger são apresentados em todos os clientes a partir desse resultado.
- Verificar empates temporais: o host processa pulso e desembarque em ordem definida; encerrado o estado do ET, eventos posteriores não o mudam.
- Preservar o mecanismo existente de esperar os peers carregarem suas cenas antes de spawnar. Não introduzir spawns antes de os novos spawners existirem.
- Cliente que perde conexão retorna ao lobby. ET humano desconectado pode passar para IA durante a onda, como já há suporte; definir também o novo orçamento de cargas se um Agente sair.

Fazer primeiro o pulso funcional, a captura e a resolução com placeholders. A animação final entra depois que esses estados funcionarem em solo e rede.

## 11. Identidade, procedência e publicação

### Independência criativa

- Criar arte, áudio, ícones, interfaces e marca próprios. Não redesenhar em cima das peças do atlas antigo.
- Não usar Duck Hunt, Nintendo ou Men in Black como nome, logo ou promessa de associação na apresentação comercial.
- Aproximações temáticas genéricas não devem reproduzir figurino, rosto, dispositivo ou composição específica de outra obra.
- Nome, logo e nomes de personagens precisam de pesquisa de disponibilidade antes de lançamento. O título de trabalho não está liberado por este plano.

No Brasil, ideias e regras de jogos como tais são excluídas da proteção autoral; arte, áudio e adaptações exigem avaliação própria. A finalidade deste redesign é produzir expressão original, sem depender de uma suposta porcentagem mínima de diferença. [Lei nº 9.610/1998, arts. 7, 8 e 29](https://www.planalto.gov.br/ccivil_03/leis/l9610.htm). Marca é uma análise distinta; verificar nomes semelhantes no segmento de jogos. [Guia do INPI](https://www.gov.br/inpi/pt-br/assuntos/marcas).

### Licenças dos serviços

Os termos consultados do PixelLab permitem uso comercial dos outputs, mantendo no usuário a responsabilidade por não infringir direitos de terceiros. Essa permissão contratual não é garantia de originalidade ou de proteção autoral do resultado em toda jurisdição. [Termos do PixelLab](https://www.pixellab.ai/termsofservice).

Para ElevenLabs, a orientação consultada informa que o plano gratuito não concede licença comercial; conteúdo gerado durante assinatura paga pode ser usado comercialmente, observadas as condições do serviço e exclusões de serviços beta. Não presumir que assinar depois libera retroativamente sons produzidos gratuitamente. Registrar o plano vigente na data de cada geração. [Publicação de conteúdo no ElevenLabs](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform).

Condições consultadas em 07/10/2026; conferir novamente na produção e na preparação do release.

### Registro de assets e limpeza da distribuição

Criar manifesto de produção com: caminho do arquivo, ferramenta/origem, prompt, referência original usada, data, job/asset ID, plano/licença, comprovante ou versão dos termos, alterações manuais e crédito necessário. Documentar também fonte tipográfica e bibliotecas/addons, preservando notices exigidos.

Na fase de release, fazer inventário de recursos antigos, remover referências e preparar um pacote com apenas assets aprovados. O preset atual exporta todos os recursos: deixar um sprite antigo sem uso dentro do projeto não comprova sua exclusão do PCK. Conferir o conteúdo real do pacote.

Não redistribuir builds antigos com a nova página de loja. Se eles contiverem conteúdo não autorizado, retirar esses arquivos da distribuição pública; limpeza de histórico de repositório público, se necessária, é uma tarefa separada por seu impacto. O redesign não resolve retroativamente uma publicação anterior.

## 12. Etapas de execução e critérios de aceite

| Etapa | Entregável | Critério para avançar |
| --- | --- | --- |
| 1. Direção | Prancha original do ET/agentes, teste estático de cenário/HUD e manifesto inicial | Silhuetas legíveis, personalidade própria e escala consistente |
| 2. Núcleo jogável | Onda com placeholders, pulso anunciado, impulso, contenção e desembarque | Duelo compreensível; captura e infiltração resolvem uma vez; números de HUD concordam |
| 3. Arte | Sprites, cidade terrestre, naves invasoras, corredor, sinalizador, FX e dupla de agentes | Sem cortes, tremor de pivô, partes inconsistentes ou assets do atlas anterior |
| 4. Interface e sessão | Lobby, instruções por papel, placar, cinco ondas solo/melhor de cinco multiplayer e relatório | Cada papel entende objetivo e resultado sem ler documentação externa |
| 5. Som | SFX/ambiente ElevenLabs, mixagem e controles | Licenças documentadas; feedback sem clipping; nenhum tempo de regra preso ao áudio |
| 6. Validação e release | Build novo, README correto, ícone/metadados e inventário do pacote | Três modos verificados; procedência completa; ausência dos recursos antigos no pacote |

### Roteiro de playtest

- Solo: completar uma sessão com captura perfeita, captura parcial, todos os desembarques e cargas esgotadas; conferir os dois desfechos de defesa da cidade.
- ET humano: mover em todas as direções, impulsionar, recarregar impulso, ser capturado e desembarcar com feedback coerente.
- Multiplayer local e online: repetir com dois e quatro participantes; confirmar que os dois lados veem aviso, captura, relógio e resultado.
- Testar as composições de equipes descritas no balanceamento e registrar se a vitória decorreu de habilidade ou excesso de cargas.
- Conferir desconexão de host, ET e Agente durante defesa, desembarque e resultado, além de retorno ao lobby e nova sessão.
- Testar último pulso contra início/fim da desembarque, dois pulsos atingindo o mesmo ET e ETs sobrepostos.
- Jogar sem áudio; objetivo, ameaça, cargas e resultado devem continuar legíveis.
- Conferir cena de levantar o ET repetida por várias ondas: deve continuar curta e funcionar em movimento reduzido.
- Inspecionar sprites no tamanho real de jogo, animações com hitbox visível e screenshots limpas do build final.

Métricas úteis: precisão, cargas restantes, capturas por onda, impulso usado versus guardado, tempo entre resolução e controle recuperado e vitórias por composição de sala. Não fixar aprovação em 50% de vitória com poucas partidas; combinar números com relato de legibilidade e justiça.

### Cortes deliberados

Fora da primeira entrega: novos mapas, bosses, árvores de habilidades, várias armas, progressão permanente, loja de cosméticos, narração obrigatória, troca automática de papéis, implementação mobile completa e trilha musical extensa. Esses itens não são necessários para validar a identidade e o duelo propostos.

## 13. Próxima ação concreta

Produzir no PixelLab a pose-base original de Zizi como invasor, os dois agentes da defesa terrestre e um fundo com cidade e naves inimigas. Montar a prancha no tamanho real do jogo e revisar visualmente antes de gerar as animações. Em seguida, implementar a onda com placeholders e testar o aviso do pulso contra o impulso do ET e a descida para o desembarque. O primeiro pacote de ElevenLabs deve cobrir preparação, disparo, acerto, impulso, corredor de desembarque e resultado.

Esta especificação registra o planejamento inicial. A implementação aprovada pelo criador está em `scenes/invasion/`; suas decisões finais e evidências estão em `docs/implementacao_invasao.md`.
