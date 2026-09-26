import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/products_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  final oldData = r'_productsFuture = repository\.getProducts\(limit: 50\); // General fetch';
  final newData = '''_productsFuture = repository.getProducts(limit: 1000); // General fetch''';

  content = content.replaceFirst(RegExp(oldData), newData);
  file.writeAsStringSync(content);
  print('SUCCESS fetch size regex');
}
