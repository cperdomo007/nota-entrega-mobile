typedef Json = Map<String, dynamic>;

int cents(Object? value) {
  final text = '$value';
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
    throw const FormatException('Importe inválido');
  }
  final parts = text.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
}

String money(int value) => (value / 100).toStringAsFixed(2);

class Client {
  final int id;
  final String name, rif, address, phone, contact;
  const Client(
    this.id,
    this.name,
    this.rif,
    this.address,
    this.phone,
    this.contact,
  );
  factory Client.fromJson(Json j) => Client(
    j['id'] as int,
    j['name'] as String,
    j['rif'] as String? ?? '',
    j['address'] as String? ?? '',
    j['phone'] as String? ?? '',
    j['contact'] as String? ?? '',
  );
}

class Product {
  final int id, priceCents;
  final String name, barcode, unit;
  final bool hasSerial;
  const Product(
    this.id,
    this.name,
    this.priceCents,
    this.barcode,
    this.unit,
    this.hasSerial,
  );
  factory Product.fromJson(Json j) => Product(
    j['id'] as int,
    j['name'] as String,
    cents(j['price']),
    j['barcode'] as String? ?? '',
    j['unit'] as String? ?? 'UN',
    j['hasSerial'] == true,
  );
}

class DraftLine {
  final Product product;
  final int quantity, priceCents;
  final List<String> serials;
  final String description;
  DraftLine(
    this.product,
    this.quantity,
    this.priceCents,
    List<String> serials, {
    String? description,
  }) : description = description ?? product.name,
       serials = List.unmodifiable(
         serials.map((s) => s.trim()).where((s) => s.isNotEmpty),
       );
  int get total => quantity * priceCents;
  Json toJson() => {
    'productId': product.id,
    'quantity': quantity,
    'unitPrice': money(priceCents),
    'serials': serials,
  };
}

String? validateLines(List<DraftLine> lines) {
  if (lines.isEmpty) return 'Agrega al menos un producto';
  final seen = <String>{};
  for (final line in lines) {
    if (line.quantity <= 0 || line.priceCents < 0) {
      return 'Cantidad o precio inválido';
    }
    if (line.product.hasSerial && line.serials.length != line.quantity) {
      return '${line.product.name}: se requiere un serial por unidad';
    }
    for (final serial in line.serials) {
      if (serial.length > 255) return 'Serial demasiado largo';
      if (!seen.add(serial)) return 'Serial duplicado: $serial';
    }
  }
  return null;
}

class DeliveryNote {
  final Json data;
  DeliveryNote(this.data);
  int get id => data['id'] as int;
  String get number => data['noteNumber'] as String;
  String get client => data['clientName'] as String;
  List<Json> get lines => (data['lines'] as List? ?? []).cast<Json>();
}

class Budget {
  final Json data;
  Budget(this.data);
  int get id => data['id'] as int;
  String get number => data['budgetNumber'] as String;
  String get client => data['clientName'] as String;
  List<Json> get lines => (data['lines'] as List? ?? []).cast<Json>();
}
