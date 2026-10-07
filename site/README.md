# Site institucional do Ello

Landing page estática usada para apresentar o projeto, divulgar os formulários da pesquisa e concentrar os links públicos do Ello.

**Produção:** [site-ello-rho.vercel.app](https://site-ello-rho.vercel.app)

## Desenvolvimento local

Você pode abrir `index.html` diretamente no navegador ou iniciar um servidor estático:

```bash
python -m http.server 4173 --directory site
```

Depois, acesse `http://localhost:4173`.

## Publicação no Vercel

O site deve usar este mesmo repositório como origem, mantendo um projeto separado no Vercel com estas configurações:

| Configuração      | Valor                    |
| ----------------- | ------------------------ |
| Repositório       | `CaioOlliveira/Ello_TCC` |
| Production Branch | `main`                   |
| Root Directory    | `site`                   |
| Framework Preset  | `Other`                  |
| Build Command     | vazio                    |
| Output Directory  | `.`                      |

Para preservar o endereço já divulgado, altere o repositório conectado no projeto atual do Vercel, em vez de criar outro projeto:

1. abra **Project Settings > Git** e desconecte `CaioOlliveira/site_ello`;
2. conecte `CaioOlliveira/Ello_TCC`;
3. em **Build and Deployment**, defina `site` como **Root Directory**;
4. crie um novo deployment da branch `main`;
5. confirme o endereço de produção e os links da página antes de remover o repositório antigo.

O diretório local `.vercel/` contém identificadores da conta e não deve ser versionado.
