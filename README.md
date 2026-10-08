# GeoTrack SIG — GEOLAYER (versão de teste)

Primeira versão completa, gerada a partir de toda a especificação acordada, para testares e
identificarmos juntos o que precisa de correção. Nada aqui é definitivo — é a base para a
ronda de testes.

## 0. Já tens o projeto a correr? Só precisas de atualizar

Se já tinhas corrido os scripts 001 a 005 e já publicaste o site, **não precisas de repetir
nada disso**. Só:

1. No SQL Editor do Supabase, corre `sql/006_atualizacoes.sql` (é seguro correr mesmo que
   algumas destas linhas já existam — usa `on conflict ... do nothing`).
2. Substitui a tua pasta `docs/` local por esta nova (a `supabase-client.js` já vem com a
   tua anon key preenchida), e volta a fazer `git add docs`, `git commit`, `git push`.

Esta ronda corrigiu, entre outras coisas: o filtro do mapa a exigir sempre um cliente, o
zoom automático ao escolher um projeto, a ferramenta de medir distâncias (ver nota sobre a
versão do Leaflet, abaixo), a importação das Zonas ANAC sem feedback nenhum, "Novo Cliente"
a abrir por baixo da tabela em vez de um painel lateral, e os PFs só poderem ser criados um
a um (agora há importação em massa a partir de um TXT). Lista completa no fundo deste README.

**Nota técnica sobre o mapa**: a ferramenta de medir linhas tinha um problema real de
compatibilidade entre a versão mais recente do Leaflet (1.9.4) e a biblioteca de desenho
Leaflet.draw (parada em 1.0.4, sem haver versão mais recente) — o botão "Finish" não
reagia. A correção foi fixar o Leaflet na versão 1.7.1, a última testada e compatível com
essa biblioteca de desenho.

## 1. Configurar o Supabase (só para uma instalação nova, do zero)

O projeto Supabase já existe (`jixbsdhiingyivfczafe.supabase.co`). Falta:

1. **Correr os scripts SQL**, por esta ordem, no SQL Editor do Supabase:
   - `sql/001_schema.sql` — tabelas, PostGIS, triggers
   - `sql/002_rls.sql` — segurança por linha (RLS)
   - `sql/003_seed.sql` — dados de arranque + 1 cliente/projeto/PFs de teste
   - `sql/004_funcoes_geojson.sql` — funções para guardar geometria desenhada no mapa
   - `sql/005_views.sql` — vistas que expõem a geometria em GeoJSON para os mapas
   - `sql/006_atualizacoes.sql` — ajustes desta ronda (ver secção 0)

2. **Obter a "anon key"**: Project Settings → API → `anon public`. Cola-a em
   `docs/js/supabase-client.js`, na variável `SUPABASE_ANON_KEY`.

3. **Criar o teu utilizador de administração**: Authentication → Users → Add User,
   com o teu email `@geolayer.com` (ex: lsimoes@geolayer.com) e uma password. A app
   reconhece automaticamente qualquer email `@geolayer.com` como administração — não
   precisas de mais nenhuma configuração para isso.

4. **Criar os buckets de Storage** (Storage → New bucket): `fotos-pfs` e `anexos-projetos`.
   O upload de fotos de PFs e dos anexos 2/3 ainda não está ligado a estes buckets no
   código desta versão — é um dos ajustes de uma próxima ronda (ver secção 4).

5. **Edge Functions** — publica as 3 pastas em `supabase/functions/` com o Supabase CLI:
   ```
   supabase functions deploy send-email
   supabase functions deploy create-client-user
   supabase functions deploy confirmar-ativacao
   ```
   E define os secrets (Project Settings → Edge Functions → Secrets):
   - `GMAIL_USER` — ex: geolayer@gmail.com
   - `GMAIL_APP_PASSWORD` — a App Password gerada na conta Google

## 2. Publicar o frontend (GitHub Pages)

A pasta `docs/` é o site inteiro — é estático, não precisa de build. Chama-se `docs`
porque é um dos dois únicos nomes que o GitHub Pages aceita (o outro é publicar a
partir da raiz do repositório):

```
git init
git add docs
git commit -m "GeoTrack SIG — versão de teste"
git branch -M main
git remote add origin <o teu repositório>
git push -u origin main
```

Depois, no GitHub: Settings → Pages → Source: branch `main`, pasta `/docs`.

## 3. Como testar

- Abre o site publicado → "Sou Administração" → entra com o utilizador que criaste no passo 1.3.
- Já existe um **cliente e projeto de teste** (criados pelo `003_seed.sql`) para experimentares
  o mapa, os PFs, e a geração de documentos sem teres de preencher tudo à mão primeiro.
- Experimenta: Projetos → abrir o projeto de teste → botões de "Geração de Documentos".
- Configurações → os 7 separadores já vêm com os valores de exemplo que tiraste dos
  documentos reais (nomes, textos, equipamento), e agora também com um separador
  "Página Inicial" para personalizares o título/imagem/texto da página de entrada.

## 4. O que fica para quando tiveres tempo (combinado nesta ronda)

Ficou acordado que estes três ficam para outra sessão, porque precisam de mais conversa
antes de avançar:

- **Histórico → separar em Auditoria + Lembretes**: a página "Histórico" atual mistura
  registo automático de acessos com notas manuais, e tem um "marcar como lido" que não
  fazia sentido para tudo. Fica para redesenhar como duas coisas distintas.
- **Configurações → Textos dos Relatórios**: só tem os blocos 4.4 e 4.5 — falta mapear o
  resto do relatório de produção completo.
- **Projetos → geração de documentos**: ainda não está a sair bem, é um tópico à parte.

## 5. O que ainda fica para uma ronda de correções seguinte

- **CAOP real**: `caop_freguesias` só tem 1 freguesia de exemplo (Mealhada). Para projetos
  noutras zonas, importa o CAOP2024 (simplificado) para essa tabela.
- **Bounding box WGS84 nos Metadados XML**: por agora o XML gerado não calcula a
  bounding box automática a partir da geometria do projeto — falta uma função RPC
  equivalente às de `004_funcoes_geojson.sql`.
- **Upload de fotos de PFs e dos Anexos 2/3**: os campos de ficheiro existem no formulário,
  mas ainda não escrevem para o Supabase Storage nem fundem esses PDFs no Dossier Completo.
- **Upload do logótipo e da imagem da página inicial**: por agora são só campos de URL
  (colar o link de uma imagem já alojada); upload direto de ficheiro fica para mais tarde.
- **Confirmar-ativação / primeiro acesso de cliente**: o fluxo está todo desenhado e a
  Edge Function `confirmar-ativacao` está pronta, mas testa o percurso completo
  (criar cliente → criar login → receber email → ativar) porque é a parte com mais peças
  a encaixar.
- **Algoritmo de horas dos PFs**: a versão em `docs/admin/pfs.html` é uma simplificação
  do algoritmo completo (tolerância de 10 min, salto de domingo) — a lógica principal
  (almoço 13h-14h, fim do dia às 18h) está lá, mas vale a pena testares casos limite.
- **Design visual**: propositadamente simples (sem gastar tempo em CSS antes de validarmos
  que os dados e os fluxos estão certos). Depois de testares o funcionamento, tratamos do
  aspeto visual.

Testa à vontade e diz-me exatamente o que corrigir — é para isso que esta versão existe.
