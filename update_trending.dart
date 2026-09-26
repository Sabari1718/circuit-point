import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/home_screen.dart');
  var content = file.readAsStringSync().replaceAll('\r\n', '\n');

  // Replace Search Box
  content = content.replaceAll(
    '''
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search products, brands, categories, sensors...',
                  hintStyle: TextStyle(fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
'''.trimRight(),
    '''
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(75.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 20.0),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Icon(Icons.search, color: Color(0xFFD32F2F), size: 24),
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search sensors, modules, dev boards...',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFFF5252)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
'''.trimRight()
  );

  // Replace Circular Categories with Pill Tabs
  content = content.replaceAll(
    '''
            // 2. Circular Categories
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  'Sensors', 'Dev Boards', 'Arduino', 'Displays', 'Modules', 
                  'ICs & Chips', 'Power Supplies', 'Cables & Wires', 'Connectors', 'Accessories'
                ].map((category) => InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductsScreen(category: category),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey.shade200,
                          child: const Icon(Icons.category, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(category, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ),
'''.trimRight(),
    '''
            // 2. Premium Pill Categories Nav
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: [
                  'Home', 'Sensors', 'Dev Boards', 'Arduino', 'Displays', 'Modules', 
                  'ICs & Chips', 'Power Supplies', 'Cables & Wires', 'Connectors', 'Accessories'
                ].length,
                itemBuilder: (context, index) {
                  final categoriesList = [
                    'Home', 'Sensors', 'Dev Boards', 'Arduino', 'Displays', 'Modules', 
                    'ICs & Chips', 'Power Supplies', 'Cables & Wires', 'Connectors', 'Accessories'
                  ];
                  final category = categoriesList[index];
                  final isSelected = index == 0; 
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () {
                        if (index == 0) return; // Home just stays here
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductsScreen(category: category),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                        decoration: BoxDecoration(
                          gradient: isSelected 
                              ? const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFFF5252)])
                              : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(21),
                          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
                          boxShadow: isSelected ? [
                            BoxShadow(color: const Color(0xFFD32F2F).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                          ] : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
'''.trimRight()
  );

  file.writeAsStringSync(content);
}
