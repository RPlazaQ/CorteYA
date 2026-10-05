# Onboarding de landing personalizada (add-on)

Checklist para cuando un cliente compra la página personalizada
(`corteya.app/<slug>` o `tubarberia.cl`), aparte del plan normal.

Plantillas base, listas para duplicar: `landing-templates/clasico.html`
(gentleman's club, serif/dorado) y `landing-templates/urbano.html`
(outline/editorial, inspirado en referencias tipo "Neo Barbería"). Mándale
al cliente los dos links de ejemplo para que elija estilo antes de
empezar — ver [[corteya_pricing_strategy]] para los dos links públicos
vigentes de la demo.

## 0. Datos que necesitas pedirle al cliente antes de armar nada

- Estilo elegido: Clásico o Urbano
- Nombre de la barbería
- Dirección completa + comuna
- Teléfono de contacto
- Correo (para el footer/contacto)
- Instagram (handle)
- Horario de atención, día por día
- Lista de servicios: nombre, duración, precio
- Equipo: nombre, especialidad/rol, años de oficio, una línea de bio por
  cada barbero
- 2-3 reseñas reales si tiene (si no, se dejan las genéricas de la
  plantilla o se omite esa sección)
- Color de marca — si no tiene uno definido, pruébalo tú mismo con el
  selector de la plantilla (ver paso 3) y que lo confirme
- Fotos reales del local/trabajos, si tiene — si no, se deja la galería
  con los placeholders de íconos por ahora (no perseguir esto todavía,
  ver nota en [[corteya_pricing_strategy]] sobre no sobre-construir el
  upload de fotos hasta que un cliente real lo pida)
- ¿`corteya.app/<slug>` o dominio propio? Si es dominio propio, el `slug`
  igual lo necesitas (es el mismo que usa su link de reserva en
  `/agenda/<slug>`)

## 1. Duplicar la plantilla

```
cp landing-templates/clasico.html public/landing-<slug>.html
```

(o `urbano.html` según el estilo elegido).

## 2. Reemplazar el contenido

Busca estos textos dentro del archivo copiado y cámbialos por los datos
reales del cliente (son los mismos en ambas plantillas, salvo donde se
indica):

| Qué buscar | Aparece en | Reemplazar por |
|---|---|---|
| `La Navaja` / `LA NAVAJA` | `<title>`, header, hero, galería (solo clásico), footer | Nombre real |
| `Av. Las Condes 1234, Local 3` | Hero, ubicación, footer | Dirección real |
| `Las Condes` (comuna, en ubicación) | Ubicación, footer urbano | Comuna real |
| `+56 9 1234 5678` | Ubicación/footer | Teléfono real |
| `hola@lanavaja.cl` | Contacto (solo clásico) | Correo real |
| `@barbería.lanavaja` | Instagram banner (solo clásico) | Handle real |
| `Manuel Soto` / `Camila Reyes` / `Jorge Ibáñez` (clásico) — `Manuel` / `Camila` / `Jorge` (urbano) | Equipo | Nombres reales (y sus bios/especialidad/años al lado) |
| `Corte clásico / Fade + diseño / Afeitado a la antigua / Barba + perfilado / Combo` + precios | Servicios (lista completa, ambos estilos) | Servicios y precios reales |
| `FADE / CLASSIC / SHAVE` (solo urbano) | Categorías grandes de servicios | Palabras que calcen con lo que realmente ofrece |
| Horario (tabla `Lunes...Domingo`) | Horario | Horario real |
| `Diego R. / Felipe M. / Ignacio T.` + sus citas | Reseñas | Reseñas reales, o déjalas si no tiene |

El logo: si el cliente tiene uno, reemplaza el badge de iniciales
(`<div class="logo-badge">LN</div>` / `<div class="logo-hero">LN</div>`)
por un `<img>` con su logo. Si no tiene, se deja el badge con sus
iniciales tal cual.

## 3. Fijar el color de marca

Ambas plantillas traen un selector de color arriba (`<div
class="brand-picker">`) — es una herramienta de prueba, **no debe
quedar en la página real**:

1. Abre el archivo en el navegador y prueba los 4 colores con el cliente
   (o decide tú si no tiene preferencia).
2. Una vez elegido, copia esos 3 valores hex directo en el `:root` del
   `<style>` (`--brass` / `--brass-bright` / `--brass-dim` en clásico,
   `--accent` / `--accent-dim` en urbano), reemplazando los valores por
   defecto.
3. Borra el bloque `<div class="brand-picker">...</div>` y el `<script>`
   del selector al final del archivo (busca `ACCENTS` / ``querySelectorAll('.brand-picker button')``).

## 4. Conectar el botón de agendar

- Busca `href="#"` en los botones principales de CTA ("Agendar en
  CorteYa →", el botón flotante de celular) y cámbialo por
  `/agenda/<slug>` — el mismo link que ya usa el flujo normal de
  reservas.
- Los `href="#agendar"` (que apuntan a la sección de cierre dentro de la
  misma página) se quedan igual, no se tocan.
- Confirma que el `slug` ya exista en `barbershops` antes de publicar —
  si la barbería es nueva, primero sigue `onboarding-barberias.md`.

## 5. Publicar

- **`corteya.app/<slug>`**: sube `public/landing-<slug>.html` al repo y
  haz push — Netlify lo publica solo, no requiere nada más.
- **Dominio propio (`tubarberia.cl`)**: compra el dominio (pagado por
  CorteYa, titular a nombre de la barbería — ver
  [[corteya_pricing_strategy]]), agrégalo en Netlify → Domain
  settings → Add custom domain, configura los registros DNS que Netlify
  indique, espera el certificado SSL automático (puede tardar un rato).

## 6. Cobrar

Ver [[corteya_pricing_strategy]] para el detalle completo:

- `corteya.app/<slug>`: $100.000 CLP el primer mes, luego $12.000/mes
- Dominio propio: $130.000 CLP el primer mes, luego $14.000/mes

## Checklist final

- [ ] Estilo elegido y archivo duplicado en `public/landing-<slug>.html`
- [ ] Todos los textos de la tabla del paso 2 reemplazados
- [ ] Logo real puesto (o badge de iniciales si no tiene)
- [ ] Color de marca fijado y selector de prueba borrado del HTML
- [ ] Botones de CTA apuntando a `/agenda/<slug>` real
- [ ] Publicado (push a `public/` o dominio propio configurado y con SSL activo)
- [ ] Cobro hecho según la modalidad elegida
