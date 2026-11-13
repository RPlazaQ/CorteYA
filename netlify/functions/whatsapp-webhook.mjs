// Webhook receptor de Meta para WhatsApp — punto de entrada del
// asistente de ventas (ver prompt-whatsapp-ventas.md).
//
// GET:  handshake de verificación de Meta (hub.challenge).
// POST: procesa mensajes entrantes de leads ya registrados en
//       whatsapp_leads. El envío de la respuesta NO ocurre acá -- esta
//       función solo escribe en whatsapp_outbox; el trigger de Postgres
//       hace el envío real a Meta vía pg_net (Netlify->Meta está
//       bloqueado, ver fix-whatsapp-direct-meta.sql).
//
// MODO FLUJO FIJO: mientras no haya ANTHROPIC_API_KEY cargada (sin
// créditos todavía), "Quiero probar gratis" corre un formulario de pasos
// fijos (sin IA) y cualquier texto libre se reenvía al WhatsApp personal
// de Rodrigo. El único punto donde se activa el modelo es el `if
// (process.env.ANTHROPIC_API_KEY)` en responderTextoLibre -- el resto no
// cambia cuando se cargue la API key.
//
// Siempre responde 200 a Meta aunque algo falle adentro, para no generar
// reintentos ni que Meta baje la calidad del webhook por timeouts.

import {
  sbSelect, sbInsert, sbUpdate, normalizaTelefono, pareceAutoRespuesta, llamarCerebro, extraeAgendarLlamada,
  RODRIGO_TELEFONO, RESUMEN_CUENTAME_MAS, preguntaDelPaso, normalizaNBarberos, pareceSkipCorreo, registraPruebaGratisFormspree,
} from './_ventas.mjs';

export default async (request) => {
  const url = new URL(request.url);

  if (request.method === 'GET') {
    const mode = url.searchParams.get('hub.mode');
    const token = url.searchParams.get('hub.verify_token');
    const challenge = url.searchParams.get('hub.challenge');

    const expected = process.env.WHATSAPP_VERIFY_TOKEN;
    if (mode === 'subscribe' && expected && token === expected) {
      return new Response(challenge, { status: 200 });
    }
    return new Response('Forbidden', { status: 403 });
  }

  if (request.method === 'POST') {
    let body;
    try {
      body = await request.json();
    } catch {
      return new Response('Bad request', { status: 400 });
    }

    procesarEvento(body).catch((err) => console.error('whatsapp-webhook: error procesando evento', err));
    return new Response('EVENT_RECEIVED', { status: 200 });
  }

  return new Response('Method not allowed', { status: 405 });
};

async function procesarEvento(body) {
  for (const entry of body.entry || []) {
    for (const change of entry.changes || []) {
      for (const msg of change.value?.messages || []) {
        await procesarMensaje(msg).catch((err) => console.error('whatsapp-webhook: error con mensaje', msg.id, err));
      }
    }
  }
}

async function procesarMensaje(msg) {
  const telefono = normalizaTelefono(msg.from);
  const leads = await sbSelect(
    'whatsapp_leads',
    `telefono=eq.${encodeURIComponent(telefono)}&select=id,barberia,comuna,contacto_nombre,n_barberos,agenda_actual,dolor_principal,objecion_principal,estado,n_intentos,notas,flujo_prueba_paso`
  );
  if (!leads.length) {
    console.log('whatsapp-webhook: numero no registrado en whatsapp_leads, se ignora', telefono);
    return;
  }
  const lead = leads[0];

  const esBoton = msg.type === 'button';
  const textoIn = esBoton ? msg.button?.text || '' : msg.text?.body || '';
  if (!textoIn) return;

  await sbInsert('whatsapp_mensajes', [{ lead_id: lead.id, direction: 'in', body: textoIn, meta_message_id: msg.id }], { returning: false });

  // si está en medio del formulario de prueba gratis, esta respuesta es la
  // contestación a esa pregunta, sea botón o texto libre
  if (lead.flujo_prueba_paso) {
    await avanzarFlujoPrueba(lead, telefono, textoIn);
    return;
  }

  if (esBoton) {
    await manejarBoton(lead, textoIn, telefono);
    return;
  }

  const ultimoOut = await sbSelect(
    'whatsapp_outbox',
    `telefono=eq.${encodeURIComponent(telefono)}&status=eq.sent&order=sent_at.desc&limit=1&select=sent_at`
  );
  const elapsedMs = ultimoOut.length ? Date.now() - new Date(ultimoOut[0].sent_at).getTime() : null;
  if (pareceAutoRespuesta(textoIn, elapsedMs)) {
    console.log('whatsapp-webhook: respuesta parece auto-reply de la barbería, se espera un mensaje real', telefono);
    return;
  }

  await responderTextoLibre(lead, telefono, textoIn);
}

