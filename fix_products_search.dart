import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/products_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  // Fix 1: Add search parameter to getProducts
  final oldFetch = '''      } else {
        _productsFuture = repository.getProducts(limit: 1000); // General fetch
      }''';
  final newFetch = '''      } else {
        final isSearch = widget.title != 'All Products' && widget.title.isNotEmpty;
        _productsFuture = repository.getProducts(
          limit: 24, 
          search: isSearch ? widget.title : null
        ); 
      }''';

  if (content.contains(oldFetch)) {
    content = content.replaceFirst(oldFetch, newFetch);
    print('Replaced fetch');
  } else {
    print('Failed to replace fetch');
  }

  // Fix 2: Remove the local filtering logic that was used for title
  final oldFilter = '''      } else if (widget.subCategoryId == null && widget.categoryId == null && widget.title != 'All Products' && widget.title.isNotEmpty) {
        filtered = filtered.where((p) => p.category.toLowerCase().contains(widget.title.toLowerCase())).toList();
      }''';
  
  if (content.contains(oldFilter)) {
    content = content.replaceFirst(oldFilter, '');
    print('Removed local filter');
  } else {
    print('Failed to remove local filter');
  }

  file.writeAsStringSync(content);
}
