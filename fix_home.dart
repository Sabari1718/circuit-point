import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/home_screen.dart');
  var content = file.readAsStringSync();

  // Normalize newlines
  content = content.replaceAll('\r\n', '\n');

  final badCode = '''
    return const SizedBox();
    },
    ),
    ),
    );
  }
''';

  final goodCode = '''
    return const SizedBox();
        },
      ),
    );
  }
''';

  content = content.replaceFirst(badCode, goodCode);
  file.writeAsStringSync(content);
}