async function manejarBoton(lead, textoBoton, telefono) {
  const hoy = new Date().toISOString().slice(0, 10);

  if (textoBoton === 'No me interesa') {
    await sbUpdate('whatsapp_leads', `id=eq.${lead.id}`, { estado: 'No interesa', ultimo_contacto: hoy });
    await sbInsert('whatsapp_outbox', [{ telefono, kind: 'freeform', body: 'Gracias por responder. Si más adelante te interesa, aquí estamos 🙌' }], { returning: false });
    return;
  }

  if (textoBoton === 'Cuéntame más') {
    await sbUpdate('whatsapp_leads', `id=eq.${lead.id}`, { estado: 'Pidió info', ultimo_contacto: hoy, n_intentos: (lead.n_intentos || 0) + 1 });
    await sbInsert('whatsapp_outbox', [{ telefono, kind: 'freeform', body: RESUMEN_CUENTAME_MAS }], { returning: false });
    return;
  }

  if (textoBoton === 'Quiero probar gratis') {
    await sbUpdate('whatsapp_leads', `id=eq.${lead.id}`, { estado: 'Pidió info', ultimo_contacto: hoy, n_intentos: (lead.n_intentos || 0) + 1, flujo_prueba_paso: 'nombre' });
    await sbInsert('whatsapp_outbox', [{ telefono, kind: 'freeform', body: preguntaDelPaso('nombre') }], { returning: false });
    return;
  }

  // botón no reconocido (no debería pasar, los 3 son los únicos de la plantilla)
  await responderTextoLibre(lead, telefono, textoBoton);
}

// -------- formulario de pasos fijos de "Quiero probar gratis" --------
async function avanzarFlujoPrueba(lead, telefono, texto) {
  const paso = lead.flujo_prueba_paso;

  if (paso === 'nombre') {
    await sbUpdate('whatsapp_leads', `id=eq.${lead.id}`, { barberia: texto.trim(), flujo_prueba_paso: 'comuna' });
    await sbInsert('whatsapp_outbox', [{ telefono, kind: 'freeform', body: preguntaDelPaso('comuna') }], { returning: false });
    return;
  }

  if (paso === 'comuna') {
    await sbUpdate('whatsapp_leads', `id=eq.${lead.id}`, { comuna: texto.trim(), flujo_prueba_paso: 'n_barberos' });
    await sbInsert('whatsapp_outbox', [{ telefono, kind: 'freeform', body: preguntaDelPaso('n_barberos') }], { returning: false });
    return;
  }

  if (paso === 'n_barberos') {
    const normalizado = normalizaNBarberos(texto);
    const patch = { flujo_prueba_paso: 'correo' };
    if (normalizado) patch.n_barberos = normalizado;
    else patch.notas = `N° barberos (respuesta libre): ${texto.trim()}`;
    await sbUpdate('whatsapp_leads', `id=eq.${lead.id}`, patch);
    await sbInsert('whatsapp_outbox', [{ telefono, kind: 'freeform', body: preguntaDelPaso('correo') }], { returning: false });
    return;
  }

  if (paso === 'correo') {
    const correo = pareceSkipCorreo(texto) ? null : texto.trim();
    const hoy = new Date().toISOString().slice(0, 10);

    const [leadFresco] = await sbSelect('whatsapp_leads', `id=eq.${lead.id}&select=barberia,comuna,n_barberos`);

    await registraPruebaGratisFormspree({
      nombreBarberia: leadFresco?.barberia || lead.barberia,
      comuna: leadFresco?.comuna || lead.comuna,
      telefonoCompleto: telefono,
      cantidadBarberos: leadFresco?.n_barberos || '',
      correo,
    });

    await sbUpdate('whatsapp_leads', `id=eq.${lead.id}`, {
      estado: 'Prueba agendada',
      fecha_1er_contacto: lead.fecha_1er_contacto || hoy,
      ultimo_contacto: hoy,
      flujo_prueba_paso: null,
      proximo_paso: 'Activar cuenta',
      fecha_proximo_paso: hoy,
    });
    await sbInsert('whatsapp_outbox', [{ telefono, kind: 'freeform', body: '¡Listo! Te contactamos por WhatsApp en menos de 24 horas para activar tu cuenta. 🙌' }], { returning: false });
  }
}

