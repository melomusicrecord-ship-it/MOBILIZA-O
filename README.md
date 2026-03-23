# 🏥 Mobilização DNSP Angola — v2.1
**República de Angola · Ministério da Saúde · Direcção Nacional de Saúde Pública**

---

## 📁 Estrutura do projecto

```
mobilizacao-dnsp/
├── public/                  ← Pasta a publicar no Netlify
│   ├── index.html           ← Aplicação completa (toda a lógica)
│   ├── config.js            ← ⚠️ PREENCHER com dados do Supabase
│   ├── manifest.json        ← PWA manifest (instalar como app)
│   └── sw.js                ← Service Worker (modo offline)
├── electron/
│   └── main.js              ← App desktop Windows/Mac/Linux
├── supabase_schema.sql      ← Executar no Supabase SQL Editor
├── package.json             ← Configuração Electron
├── netlify.toml             ← Configuração Netlify
└── README.md
```

---

## 🚀 Passo 1 — Supabase (base de dados)

1. Cria conta em **supabase.com** → New Project
2. Guarda: **Project URL** e **anon key** (Settings → API)
3. Vai a **SQL Editor** → cola o conteúdo de `supabase_schema.sql` → **Run**
4. As tabelas `mobilizacao` e `criancas_bairro` são criadas automaticamente

---

## ⚙️ Passo 2 — config.js (credenciais)

Abre `public/config.js` e substitui:

```javascript
const SUPABASE_URL      = 'https://SEU_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGci...';
```

---

## 🌐 Passo 3 — Netlify (publicar online)

**Opção rápida (sem conta):**
- Vai a **app.netlify.com/drop**
- Arrasta a pasta `public/` → site online em segundos

**Opção com conta (recomendado para produção):**
1. Cria conta em netlify.com
2. New site → Import from Git ou arrasta a pasta
3. O `netlify.toml` configura tudo automaticamente

---

## 📱 Passo 4 — Instalar como App (PWA)

### Desktop (Chrome / Edge)
- Abre o site publicado
- Clica em **📥 Instalar App** na barra do topo
- Ou: ícone de instalação na barra de endereço do browser

### Android
- Chrome → menu (⋮) → **Adicionar ao ecrã inicial**

### iPhone / iPad
- Safari → botão Partilhar → **Adicionar ao ecrã inicial**

✅ Funciona **100% offline** — guarda dados localmente
✅ **Sincroniza automaticamente** ao voltar a ter internet

---

## 🖥️ App Desktop Electron (Windows/Mac/Linux)

Requer **Node.js 18+** — descarregar em nodejs.org

```bash
# Instalar dependências (só uma vez)
npm install

# Executar em modo desenvolvimento
npm start

# Criar instalador Windows (.exe)
npm run build

# O instalador fica na pasta dist/
```

---

## 📶 Como funciona offline

| Situação | O que acontece |
|----------|---------------|
| Sem internet | Dados guardados no browser (localStorage) |
| Banner amarelo | Indica que está offline + nº de registos pendentes |
| Volta online | Sincronização automática com o Supabase |
| Botão 🔄 | Forçar sincronização manual |
| Verificação | A cada 30 segundos verifica a ligação |

---

## ✨ Funcionalidades

| Módulo | Descrição |
|--------|-----------|
| **Nova Ficha** | Grelha de quadrados: 4×14 (Casa a casa) + 1×14 (outros locais) |
| **Totais automáticos** | Sub-totais por linha + total geral em tempo real |
| **Crianças <5 Anos** | Contagem por bairro com % de cobertura |
| **Registos** | Lista e pesquisa de todas as fichas |
| **Consolidação** | Ficha física por mobilizador, pronta a imprimir A4 |
| **Relatório** | Métricas gerais da campanha por bairro |
| **Offline/Online** | Funciona sem internet, sincroniza ao ligar |
| **PWA** | Instala no desktop e telemóvel como app nativa |
| **Electron** | App instalável para Windows/Mac/Linux |

---

## 🔐 Segurança (produção)

Para exigir autenticação (opcional):

```sql
-- No Supabase SQL Editor:
DROP POLICY "allow_all_mob" ON mobilizacao;
DROP POLICY "allow_all_cri" ON criancas_bairro;

CREATE POLICY "auth_only_mob" ON mobilizacao
  FOR ALL USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "auth_only_cri" ON criancas_bairro
  FOR ALL USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');
```
