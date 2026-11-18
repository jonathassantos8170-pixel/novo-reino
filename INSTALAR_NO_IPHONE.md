# Instalar no iPhone 11 (sem Mac, sem Xcode, sem pagar nada)

O jogo vira um app na tela inicial do iPhone (PWA), aberto pelo Safari.

1. Crie uma conta grátis em github.com e clique em "New repository" (nome: reinos-de-ferro, público).
2. Em "uploading an existing file", arraste TODO o conteúdo desta pasta (inclusive a pasta oculta .github). Clique "Commit changes".
   Se a pasta .github não subir pelo navegador, crie o arquivo ".github/workflows/web.yml" manualmente ("Add file > Create new file") e cole o conteúdo.
3. Vá em Settings > Pages > Build and deployment > Source: "GitHub Actions".
4. Aba Actions: espere o fluxo "Publicar jogo" ficar verde (2-4 min). Se não rodar, clique em "Run workflow".
5. Seu link será https://SEU-USUARIO.github.io/reinos-de-ferro/
6. No iPhone, abra o link no SAFARI > botão Compartilhar > "Adicionar à Tela de Início".
   Gire o aparelho para paisagem e abra pelo ícone.

Observações: o desempenho no Safari é menor que o de um app nativo; use 30 FPS nas Configurações se esquentar.
O salvamento fica no armazenamento do navegador (apagar dados do Safari apaga o save).
Um app nativo (.ipa) exige Mac com Xcode e conta Apple; não dá para gerar esse arquivo sem isso.