// -------- texto libre fuera de cualquier flujo --------
async function responderTextoLibre(lead, telefono, texto) {
  if (process.env.ANTHROPIC_API_KEY) {
    await responderConCerebro(lead, telefono);
    return;
  }

  // modo flujo fijo: sin créditos, se reenvía a Rodrigo en vez de generar respuesta
  const hoy = new Date().toISOString().slice(0, 10);
  await sbUpdate('whatsapp_leads', `id=eq.${lead.id}`, { estado: 'Pidió info', ultimo_contacto: hoy, n_intentos: (lead.n_intentos || 0) + 1 });
  await sbInsert('whatsapp_outbox', [{
    telefono: RODRIGO_TELEFONO,
    kind: 'freeform',
    body: `📩 ${lead.barberia} (${telefono}) escribió:\n"${texto}"`,
  }], { returning: false });
}

async function responderConCerebro(lead, telefono) {
  const historial = await sbSelect('whatsapp_mensajes', `lead_id=eq.${lead.id}&order=created_at.asc&limit=20&select=direction,body`);
  const mensajes = historial.map((m) => ({ role: m.direction === 'in' ? 'user' : 'assistant', content: m.body }));

  const contexto = `Datos conocidos de esta barbería: nombre "${lead.barberia}", comuna ${lead.comuna || 'desconocida'}, n° barberos ${lead.n_barberos || 'desconocido'}, agenda actual ${lead.agenda_actual || 'desconocida'}.`;

  const respuesta = await llamarCerebro(mensajes, contexto);
  const { visible, agendarLlamada } = extraeAgendarLlamada(respuesta);

  await sbInsert('whatsapp_outbox', [{ telefono, kind: 'freeform', body: visible }], { returning: false });
  await sbInsert('whatsapp_mensajes', [{ lead_id: lead.id, direction: 'out', body: visible }], { returning: false });

  if (agendarLlamada) {
    await sbInsert('whatsapp_llamadas_agendadas', [{ lead_id: lead.id, fecha_hora: null, motivo: agendarLlamada.motivo, resumen: agendarLlamada.resumen }], { returning: false });
    await sbUpdate('whatsapp_leads', `id=eq.${lead.id}`, { proximo_paso: 'Llamada Rodri', notas: agendarLlamada.resumen });
    await sbInsert('whatsapp_outbox', [{
      telefono: RODRIGO_TELEFONO,
      kind: 'template',
      template_name: 'aviso_llamada_rodri',
      template_params: [lead.barberia, lead.comuna || '-', lead.contacto_nombre || '-', telefono, 'por coordinar con Rodrigo', agendarLlamada.motivo, agendarLlamada.resumen],
    }], { returning: false });
  }
}
