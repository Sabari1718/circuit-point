import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/categories_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  final oldData = '''
                        final subCatCount = state.subSectors.where((s) => s.sectorId == sector.id).length;
                        
                        return Container(
''';

  final newData = '''
                        final subCatCount = state.subSectors.where((s) => s.sectorId == sector.id).length;
                        final subCatNames = state.subSectors.where((s) => s.sectorId == sector.id).map((s) => s.name.toLowerCase()).toList();
                        final prodCount = state.products.where((p) => subCatNames.contains(p.category.toLowerCase()) || p.category.toLowerCase().contains(sector.name.toLowerCase())).length;
                        
                        return Container(
''';

  final oldData2 = '''
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text('\$subCatCount Sub-Categories', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                            ),
''';

  final newData2 = '''
                            Row(
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text('\$subCatCount Sub-Categories', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                                ),
                              ],
                            ),
''';

  // Wait, I need the green pill at the top right of the card too, exactly like the UI mockup!
  // In the UI mockup: The green pill "113 Products" is at the top right, NEXT to the red folder icon!
  // Let me look at the code for the red folder icon!
  
  if (content.contains(oldData)) {
    content = content.replaceFirst(oldData, newData);
    file.writeAsStringSync(content);
    print('SUCCESS 1');
  } else {
    print('FAILED 1');
  }
}
