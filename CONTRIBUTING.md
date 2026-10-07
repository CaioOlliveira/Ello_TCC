# Como contribuir

Obrigado por contribuir com o Ello. Este guia mantém o histórico do projeto organizado e facilita a revisão das mudanças.

## Fluxo de trabalho

1. Atualize a branch principal com `git pull origin main`.
2. Crie uma branch curta e descritiva:

   ```bash
   git switch -c feature/nome-da-funcionalidade
   ```

3. Faça alterações pequenas e relacionadas entre si.
4. Execute as verificações locais antes de abrir um pull request.
5. Envie a branch e abra um pull request para `main`.

Prefixos sugeridos para branches: `feature/`, `fix/`, `docs/`, `refactor/` e `test/`.

## Commits

Use mensagens objetivas no padrão Conventional Commits:

```text
feat: adiciona lembrete de medicamento
fix: corrige horário exibido na agenda
docs: atualiza instruções de instalação
test: cobre validação de glicemia
refactor: simplifica serviço de notificações
```

## Verificações locais

### API

```bash
cd backend
npm ci
npm run lint
npm test
npm run build
```

### Flutter

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

## Pull requests

Descreva o problema resolvido, as principais mudanças e como validar o resultado. Para alterações visuais, inclua imagens ou uma gravação curta, removendo previamente qualquer dado pessoal.

## Versões e releases

O projeto usa Versionamento Semântico:

- `PATCH` para correções compatíveis;
- `MINOR` para novas funcionalidades compatíveis;
- `MAJOR` para mudanças incompatíveis.

Antes de criar uma tag, atualize as versões em `backend/package.json` e `mobile/pubspec.yaml`, valide o CI e registre um resumo das mudanças na release do GitHub.
