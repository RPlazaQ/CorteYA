# Agente de WhatsApp (confirmación + recordatorio) — modo prueba

Alcance: solo mensajes automáticos de una vía (confirmación al agendar +
recordatorio ~1h antes). No es un bot conversacional — el cliente no puede
responderle y que pase algo.

En modo prueba, Meta solo deja mandar mensajes a **hasta 5 números** que tú
apruebes a mano (cada uno recibe un código y lo confirma). No sirve para los
clientes reales de una barbería todavía — sirve para probar que todo el
flujo (reserva → WhatsApp) funciona de punta a punta. Pasar a producción
real (clientes de verdad) requiere verificación de negocio de Meta más
adelante — ver `onboarding-barberias.md` / memoria de notificaciones.

## Arquitectura (ya construida, lista para conectar)

Todo el envío corre dentro de Supabase, no en el navegador:

1. Al crear una reserva (`insert` en `bookings`), un trigger de Postgres
   arma el mensaje y lo manda a una función de Netlify.
2. Cada 15 minutos, `pg_cron` revisa reservas que empiezan en 60-75 min y
   manda el recordatorio de la misma forma.
3. Las funciones de Netlify (`netlify/functions/whatsapp-confirmacion.mjs`,
   `whatsapp-recordatorio.mjs`) no leen la base de datos — solo reciben el
   payload ya armado y lo reenvían a la API de WhatsApp (Graph API de Meta).
4. Un secreto compartido (`X-CorteYa-Secret`) evita que cualquiera de
   afuera pueda golpear esas funciones y hacernos mandar WhatsApps con nuestro
   número de negocio.

Archivos: `add-whatsapp-recordatorios.sql` (migración), `netlify/functions/_whatsapp.mjs`
(helper), `whatsapp-confirmacion.mjs`, `whatsapp-recordatorio.mjs`.

## Lo que falta — pasos manuales de mañana

### 1. Crear la app de Meta y el número de prueba
1. Entra a [developers.facebook.com](https://developers.facebook.com) con
   tu cuenta de Facebook → **Mis apps → Crear app → tipo "Negocios"**.
2. Dentro de la app, agrega el producto **WhatsApp**.
3. Esto crea automáticamente una **WABA de prueba** y te da un **número de
   prueba gratis** (no es tu chip, es un número que te presta Meta). No
   necesitas verificación de negocio para esto.
4. En **WhatsApp → Configuración de la API**, agrega hasta 5 números de
   destino (tu celular real + los que quieras probar) — cada uno recibe un
   código por WhatsApp y lo confirmas ahí mismo.
5. Copia dos datos de esa misma pantalla: **Phone number ID** y el
   **token de acceso temporal** (dura 24h; más abajo cómo sacar uno que no
   expire).

### 2. Enviar las plantillas a aprobación (esto demora, hazlo apenas puedas)
En **WhatsApp → Administrador de plantillas de mensajes → Crear plantilla**,
categoría **Utilidad**, idioma **Español**, crea estas dos (el orden de las
variables {{1}}..{{6}} tiene que respetarse tal cual, el código ya las manda
en ese orden):

**`confirmacion_reserva`**
> Hola {{1}}! Tu hora en {{2}} quedó confirmada: {{3}} el {{4}} a las {{5}} con {{6}}. Cualquier cambio, contáctanos.

**`recordatorio_reserva`**
> Hola {{1}}! Te recordamos tu hora en {{2}}: {{3}} hoy {{4}} a las {{5}} con {{6}}. ¡Te esperamos!

La aprobación normalmente demora minutos a algunas horas, a veces más —
mándalas a revisión ni bien tengas la app creada, no esperes a tener todo
lo demás listo.

### 3. Pasarme las credenciales
Una vez tengas **Phone number ID** y **token**, pásamelos por chat. Yo no
pude dejarlos configurados de una porque esta sesión bloqueó automáticamente
la llamada a la API de Netlify que agrega variables de entorno (protección
del propio entorno, no fue un rechazo tuyo) — así que hay dos caminos:

- **Me los pasas y reintento** la llamada a la API de Netlify (puede que
  simplemente pidiéndolo de nuevo en otro momento ya no se bloquee), o
- **Los agregas tú mismo** en Netlify: *Site settings → Environment
  variables → Add a variable*, con estas 3 claves (scope "Functions"):
  - `WHATSAPP_TOKEN`
  - `WHATSAPP_PHONE_NUMBER_ID`
  - `WHATSAPP_WEBHOOK_SECRET` = `736503a901225649d1be6bf1adefc66d2791ae5a3206b316`
    (ya generado, no lo cambies — tiene que ser igual al que va en Supabase, paso 4)

Nota sobre el token: el que te da la pantalla de configuración dura 24h.
Para uno que no expire (necesario si esto va a quedar corriendo más de un
día): **App → Configuración básica** te deja generar un **token de sistema
permanente** asociado a un "system user" — te guío en eso cuando lleguemos.

### 4. Correr el SQL en Supabase
1. Primero, en el SQL Editor, corre **solo esta línea** (con el secreto
   real, no la subo a git):
   ```sql
   alter database postgres set app.settings.whatsapp_webhook_secret = '736503a901225649d1be6bf1adefc66d2791ae5a3206b316';
   ```
2. Después corre completo `add-whatsapp-recordatorios.sql`.

### 5. Probar
1. Agenda una hora de prueba en `app-cliente.html` usando como teléfono uno
   de los 5 números que aprobaste en el paso 1 — debería llegarte la
   confirmación por WhatsApp casi al toque.
2. Para el recordatorio sin esperar la hora real, se puede simular
   llamando manualmente `select send_whatsapp_recordatorios();` en el SQL
   Editor después de insertar una reserva de prueba con `booking_date`/`start_time`
   cayendo dentro de la ventana de 60-75 min desde ahora.

## Pendiente para más adelante (no es de mañana)
- Pasar a número real + verificación de negocio de Meta para que esto
  llegue a clientes reales de las barberías (ver duda de iniciación de
  actividades, ya resuelta: hacerla como persona natural con giro cuando
  se decida ir en serio con esto).
- Token de sistema permanente en vez del temporal de 24h.
