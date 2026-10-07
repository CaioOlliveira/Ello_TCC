# Ello Mobile

Aplicativo Flutter do Ello. A documentação geral e as instruções completas estão no [README principal](../README.md).

## Execução

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

No emulador Android, `10.0.2.2` aponta para o `localhost` do computador. Em um aparelho físico, use o IP local da máquina que está executando a API.

## Qualidade

```bash
flutter analyze
flutter test
```
