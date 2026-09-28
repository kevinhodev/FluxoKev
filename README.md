# Fluxo IA

Aplicativo Android de gestão financeira com Flutter e backend TypeScript/PostgreSQL.
A interface usa Inter, ícones Lucide, motor financeiro determinístico e arquitetura
por features.

## Preparação

O SDK Flutter está instalado em `C:\Users\user\Flutter`. Execute na raiz:

```powershell
flutter pub get
flutter run
```

O aplicativo abre na tela de login e usa a API local em
`http://10.0.2.2:8080` no emulador Android. Entre com `BOOTSTRAP_EMAIL` e
`BOOTSTRAP_PASSWORD` definidos em `backend/.env`. A senha não é persistida no
aparelho.

As telas reais carregam contas, cartões, categorias e transações da API. A aba
`Compromissos` resume compras parceladas, saldo restante e recorrências mensais;
o extrato completo permanece disponível como acesso secundário. PREVI e
empréstimos permanecem fora dos totais até que seus PDFs sejam importados, para
não misturar mocks com dados financeiros reais.

Depois de adicionar ou atualizar plugins Android, encerre a execução atual e inicie
novamente em vez de usar apenas hot reload.

## Verificação

```powershell
dart format lib test
flutter analyze
flutter test
```

O backend fica em [`backend`](backend/README.md). Ele pode ser compilado e testado
localmente com Node.js sem banco:

```powershell
cd backend
npm.cmd install
npm.cmd run check
npm.cmd test
```

Para executar API e PostgreSQL juntos, instale o Docker Desktop e siga o README do
backend.

## Estrutura

- `lib/app`: tema, navegação e shell principal.
- `lib/core`: tokens e componentes compartilhados.
- `lib/features`: telas, domínio e repositórios do aplicativo.
- `backend`: API, migrações e persistência PostgreSQL.
- `test`: testes funcionais e visuais do aplicativo.
