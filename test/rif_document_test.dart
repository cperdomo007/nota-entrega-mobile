import 'package:flutter_test/flutter_test.dart';
import 'package:nota_entrega_mobile/domain/rif_document.dart';

void main() {
  // Synthetic data mirrors the two SENIAT layouts; no customer documents in git.
  test('inline legal name and multiline fiscal address', () {
    final doc = RifDocument.parse('''
N° COMPROBANTE: 202503V0000000000000
REGISTRO ÚNICO DE INFORMACIÓN FISCAL (RIF)
J123456789 EMPRESA DEMO CA
DOMICILIO FISCAL CR A3 PARCELA A4 EDIF DEMO PISO 1
INDUSTRIAL II BARQUISIMETO LARA ZONA POSTAL 3001
FECHA DE INSCRIPCIÓN: 24/05/2004
DIVISIÓN DE CONTRIBUYENTES ESPECIALES
FIRMA AUTORIZADA
''');
    expect(doc.rif, 'J123456789');
    expect(doc.name, 'EMPRESA DEMO CA');
    expect(
      doc.address,
      'CR A3 PARCELA A4 EDIF DEMO PISO 1 INDUSTRIAL II BARQUISIMETO LARA ZONA POSTAL 3001',
    );
  });
  test('separate name, spaced RIF, accented label and metadata excluded', () {
    final doc = RifDocument.parse('''
IDENTIFICACIÓN DEL CONTRIBUYENTE
RIF: j - 12.345.678 - 9
COMERCIAL DEMO, C.A.
DOMICILIO FISCAL:
AV VENEZUELA CON AV PRINCIPAL LOCAL 2
BARQUISIMETO LARA ZONA POSTAL 3001
DOCUMENTO EMITIDO ELECTRÓNICAMENTE
NO REQUIERE SELLO HÚMEDO
Condición: Contribuyente Ordinario del IVA
''');
    expect(doc.rif, 'J123456789');
    expect(doc.name, 'COMERCIAL DEMO, C.A.');
    expect(
      doc.address,
      'AV VENEZUELA CON AV PRINCIPAL LOCAL 2 BARQUISIMETO LARA ZONA POSTAL 3001',
    );
  });
  test(
    'does not invent data from partial RIF, QR link or certificate number',
    () {
      for (final text in [
        '',
        'RIF: J12345',
        'N° COMPROBANTE: 202503V0000067349011',
        'https://example.com/consulta?rif=123456789',
        'J1234567890',
      ]) {
        expect(RifDocument.parse(text).isEmpty, true);
      }
    },
  );
  test(
    'missing address remains empty; multiline company name is preserved',
    () {
      final doc = RifDocument.parse(
        'RIF: V123456789\nEMPRESA DE SERVICIOS\nDEMO C.A.\nFECHA DE VENCIMIENTO: 01/01/2030',
      );
      expect(doc.name, 'EMPRESA DE SERVICIOS DEMO C.A.');
      expect(doc.address, isEmpty);
    },
  );
}
