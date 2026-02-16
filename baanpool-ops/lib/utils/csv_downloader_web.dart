import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Download a CSV file in the browser.
void downloadCsvFile(String csvContent, String fileName) {
  // Add BOM for Excel to recognise UTF-8
  final bom = '\uFEFF';
  final bytes = utf8.encode('$bom$csvContent');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
