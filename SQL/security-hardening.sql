-- Refuerzo de seguridad para bookings: límites de longitud a nivel de base de datos.
-- El maxlength del formulario HTML es solo cosmético (cualquiera puede llamar la API
-- directo, como ya probamos con curl), así que la validación real tiene que vivir acá.

alter table bookings
  add constraint customer_name_length check (char_length(customer_name) between 1 and 80);

alter table bookings
  add constraint customer_email_length check (customer_email is null or char_length(customer_email) <= 120);
