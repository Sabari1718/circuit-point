import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/products_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  final oldData = '''
  void _fetchData() {
    final repository = HomeRepository(
      remoteDataSource: HomeRemoteDataSourceImpl(dio: Dio()),
    );
    if (widget.categoryId != null) {
      _productsFuture = repository.getProductsByCategory(widget.categoryId!);
    } else if (widget.brandName != null) {
      _productsFuture = repository.getProducts(brand: widget.brandName, limit: 50);
    } else {
      _productsFuture = repository.getProducts(limit: 50); // General fetch
    }
  }
''';

  final newData = '''
  void _fetchData() {
    final repository = HomeRepository(
      remoteDataSource: HomeRemoteDataSourceImpl(dio: Dio()),
    );
    if (widget.subCategoryId != null) {
      _productsFuture = repository.getProductsBySubCategory(widget.subCategoryId!);
    } else if (widget.categoryId != null) {
      _productsFuture = repository.getProductsByCategory(widget.categoryId!);
    } else if (widget.brandName != null) {
      _productsFuture = repository.getProducts(brand: widget.brandName, limit: 50);
    } else {
      _productsFuture = repository.getProducts(limit: 50); // General fetch
    }
  }
''';

  if (content.contains(oldData)) {
    content = content.replaceFirst(oldData, newData);
    file.writeAsStringSync(content);
    print('SUCCESS');
  } else {
    print('FAILED to match oldData. Here is what is in the file:');
    print(content.substring(content.indexOf('void _fetchData()'), content.indexOf('void _fetchData()') + 400));
  }
}
