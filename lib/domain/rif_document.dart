/// Suggestions from a SENIAT document. Never treated as verified fiscal data.
class RifDocument {
  final String rif, name, address;
  const RifDocument({this.rif = '', this.name = '', this.address = ''});
  bool get isEmpty => rif.isEmpty && name.isEmpty && address.isEmpty;

  static String _plain(String text) => text
      .toUpperCase()
      .replaceAll(RegExp('[ÁÀÄ]'), 'A')
      .replaceAll(RegExp('[ÉÈË]'), 'E')
      .replaceAll(RegExp('[ÍÌÏ]'), 'I')
      .replaceAll(RegExp('[ÓÒÖ]'), 'O')
      .replaceAll(RegExp('[ÚÙÜ]'), 'U');

  static final _rif = RegExp(
    r'\b([VEJPGC])\s*[-–]?\s*(\d(?:[ .]?\d){7})\s*[-–]?\s*(\d)\b',
    caseSensitive: false,
  );
  static final _address = RegExp(r'DOMICILIO\s+FISCAL\s*:?\s*');
  static final _stop = RegExp(
    r'^(FECHA|ULTIMA ACTUALIZACION|DATOS DE REGISTRO|REGISTRO Y VIGENCIA|'
    r'N[°ºO]?\s*COMPROBANTE|DIVISION DE CONTRIBUYENTES|FIRMA|CONDICION|'
    r'LA VALIDEZ|DOCUMENTO EMITIDO|NO REQUIERE|SERVICIO NACIONAL|\d{7,}[- ])',
  );

  factory RifDocument.parse(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((l) => l.isNotEmpty)
        .toList();
    var rif = '', name = '';
    var rifIndex = -1;
    for (var i = 0; i < lines.length; i++) {
      final match = _rif.firstMatch(lines[i]);
      if (match == null) continue;
      rif =
          '${match[1]!.toUpperCase()}${match[2]!.replaceAll(RegExp(r'\D'), '')}${match[3]}';
      rifIndex = i;
      final tail = lines[i].substring(match.end).trim();
      if (tail.isNotEmpty &&
          !_stop.hasMatch(_plain(tail)) &&
          !_address.hasMatch(_plain(tail))) {
        name = tail;
      }
      break;
    }
    if (rifIndex < 0) return const RifDocument();
    final names = <String>[if (name.isNotEmpty) name];
    final addresses = <String>[];
    var inAddress = false;
    for (var i = rifIndex + (name.isEmpty ? 1 : 0); i < lines.length; i++) {
      final line = lines[i];
      final plain = _plain(line);
      final label = _address.firstMatch(plain);
      if (label != null) {
        inAddress = true;
        final tail = line.substring(label.end).trim();
        if (tail.isNotEmpty) addresses.add(tail);
        continue;
      }
      if (i == rifIndex) continue;
      if (_stop.hasMatch(plain)) {
        // Registration metadata can be a separate column before the address.
        if (inAddress) break;
        continue;
      }
      if (inAddress) {
        addresses.add(line);
      } else if (names.length < 3 &&
          !RegExp(r'^(RIF|IDENTIFICACION|REGISTRO UNICO|\d|\()')
              .hasMatch(plain)) {
        names.add(
          line.replaceFirst(
            RegExp(r'^(NOMBRE|RAZON SOCIAL)\s*:?\s*', caseSensitive: false),
            '',
          ),
        );
      }
    }
    return RifDocument(
      rif: rif,
      name: names.join(' '),
      address: addresses.join(' '),
    );
  }
}
