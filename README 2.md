# Reinos de Ferro — v0.1 (Godot 4.3+, GDScript, 2D)

## Como executar
1. Instale o Godot 4.3 ou superior (versão padrão, sem .NET).
2. "Importar" → selecione `project.godot` → abra o projeto (a primeira abertura gera o cache de classes).
3. F5 para rodar. Computador: setas = mover, Espaço = atacar, Shift = esquiva, E = ação (mercado), R = correr. O mouse simula toque.
4. iPhone: precisa de Mac + Xcode + conta Apple Developer. Projeto > Exportar > iOS. Orientação já configurada para paisagem.

## Estrutura
- `scripts/world/` estado global, relógio, estações, salvamento, cena principal e Sim (LOD de simulação)
- `scripts/player/`, `scripts/npcs/`, `scripts/caravans/`, `scripts/economy/`, `scripts/kingdoms/`, `scripts/ui/`
- `combat/`, `inventory/`, `quests/`: pastas reservadas para a expansão (hoje o combate vive em player.gd e npc.gd)

## Otimização já implementada
- 3 níveis de simulação (perto 100%, região ~2,5 Hz, longe 0,5 Hz sem desenhar)
- Caravanas calculadas por distância ao longo da estrada; emboscadas resolvidas estatisticamente
- Guerra resolvida por cálculo estratégico (sem soldados em cena)
- Sem física para NPCs, sem texturas, sem shaders, sem iluminação dinâmica; mundo estático desenhado uma vez
- Renderizador gl_compatibility, viewport 960×540 e limite de 30 FPS para reduzir aquecimento e consumo no celular
- HUD com joystick virtual à esquerda e botões de ação à direita; suporta vários dedos simultaneamente

## Configuração iPhone 11\n- Projeto em orientação paisagem, renderizador Compatibility e 30 FPS.\n- Os controles de toque já estão no HUD; não é necessário conectar controle Bluetooth.\n- A versão iPhone via Safari/PWA depende da publicação no GitHub Pages descrita em `INSTALAR_NO_IPHONE.md`.\n\n## Limitações conhecidas
- Gráficos são formas primitivas (placeholders), não pixel art
- Não testado em iPhone nem executado em Godot durante a criação deste código
