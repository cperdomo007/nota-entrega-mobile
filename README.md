# Nota Entrega Mobile

Cliente Android Flutter/Dart con Material 3, Riverpod, GoRouter y Dio.

## Estado de la integración

La web de referencia usa OAuth Manus y tRPC con cookie. **No existe todavía el adaptador REST/OIDC que este cliente necesita.** No apuntar API_BASE_URL directamente a /api/trpc. Las pantallas y operaciones están implementadas contra el contrato propuesto en docs/API.md; el acceso con datos compartidos requiere implementar y aprobar ese adaptador en staging. No se modificó el repositorio web ni la base de producción. No hay conexión MySQL, credenciales de BD, cuentas de demostración ni un bypass de autenticación en Flutter.

## Ejecutar

1. Instalar Flutter 3.47.9 (Dart 3.13.7) y Android SDK/JDK 17.
2. `flutter pub get`
3. Copiar `config/env.example.json` a `config/env.local.json` y configurar un proveedor OIDC y API de staging aprobados.
4. `flutter run --dart-define-from-file=config/env.local.json`
5. `flutter analyze`, `flutter test`, `flutter build apk --debug --dart-define-from-file=config/env.local.json`

Variables públicas compiladas en la app (no son secretos):

| Variable | Uso |
| --- | --- |
| API_BASE_URL | HTTPS, base del adaptador, con barra final `/api/mobile/v1/` |
| OIDC_ISSUER | Emisor HTTPS con discovery OIDC y PKCE S256 |
| OIDC_CLIENT_ID | ID de cliente público Android, sin client_secret |

Registrar exactamente `com.notaentrega.mobile:/oauthredirect` en el proveedor. Android usa el esquema `com.notaentrega.mobile`. Los access tokens viven en memoria; refresh tokens en almacenamiento seguro Android. Al iniciar se intenta renovar; ante 401 se cierra la sesión. Al vencer el access token durante el uso se solicita nuevo acceso, sin reintentar escrituras automáticamente. Cerrar sesión elimina tokens locales; la sesión del navegador/proveedor puede persistir. No se registra tráfico ni tokens. Android prohíbe tráfico HTTP, respaldos y restauración de credenciales.

## Funcionalidades

- Inicio de sesión en navegador del sistema mediante OAuth/OIDC PKCE.
- Dashboard con indicadores del servidor.
- Clientes, productos y notas con búsqueda explícita, paginación, errores y reintento.
- Creación: selección de cliente/productos, fecha, número, cantidades, precios, IVA, observaciones y responsables.
- Seriales manuales y mediante cámara; búsqueda de producto por código escaneado.
- Detalle y PDF A4 multipágina compartido por el selector nativo.

Los totales locales son una estimación; el servidor recalcula los definitivos. Las escrituras usan Idempotency-Key y no se repiten automáticamente. Conservar el mismo formulario al reintentar una respuesta incierta. No cambiar sus datos tras un timeout hasta resolver el resultado con el servidor. Sin soporte offline ni cola de escrituras.

## Estructura

`lib/core`: configuración y sesión. `lib/data`: API y PDF. `lib/domain`: modelos y validación. `lib/ui`: pantallas y cámara. `android`: proyecto nativo. `test`: reglas, PDF y acceso. `docs`: análisis web, contrato y verificación. `.github/workflows/android.yml`: análisis, pruebas y APK debug de CI.

## Pendientes

Implementación autorizada del adaptador, registro OAuth Android e integración en staging; permisos/roles y pruebas de extremo a extremo con datos de prueba; revisión visual y cámara/compartir en dispositivo; logo corporativo y revisión del formato PDF; firma release y distribución. Ver docs/VALIDATION.md para las verificaciones realmente ejecutadas.
