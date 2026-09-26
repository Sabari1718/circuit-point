import 'dart:io';

void main() {
  final file = File('lib/features/home/data/repositories/home_repository.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  final oldData = '''
  Future<List<ProductModel>> getProductsByCategory(int categoryId) {
    return remoteDataSource.getProductsByCategory(categoryId);
  }
''';

  final newData = '''
  Future<List<ProductModel>> getProductsBySubCategory(int subCategoryId) {
    return remoteDataSource.getProductsBySubCategory(subCategoryId);
  }

  Future<List<ProductModel>> getProductsByCategory(int categoryId) {
    return remoteDataSource.getProductsByCategory(categoryId);
  }
''';

  if (content.contains(oldData)) {
    content = content.replaceFirst(oldData, newData);
    file.writeAsStringSync(content);
    print('SUCCESS');
  } else {
    print('FAILED to match oldData.');
  }
}
