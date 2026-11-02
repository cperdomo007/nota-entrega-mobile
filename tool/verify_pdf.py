"""Verify text from the actual Flutter PDF renderer, not a parallel template."""
from pathlib import Path
from pypdf import PdfReader

folder = Path('build/pdf-preview')
documents = {}
for path in folder.glob('*.pdf'):
    reader = PdfReader(path)
    text = '\n'.join(page.extract_text() for page in reader.pages)
    assert 'Código' not in text and 'SKU-NEVER-PRINT' not in text, path
    assert '987654321' not in text and '987654322' not in text, path
    assert 'Datos del Cliente' in text and 'Descripción' in text, path
    assert all(abs(float(page.mediabox.width) - 595.28) < 1 for page in reader.pages), path
    assert all(abs(float(page.mediabox.height) - 841.89) < 1 for page in reader.pages), path
    documents[path.stem] = (reader, text)

assert len(documents) == 6, documents.keys()
for kind in ('nota-entrega', 'presupuesto'):
    reader, text = documents[kind]
    assert len(reader.pages) == 1, kind
    assert '368.30' in text and '50.80' in text and '317.50' in text, kind
    assert 'J-00000000-0' in text and 'J-11111111-1' in text, kind
    assert 'ventas@example.com' in text and 'Avenida Principal' in text, kind

assert 'NOTA DE ENTREGA' in documents['nota-entrega'][1]
assert '30-10-2026' in documents['nota-entrega'][1]
assert 'Entregado por' in documents['nota-entrega'][1]
assert 'Recibido conforme' in documents['nota-entrega'][1]
assert 'SERIAL-EJEMPLO-001' in documents['nota-entrega'][1]
assert '$368.30' in documents['nota-entrega'][1]
assert 'PRESUPUESTO' in documents['presupuesto'][1]
assert '28-10-2026' in documents['presupuesto'][1]
assert 'TOTAL NETO Bs.' in documents['presupuesto'][1]
assert '$' not in documents['presupuesto'][1]
assert 'Recibido conforme' not in documents['presupuesto'][1]
assert 'IVA' not in documents['sin-iva'][1]
assert 'Producto sin descripción' in documents['sin-descripcion'][1]
for kind in ('multipagina', 'seriales-largos'):
    assert len(documents[kind][0].pages) > 1, kind
    assert 'Página' in documents[kind][1], kind
assert all(f'SERIAL-PRUEBA-{i}' in documents['multipagina'][1] for i in range(1, 81))
assert all(f'SERIAL-LARGO-{i}' in documents['seriales-largos'][1] for i in range(1, 501))
print('PDF: 6 documentos verificados; formatos, importes, seriales y códigos omitidos.')
