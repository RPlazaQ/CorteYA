# Cómo usar las skills de CorteYa

Se agregaron 12 skills funcionales a `.claude/skills/` (instrucciones en español + scripts en Python listos para correr) enfocadas en generación de leads, publicidad/outreach y automatización de tareas.

| Skill | Categoría |
|---|---|
| `gmaps-leads` | Generación de leads |
| `scrape-leads` | Generación de leads |
| `classify-leads` | Generación de leads |
| `casualize-names` | Generación de leads |
| `instantly-campaigns` | Publicidad |
| `instantly-autoreply` | Publicidad / automatización |
| `gmail-inbox` | Automatización |
| `gmail-label` | Automatización |
| `onboarding-kickoff` | Automatización |
| `welcome-email` | Automatización |
| `create-proposal` | Automatización |
| `add-webhook` | Automatización (requiere infraestructura extra, ver su SKILL.md) |

## Puesta en marcha (una sola vez)

1. **Instalar Python 3.10+** (si no lo tienes) y las dependencias:
   ```bash
   cd ~/Desktop/CorteYa
   pip install -r requirements.txt
   ```

2. **Configurar las claves de API:**
   ```bash
   cp .env.example .env
   ```
   Edita `.env` y llena solo las claves de los servicios que vayas a usar:
   - `ANTHROPIC_API_KEY` — usada por casi todas las skills. Se obtiene en [console.anthropic.com](https://console.anthropic.com/)
   - `APIFY_API_TOKEN` — para `gmaps-leads` y `scrape-leads`. Se obtiene en [apify.com](https://apify.com/)
   - `INSTANTLY_API_KEY` — para las campañas de correo. Se obtiene en [instantly.ai](https://instantly.ai/)
   - `PANDADOC_API_KEY` — para `create-proposal`. Se obtiene en [pandadoc.com](https://pandadoc.com/)
   - `ANYMAILFINDER_API_KEY` — opcional, para enriquecer correos en `scrape-leads`

3. **Google Sheets / Gmail (opcional, si usarás esas skills):**
   - Crea credenciales OAuth en [Google Cloud Console](https://console.cloud.google.com/) (tipo "Desktop app")
   - Descárgalas como `credentials.json` en la raíz de esta carpeta
   - Para Gmail: `cp gmail_accounts.json.example gmail_accounts.json` y edítalo con tu correo
   - La primera vez que corras una skill de Gmail/Sheets se abrirá el navegador para autorizar el acceso

## Cómo correrlas

Simplemente pídemelo en lenguaje natural mientras trabajas en esta carpeta (CorteYa) — por ejemplo:
- "Busca barberías en Providencia con gmaps-leads"
- "Crea las campañas de correo en Instantly para las barberías de la hoja X"
- "Etiqueta mi bandeja de Gmail"

Cada skill se activa sola según lo que pidas. También puedes correr los scripts directamente:
```bash
python3 .claude/skills/gmaps-leads/scripts/gmaps_lead_pipeline.py --search "barberías en Providencia, Santiago" --limit 10
```

## Notas
- `add-webhook` es la única skill que necesita infraestructura adicional (cuenta en Modal) — las otras 11 funcionan solo con `pip install` + `.env`.
- `onboarding-kickoff` incluye un script "todo en uno" (`onboarding_post_kickoff.py`) que quedó desactualizado respecto a esta estructura de carpetas — usa el proceso paso a paso descrito en su `SKILL.md`, que sí funciona.
- Los archivos `.tmp/` que generan las skills son intermedios, no se suben a ningún lado — los entregables reales quedan en Google Sheets, Instantly, PandaDoc, etc.
