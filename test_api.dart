import 'dart:convert';
import 'dart:io';

void main() async {
  final req = await HttpClient().getUrl(Uri.parse('https://rtest.epriceoffer.com/api/sectorTitleRoutes'));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print(body);
}
