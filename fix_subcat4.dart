import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/sub_categories_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  // Replace everything between `const Icon(Icons.folder, color: Colors.blueGrey),` and `],`
  final pattern = RegExp(r'const Icon\(Icons\.folder, color: Colors\.blueGrey\),[\s\S]*?\],');
  
  final newData = '''const Icon(Icons.folder, color: Colors.blueGrey),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                                    child: Text('\${state.products.where((p) => p.category.toLowerCase().contains(sub.name.toLowerCase())).length} Products', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],''';

  content = content.replaceFirst(pattern, newData);
  file.writeAsStringSync(content);
  print('SUCCESS regex');
}
