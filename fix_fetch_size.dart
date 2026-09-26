import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/products_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  final oldData = '''
      } else {
        _productsFuture = repository.getProducts(limit: 50); // General fetch
      }
''';

  final newData = '''
      } else {
        _productsFuture = repository.getProducts(limit: 1000); // Increased limit so local title-based category filters work
      }
''';

  if (content.contains(oldData)) {
    content = content.replaceFirst(oldData, newData);
    file.writeAsStringSync(content);
    print('SUCCESS fetch size');
  } else {
    print('FAILED fetch size');
  }
}
