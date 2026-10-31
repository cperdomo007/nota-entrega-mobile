# Presupuesto y Nota de Entrega

La versión 0.3.0+5 adapta los PDF móviles a los dos ejemplos facilitados por el propietario. Los originales de clientes no se incluyen en Git. El renderizador compartido está en `lib/data/commercial_pdf.dart`, con adaptadores en `lib/data/note_pdf.dart`.

- A4, fondo blanco, tipografía Roboto incluida, logo Sumisistemas sin deformación y cabecera fiscal obtenida de la API autenticada.
- Título, número enmarcado, datos del cliente a la izquierda y cuadros RIF/fecha, atención y teléfono a la derecha. Fechas dd-MM-yyyy.
- Tabla con ítem consecutivo, descripción, cantidad, precio unitario y total. Ocho renglones como mínimo para conservar espacio de escritura.
- Sin columna Código, barcode ni ID de producto. Si un producto de una nota ya no tiene nombre, se imprime «Producto sin descripción»; no su ID. En presupuestos se usa la descripción histórica guardada.
- Seriales debajo de la descripción; textos y listas largas continúan en nuevas filas/páginas sin repetir cantidades ni importes. Cabecera y encabezados de tabla se repiten; las páginas múltiples se numeran.
- Presupuesto: observaciones y totales en paralelo, etiquetas Total Bs/TOTAL NETO Bs., sin símbolo dólar, siguiendo el ejemplo.
- Nota: observaciones a todo el ancho, totales con símbolo dólar y espacios de Entregado por/Recibido conforme.
- Se conservan los importes persistidos; no hay conversión de moneda ni recálculo fiscal en el PDF. La fila de IVA se omite cuando applyIVA es falso.

La app permite buscar, consultar y compartir los presupuestos existentes de la web. Desde 0.4.0+6 también crea presupuestos, con descripción editable y número DDMMAAAAHHMM asignado por el servidor al guardar. Los endpoints están protegidos con la misma sesión móvil; no requieren alterar el esquema de producción. El formato PDF y la omisión de códigos se conservan.

## Verificación

`flutter test --coverage` genera muestras ficticias, sin datos reales de clientes, en `build/pdf-preview/`. `python tool/verify_pdf.py` (pypdf 6.10.0) extrae el texto de esos archivos y comprueba las dos plantillas, los importes, el caso sin IVA, el caso sin descripción y la conservación de 80/500 seriales en documentos multipágina. Comprueba que Código, barcodes e IDs de las muestras no aparezcan impresos. GitHub Actions ejecuta esta verificación antes de compilar Android y publica dos muestras ficticias en el artefacto `pdf-format-previews`.

La revisión visual se hace renderizando los PDF reales generados por Flutter con Poppler. Compartir desde Android, permisos de cámara e inicio de sesión en el dispositivo requieren comprobación manual. El APK debug de cada versión está en el run de CI correspondiente; no usar un APK anterior para revisar este formato.
