# Análisis de la web

Referencia leída: cperdomo007/nota-entrega-app-v3, main, commit 25e8e99bcc1525610af8abc3c63464fcfed8d7a6 (2026-10-30). Copia local de solo consulta, sin cambios ni migraciones.

## Arquitectura y autenticación

React/Vite/TypeScript, Express, tRPC v11 con SuperJSON, Drizzle y MySQL. `server/_core/index.ts` monta /api/trpc. `server/_core/oauth.ts` intercambia código OAuth Manus, consulta usuario, upsert por openId y crea cookie de sesión JWT (un año en el callback). `context.ts` autentica mediante sdk; `trpc.ts` distingue publicProcedure y protectedProcedure. auth.me consulta usuario y auth.logout elimina la cookie. No hay login usuario/contraseña ni endpoint de tokens móviles verificable en esta referencia. No asumir compatibilidad OIDC de Manus sin validar con su proveedor.

`routers.ts` expone consultas públicas de clientes, productos, configuración, notas y seriales; escrituras protegidas. La API móvil debe exigir autenticación incluso en lecturas. JWT de cookie y token OIDC no son intercambiables. La adaptación requiere una decisión de identidad y despliegue autorizados; esta entrega solo modifica el repositorio móvil.

## Modelos

- users: id, openId único, name, email, loginMethod, role user/admin y fechas.
- clients: id, name, rif único opcional, address, phone, email, contact.
- products: id, barcode único opcional, name, description, category, price decimal(10,2), unit UN, hasSerial, stock.
- company_config: rif, businessName, dirección/contactos/logo, ivaRate decimal (16 por defecto).
- delivery_notes: número único, fecha sin hora, instantánea del cliente, subtotal, applyIVA, ivaAmount, total, observaciones, entregado/recibido.
- note_lines: noteId, productId, quantity entera, unitPrice y lineTotal decimales.
- serials: lineId y serial, unicidad por línea en BD; validación adicional por nota.
- budgets/budget_lines y price_list existen en la web y quedan fuera del alcance móvil inicial.

## Operaciones y reglas

Clientes/productos: list, search, getById, create/update/delete; configuración empresarial y fiscal; notas: listado paginado, búsqueda, siguiente número, detalle con líneas/seriales, createComplete/updateComplete/delete. Web incluye presupuestos, listas de precios, impresión/PDF y configuración.

`server/db.ts:createCompleteDeliveryNote` normaliza número/cliente/seriales, exige número/cliente y al menos una línea, rechaza número existente, cantidades no enteras o <=0, precios negativos/no finitos, productos inexistentes y serial repetido en cualquier línea. Productos hasSerial requieren tantos seriales como unidades. Calcula subtotal como suma cantidad×precio, IVA opcional con tasa por defecto 16 y total; guarda cabecera/líneas/seriales en transacción y redondea dinero a dos decimales. La fecha se conserva sin conversión UTC. No se observó descuento automático de stock en esta operación: no se agrega esa regla en el móvil.

El cliente conserva nombres camelCase y cadenas decimales. Usa centavos para estimaciones, pero el adaptador debe conservar el cálculo autoritativo y los límites SQL. Debe resolver colisiones de numeración de forma atómica: next-number solo es sugerencia. Idempotencia es un requisito nuevo del contrato móvil, no una capacidad afirmada de la web.

Fuentes principales: `drizzle/schema.ts`, `server/routers.ts`, `server/db.ts`, `server/_core/{oauth,sdk,context,trpc,index}.ts`, `client/src/pages`, `client/src/lib` y pruebas de cálculo.

El dashboard web consulta las cinco notas recientes (Home.tsx); los indicadores de conteo propuestos en el móvil requieren una agregación nueva del adaptador. NoteDetail.tsx usa window.print() para imprimir y Guardar como PDF en el navegador. El cliente Android genera el documento localmente con pdf/printing. El SDK también contempla identidades cron_ para tareas; no deben utilizarse como identidad móvil ni eludir el vínculo con usuarios humanos.
