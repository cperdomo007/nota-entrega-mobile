# API móvil v1 implementada

Código en `backend/src/`. Base HTTPS `/api/mobile/v1/`; MySQL solo en el servidor. Datos JSON camelCase, precios como strings decimales y fechas YYYY-MM-DD. No envolver en SuperJSON/tRPC.

## Autenticación

- POST `auth/login`: `{email,password}` → `{accessToken,refreshToken,expiresIn:900,user:{id,email,name,role}}`.
- POST `auth/refresh`: `{refreshToken}` → misma estructura, rotando access/refresh; los anteriores dejan de funcionar.
- POST `auth/logout`: `{refreshToken}` → 204, revoca la sesión. Es idempotente.
- GET `auth/me`: requiere Bearer → `{user}`.

Las cuentas residen en `mobile_users`, separadas de `users` OAuth de la web. Contraseñas de 12–128 caracteres al crearlas; scrypt N=32768,r=8,p=3, salt aleatorio de 16 bytes. Tokens opacos de 32 bytes aleatorios; solo hashes SHA-256 en `mobile_sessions`. Cinco fallos por cuenta bloquean 15 minutos. Respuestas de login uniformes sin revelar si existe la cuenta. Rate limiting por IP (una réplica); bloqueo de cuenta persistente entre réplicas.

Todas las rutas siguientes requieren `Authorization: Bearer <accessToken>`. Se comprueba usuario activo y expiración en cada solicitud, sin reutilizar cookies web.

| Método/ruta | Respuesta |
| --- | --- |
| GET dashboard | `{clients,products,notes}` conteos reales |
| GET clients?q=&limit=50&offset=0 | `{items:[{id,name,rif,address,phone,email,contact}]}` |
| GET products?q=&limit=50&offset=0 | `{items:[{id,name,barcode,description,category,price,unit,hasSerial,stock}]}` |
| GET notes?q=&limit=50&offset=0 | `{items:[{id,noteNumber,noteDate,clientName,subtotal,ivaAmount,total,applyIVA}]}` |
| GET config | `{businessName,ivaRate}` |
| GET notes/next-number | `{noteNumber}` vista previa DDMMAAAAHHMM, no reserva |
| GET budgets/next-number | `{budgetNumber}` vista previa DDMMAAAAHHMM, no reserva |
| GET notes/:id | Cabecera, companyName, company y lines con productName/serials como strings |
| GET budgets?q=&limit=50&offset=0 | `{items:[{id,budgetNumber,budgetDate,clientName,subtotal,ivaAmount,total,applyIVA}]}` |
| GET budgets/:id | Cabecera, company y lines con description persistida, quantity, unitPrice y lineTotal |
| POST notes | 201 `{id,noteNumber?}` |
| POST budgets | 201 `{id,budgetNumber?}`; cabecera fiscal y líneas con descripción histórica |
| POST clients | 201 `{id}`; name obligatorio, rif/address/phone/email/contact opcionales |
| POST products | 201 `{id}`; name/price/unit, barcode/description/category opcionales, hasSerial y stock |
| GET users | Solo admin; `{items:[{id,email,name,role,active}]}` paginado |
| POST users | Solo admin; `{email,name,password,role}` → 201 usuario sin hash |
| PATCH users/:id | Solo admin; `{active:boolean}` → 204; desactivar revoca sesiones |

No se permite desactivar la propia cuenta. No hay endpoint público de registro. Para crear el primer administrador se usa el comando del servidor documentado en RAILWAY.md.

`company` contiene `{businessName,rif,address,phone1,phone2,email,website}` de `company_config` para la cabecera fiscal de los PDF. No contiene credenciales SQL. Presupuestos consulta y crea en `budgets`/`budget_lines`; no hay PATCH/DELETE ni migraciones nuevas. Se conserva la descripción histórica incluso si la línea no tiene producto asociado. Los IDs siguen en JSON para relacionar datos; Flutter no los imprime como descripción ni muestra una columna de código en los PDF.

Búsqueda por nombre/RIF, nombre/código y número/cliente. Limit 1–50, offset>=0, orden id descendente; comodines escapados. hasSerial/applyIVA booleanos; datos de la misma empresa compartidos para todas las cuentas activas.

Los POST notes/budgets/clients/products exigen `Idempotency-Key` (24–96 caracteres A–Z, a–z, dígitos, _ y -). Las altas se ejecutan con la sesión móvil activa y se confirman con su registro idempotente en la misma transacción. Producto: precio >0, máximo 99999999.99; stock inicial entero no negativo; códigos/RIF vacíos se guardan NULL. Duplicados de código/RIF devuelven 409 con code CATALOG_DUPLICATE. Ejemplo de nota:

```json
{"noteDate":"2026-10-30","clientName":"Cliente","clientRif":"J-1","clientAddress":"","clientPhone":"","clientContact":"","applyIVA":true,"ivaRate":"16.00","observations":"","deliveredBy":"","receivedBy":"","lines":[{"productId":1,"quantity":1,"unitPrice":"100.25","serials":["ABC"]}]}
```

Valida productos existentes, cantidades enteras, precios/rangos, fecha válida y seriales; serial único dentro de la nota y uno por unidad para hasSerial. La tasa se lee de company_config y se recalculan subtotal, IVA y total en centavos. Una tasa cliente desactualizada devuelve 409. Nota, líneas, seriales y respuesta idempotente se confirman en una misma transacción. Misma clave/usuario/cuerpo devuelve el mismo id; otro cuerpo con esa clave devuelve 409. Número único validado por BD; no sobrescribe notas existentes. No hay reintento automático de POST.

POST budgets usa budgetDate y la misma cabecera de cliente/IVA/observaciones. Sus líneas tienen productId opcional/null, description obligatoria, quantity y unitPrice. No se requieren seriales para cotizar. Guarda descripción y totales en transacción y obtiene IVA del servidor.

Numeración: el servidor asigna DDMMAAAAHHMM al guardar, usando DOCUMENT_TIME_ZONE=America/Caracas por defecto; independiente del reloj del teléfono o del contenedor. El campo noteNumber se acepta por compatibilidad con APKs anteriores, pero no decide el número persistido. Un duplicado dentro del mismo minuto y tipo devuelve 409 con code DOCUMENT_NUMBER_EXISTS; rollback completo y reintento al minuto siguiente. Notas y presupuestos tienen unicidad independiente, como en la web. No se agregan segundos/sufijos ni se altera el historial.

Se reutiliza mobile_note_requests sin cambios de esquema. Claves de notas conservan el formato previo; las de catálogo/presupuesto se guardan como clients:/products:/budgets: + SHA-256 de la clave. Los dos puntos no están permitidos en claves externas, evitando colisiones entre tipos. En esos registros, la columna heredada noteId almacena el ID de la entidad creada; no tiene FK a delivery_notes. No agregar esa FK sin migrar primero el ledger a un esquema genérico. Los hashes no contienen datos de clientes en claro.

Errores: 400 JSON inválido, 401 credenciales/sesión, 403 permisos, 404 ausente, 409 conflicto, 413 cuerpo grande, 422 validación, 426 HTTPS, 429 límite, 5xx error. SQL y credenciales nunca se devuelven. TLS termina en Railway; un proxy de ingreso confiable. /health solo responde disponibilidad de BD; no expone información del esquema.

Despliegue autorizado: https://nota-entrega-mobile-production.up.railway.app/api/mobile/v1/ . La API es pública por HTTPS, las rutas de datos requieren sesión y API→MySQL usa red privada. No se habilitó HTTP ni conexión MySQL en Flutter.
