/// Stub implementation – throws on non-web platforms.
void downloadCsvFile(String csvContent, String fileName) {
  throw UnsupportedError('CSV download is only supported on web');
}
