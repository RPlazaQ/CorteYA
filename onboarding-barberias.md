# Onboarding de una barbería nueva al piloto

Checklist para dar de alta una barbería después de que acepta participar.

> Para no hacerlo a mano: dale a Claude los 5 datos de la sección 0 y listo
> — el skill `onboarding-barberia` (`.claude/skills/onboarding-barberia/`)
> genera la contraseña, el SQL y el mensaje de WhatsApp. Este documento es
> el detalle de fondo y el checklist manual, por si el skill no está
> disponible o quieres hacerlo tú mismo paso a paso.

## 0. Datos que necesitas antes de sentarte a crear la cuenta

- Nombre de la barbería
- Dirección completa
- Teléfono de contacto (formato `+56 9 XXXX XXXX`)
- Correo del dueño (para su login — no tiene que ser corporativo, puede ser su Gmail)
- Un logo/foto (si no tienen, puede subirlo después él mismo desde el dashboard)

Todo lo demás (barberos, servicios, horarios) lo carga el dueño solo desde el dashboard una vez tiene acceso — no hace falta pedírselo por adelantado.

## 1. Crear su cuenta de acceso (Supabase → Authentication)

1. Entra al proyecto en Supabase → **Authentication → Users → Add user**.
2. Usa el correo del dueño y define tú una contraseña temporal (algo simple que puedas dictarle, ej. `CorteYa2026`).
3. **No uses "Send invitation"** — el correo de invitación de Supabase no siempre llega (problema conocido del plan gratis). Crea el usuario directo con contraseña ("Add user"), así no dependes de que el mail llegue.
4. Copia el **UUID** del usuario recién creado (aparece en la lista de Users al hacer clic en él).

## 2. Crear su barbería (SQL Editor)

Corre esto en el SQL Editor de Supabase, reemplazando los valores:

```sql
insert into barbershops (owner_id, name, slug, address, phone)
values (
  'UUID-DEL-USUARIO-AQUI',
  'Nombre de la Barbería',
  'nombre-de-la-barberia',
  'Dirección completa, Providencia',
  '+56 9 XXXX XXXX'
);
```

- `slug`: en minúsculas, sin tildes ni espacios (usa guiones). Va a quedar visible en su link: `corteya.app/agenda/nombre-de-la-barberia`.
- Tiene que ser único — si ya existe una barbería con ese slug, el insert falla.

## 3. Entregarle el acceso

Mándale por WhatsApp:
- El link del dashboard: `https://corteya.app/dashboard-barberia.html`
- Su correo y la contraseña temporal

Sugerido: pídele que la cambie por una propia la primera vez que entra (Supabase permite esto desde la sesión ya logueada, o se la puedes cambiar tú de nuevo en Authentication si te la pide).

## 4. Guiarlo en el dashboard (idealmente sentado contigo, la primera vez)

Una vez que inicia sesión, verá el dashboard vacío. En orden:

1. **Info** → completar dirección/teléfono si no quedaron bien, y **subir su logo**.
2. **+ Agregar barbero** por cada persona que corta ahí (incluido él mismo si corta).
3. **+ Agregar servicio** con nombre, duración y precio, por cada corte/servicio que ofrecen.
4. **Info** → para cada barbero, configurar su **horario semanal** (día por día). Sin esto, no van a aparecer horas disponibles para agendar.

## 5. Mostrarle cómo conseguir clientes

1. Botón **"🔗 Compartir agenda"** (header del dashboard) → el link que va en su Instagram/WhatsApp.
2. Botón **"🔳 QR reseñas"** → mostrárselo impreso o desde el celular, para que lo enseñe a cada cliente recién terminado el corte y sume reseñas.

## Borrar una barbería (ej. cuenta de prueba)

Orden importa: `barbershops.owner_id` referencia a `auth.users` sin cascade,
así que si borras el usuario primero, Supabase rechaza el delete por la
foreign key.

1. SQL Editor: `delete from barbershops where slug = '<slug>';` (esto
   arrastra barberos, servicios, horarios, reservas y reseñas vía cascade).
2. Recién ahí, Authentication → Users → eliminar el usuario.

## Hecho en la sesión de código del 2026-09-13

- **Campo `plan` en `barbershops`**: agregado vía `add-barbershop-plan.sql`
  (falta correrlo en el SQL Editor de Supabase — no tengo acceso admin para
  hacerlo yo). Valores: `piloto` / `barbero_independiente` / `multisucursal`
  / `local_independiente` / `inactivo`. Rodrigo lo cambia a mano por ahora;
  no hay nada que gatear todavía porque WhatsApp y prepago no existen como
  funciones reales en el producto.
- **Botón "Cambiar contraseña"** en Info → Seguridad. Ya no depende de que
  Rodrigo lo haga manualmente en Supabase.
- **Advertencia de cambios sin guardar en "Info"**: si hay horarios editados
  sin guardar, avisa antes de cambiar de pestaña o cerrar la ventana.
- **Reportes de rendimiento**: nueva vista "Reportes" con filtro de fechas —
  cortes pagados, $ recibido, reagendadas y no-shows con datos del cliente.

## Pendiente

- **Embeber el link de agenda en webs existentes de barberías** ("en caso
  de que se pueda"): algunas barberías del pipeline ya tienen su propio
  sitio (ej. CUT AR STUDIO, Gentleman's Club Barber) y podrían querer
  incrustar el agendamiento ahí en vez de solo compartir un link aparte.
  Bloqueador ya detectado: `netlify.toml` tiene `X-Frame-Options: DENY` y
  `frame-ancestors 'none'` a nivel de sitio completo, lo que impide
  cualquier iframe de terceros hoy. Antes de programar nada: definir una
  ruta específica embebible (no relajar la protección del resto del
  sitio) y decidir si se permite `frame-ancestors *` o se restringe por
  dominio — dado que cada barbería tiene su propio dominio, restringir no
  escala fácil. Si el análisis de riesgo de clickjacking no cierra bien,
  está bien concluir que por ahora se sigue solo con el botón "Compartir
  agenda" y no forzar el embed.

  **Recomendación 2026-09-13**: no construirlo todavía. Cero barberías del
  pipeline han pedido esto — son solo 2 de casi 400 que tienen sitio propio,
  y ninguna lo confirmó como interés real. Relajar `frame-ancestors` abre
  riesgo real de clickjacking en una página que pide nombre/teléfono del
  cliente, por una demanda que hoy es hipotética. Retomar esto si alguna
  barbería lo pide explícitamente — ahí sí vale la pena construir la ruta
  aislada con el análisis de riesgo bien hecho.

## 6. Checklist final antes de dejarlo solo

- [ ] Usuario creado en Supabase (Add user, no invite)
- [ ] Fila en `barbershops` con `owner_id` correcto
- [ ] Login probado (le funciona entrar)
- [ ] Al menos 1 barbero y 1 servicio cargados
- [ ] Horario semanal del barbero cargado (probar que aparezcan horas en la app cliente)
- [ ] Logo subido
- [ ] Link de agenda compartido y probado (agendar una hora de prueba)
- [ ] QR de reseñas mostrado y explicado
