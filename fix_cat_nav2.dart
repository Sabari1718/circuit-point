import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/categories_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  final oldData = r'''Navigator\.push\(context, MaterialPageRoute\(builder: \(\_\) => SubCategoriesScreen\(sector: sector\)\)\);''';
  final newData = '''if (subCatCount == 0) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(title: sector.name, categoryId: sector.id)));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => SubCategoriesScreen(sector: sector)));
                                  }''';

  content = content.replaceFirst(RegExp(oldData), newData);
  file.writeAsStringSync(content);
  print('SUCCESS cat nav regex');
}
