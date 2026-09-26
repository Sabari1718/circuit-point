import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/sub_categories_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  final badCode = '''
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: Text('\$prodCount Products', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
''';

  content = content.replaceFirst(badCode, 'const SizedBox(),');
  file.writeAsStringSync(content);
}
