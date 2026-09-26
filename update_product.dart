import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/product_details_screen.dart');
  var content = file.readAsStringSync().replaceAll('\r\n', '\n');

  content = content.replaceAll(
    '''
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
'''.trimRight(),
    '''
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          Builder(
            builder: (ctx) => ValueListenableBuilder(
              valueListenable: AppGlobals.cartNotifier,
              builder: (context, cart, _) {
                return IconButton(
                  icon: Badge(
                    isLabelVisible: cart.isNotEmpty,
                    label: Text(cart.length.toString()),
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                );
              }
            )
          ),
          const SizedBox(width: 8),
        ],
'''.trimRight()
  );

  file.writeAsStringSync(content);
}
