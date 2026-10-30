# Verificación ejecutada — 2026-10-30

Entorno local Windows: Flutter 3.47.9, Dart 3.13.7. Proyecto Android generado con `flutter create --platforms=android --org com.notaentrega --project-name nota_entrega_mobile --no-pub mobile` y ajustado para applicationId com.notaentrega.mobile, minSdk 23 y retorno OAuth.

- `flutter pub get --enforce-lockfile`: correcto; pubspec.lock versionado.
- `dart format --output=none --set-exit-if-changed lib test`: correcto tras aplicar formato con el SDK mínimo final.
- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub --coverage`: 13 pruebas aprobadas. Cobertura en coverage/lcov.info (artefacto local ignorado y publicado por CI).
- `flutter build apk --debug --no-pub --dart-define-from-file=config/env.example.json`: ejecutado localmente, falló porque no existe Android SDK (`No Android SDK found`). **No se generó un APK local.** Java tampoco está disponible en PATH.

Pruebas: 5 de transporte (Bearer, búsqueda/paginación, rechazo HTTP/host externo, 401 y sesión ausente); 6 de dominio/PDF (centavos, cantidades/seriales, duplicados, payload, HTTPS y documento multipágina con caracteres españoles); 1 de acceso protegido; 1 de creación completa con cliente/producto/serial y navegación al detalle usando un adaptador de prueba en memoria. Los dobles de prueba no forman parte del cliente de producción.

GitHub Actions instala Java/Android SDK/Flutter y ejecuta formato, análisis, pruebas y build APK debug, y publica APK/cobertura como artefactos si se completa. Consultar el resultado real de la ejecución vinculada al PR; la presencia del workflow no prueba por sí sola una compilación exitosa.

Pendiente: API/OIDC en staging, validación de identidad y permisos del servidor, datos compartidos web/móvil, idempotencia y concurrencia del adaptador, cámara y permisos en dispositivo, selector nativo para compartir, revisión visual del PDF y de pantallas, compilación/firma release. La conexión a producción no fue probada ni modificada.
