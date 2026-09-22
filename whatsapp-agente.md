# Agente de WhatsApp — aviso al barbero (modo prueba)

Alcance actual (decidido 2026-09-14): cuando alguien agenda una hora, el
**barbero** recibe un WhatsApp avisando. No es para el cliente todavía.

Por qué así: en modo prueba, Meta solo deja mandar mensajes a **hasta 5
números** que tú apruebes a mano. No alcanza para avisar a clientes reales
de una barbería, pero el número del barbero sí puede ser uno de esos 5 —
así que el valor real hoy es "avísame apenas me agendan una hora", no
confirmación/recordatorio al cliente. Eso queda pendiente para cuando
pasemos a número real + verificación de negocio de Meta.

## Arquitectura (ya construida, lista para conectar)

Todo el envío corre dentro de Supabase, no en el navegador:

1. Al crear una reserva (`insert` en `bookings` con `status = 'confirmed'`),
   un trigger de Postgres arma el mensaje (servicio, fecha, hora, barbero,
   nombre y teléfono del cliente) y lo manda a una función de Netlify.
2. La función de Netlify (`whatsapp-nueva-reserva.mjs`) no lee la base de
   datos — solo recibe el payload ya armado y lo reenvía a la API de
   WhatsApp (Graph API de Meta), al teléfono de la barbería (`barbershops.phone`).
3. Un secreto compartido (`X-CorteYa-Secret`) evita que cualquiera de
   afuera pueda golpear esa función y hacernos mandar WhatsApps con nuestro
   número de negocio.

Archivos: `add-whatsapp-nueva-reserva.sql` (migración), `netlify/functions/_whatsapp.mjs`
(helper), `netlify/functions/whatsapp-nueva-reserva.mjs`.

## Lo que falta — pasos manuales

### 1. Crear la app de Meta y el número de prueba
1. Entra a [developers.facebook.com](https://developers.facebook.com) con
   tu cuenta de Facebook → **Mis apps → Crear app → tipo "Negocios"**.
2. Dentro de la app, agrega el producto **WhatsApp**.
3. Esto crea automáticamente una **WABA de prueba** y te da un **número de
   prueba gratis** (no es tu chip, es un número que te presta Meta). No
   necesitas verificación de negocio para esto.
4. En **WhatsApp → Configuración de la API**, agrega como número de
   destino de prueba el **teléfono de la barbería** (el que está guardado
   en `barbershops.phone` — para Tommy's es el mismo +56930102514). Ese
   número recibe un código por WhatsApp y lo confirmas ahí mismo. Puedes
   agregar hasta 5 en total, así que hay espacio para más barberías del
   piloto.
5. Copia dos datos de esa misma pantalla: **Phone number ID** y el
   **token de acceso temporal** (dura 24h; más abajo cómo sacar uno que no
   expire).

### 2. Enviar la plantilla a aprobación
En **WhatsApp → Administrador de plantillas de mensajes → Crear plantilla**,
categoría **Utilidad**, idioma **Español**, crea esta (el orden de las
variables {{1}}..{{6}} tiene que respetarse tal cual, el código ya las manda
en ese orden):

**`nueva_reserva_barbero`**
> Nueva reserva: {{1}} el {{2}} a las {{3}} con {{4}}. Cliente: {{5}}, tel {{6}}.

La aprobación normalmente demora minutos a algunas horas — mándala a
revisión ni bien tengas la app creada, no esperes a tener todo lo demás listo.

### 3. Pasarme las credenciales (o agregarlas tú mismo)
Una vez tengas **Phone number ID** y **token**, pásamelos por chat para que
intente dejarlos en Netlify por API, o los agregas tú mismo: *Site settings
→ Environment variables → Add a variable* (scope "Functions"):
- `WHATSAPP_TOKEN`
- `WHATSAPP_PHONE_NUMBER_ID`
- `WHATSAPP_WEBHOOK_SECRET`
  (valor generado aparte, revisa Netlify → Environment variables — no se
  escribe acá porque este archivo va a un repo público. Tiene que ser
  igual al que va en Supabase, paso 4)

Nota sobre el token: el que te da la pantalla de configuración dura 24h.
Para uno que no expire, **App → Configuración básica** te deja generar un
**token de sistema permanente** asociado a un "system user" — te guío en
eso cuando lleguemos.

### 4. Correr el SQL en Supabase
1. Primero, en el SQL Editor, corre **solo esta línea**, reemplazando
   `<secreto>` por el mismo valor que pusiste en `WHATSAPP_WEBHOOK_SECRET`
   en Netlify (no se escribe el valor real acá porque este archivo va a un
   repo público):
   ```sql
   alter database postgres set app.settings.whatsapp_webhook_secret = '<secreto>';
   ```
2. Después corre completo `add-whatsapp-nueva-reserva.sql`.

### 5. Probar
Agenda una hora de prueba en `app-cliente.html` para Tommy's Barber Shop —
debería llegarle a Tomás (o a ti, si tu número es el de prueba) el aviso
por WhatsApp casi al toque.

## Pendiente para más adelante (no es de ahora)
- Confirmación y recordatorio automático **al cliente** — requiere pasar a
  número real + verificación de negocio de Meta (ver duda de iniciación de
  actividades: hacerla como persona natural con giro cuando se decida ir
  en serio con esto).
- Token de sistema permanente en vez del temporal de 24h.
- Si algún día una barbería tiene más de un barbero y se quiere avisar al
  barbero específico (no solo al teléfono general de la barbería), hay que
  agregar un campo de teléfono a `barbers` — no existe hoy.
