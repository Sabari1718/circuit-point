import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/sub_categories_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  final oldData = '''
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.folder, color: Colors.blueGrey),
  const SizedBox(),                              ],
                              ),
''';

  final newData = '''
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.folder, color: Colors.blueGrey),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                                    child: Text('\${state.products.where((p) => p.category.toLowerCase().contains(sub.name.toLowerCase())).length} Products', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                              ),
''';

  if (content.contains(oldData)) {
    content = content.replaceFirst(oldData, newData);
    file.writeAsStringSync(content);
    print('SUCCESS sub_categories_screen');
  } else {
    print('FAILED sub_categories_screen');
  }
}
