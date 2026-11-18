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
- Renderizador gl_compatibility; opção de 30 FPS ainda NÃO implementada (use `Engine.max_fps = 30`)

## Limitações conhecidas
- Gráficos são formas primitivas (placeholders), não pixel art
- Não testado em iPhone nem executado em Godot durante a criação deste código
