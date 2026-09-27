import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Dart's IO client does not automatically use Windows Internet Settings.
/// Read the user's manual proxy without changing OS configuration.
class WindowsSpeechProxy {
  const WindowsSpeechProxy(
      {required this.enabled, required this.server, this.bypass = ''});
  final bool enabled;
  final String server;
  final String bypass;

  String findProxy(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!enabled ||
        host == 'localhost' ||
        host == '::1' ||
        host.startsWith('127.')) return 'DIRECT';
    for (final item in bypass.toLowerCase().split(';')) {
      final pattern = item.trim();
      if (pattern.isEmpty) continue;
      if (pattern == '<local>' && !host.contains('.')) return 'DIRECT';
      final expression =
          RegExp('^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}' r'$');
      if (expression.hasMatch(host)) return 'DIRECT';
    }
    var address = server.trim();
    if (address.contains('=')) {
      final values = <String, String>{};
      for (final entry in address.split(';')) {
        final split = entry.indexOf('=');
        if (split > 0) {
          values[entry.substring(0, split).trim().toLowerCase()] =
              entry.substring(split + 1).trim();
        }
      }
      address = values[uri.scheme] ?? '';
    }
    // Only a host:port authority is supported by HttpClient's HTTP proxy.
    if (address.isEmpty || RegExp(r'[\s;/@]').hasMatch(address)) {
      return 'DIRECT';
    }
    final proxy = Uri.tryParse('http://$address');
    if (proxy == null ||
        proxy.host.isEmpty ||
        !proxy.hasPort ||
        proxy.port < 1 ||
        proxy.port > 65535) return 'DIRECT';
    return 'PROXY $address';
  }

  static Future<WindowsSpeechProxy> read() async {
    const key =
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
    final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    Future<String> value(String name) async {
      final result = await Process.run(
              '$root\\System32\\reg.exe', ['query', key, '/v', name])
          .timeout(const Duration(seconds: 2));
      if (result.exitCode != 0) return '';
      final match = RegExp('${RegExp.escape(name)}\\s+REG_\\w+\\s+([^\\r\\n]+)')
          .firstMatch(result.stdout.toString());
      return match?.group(1)?.trim() ?? '';
    }

    final enabled = await value('ProxyEnable');
    if (enabled != '0x1' && enabled != '1') {
      return const WindowsSpeechProxy(enabled: false, server: '');
    }
    final entries =
        await Future.wait([value('ProxyServer'), value('ProxyOverride')]);
    return WindowsSpeechProxy(
        enabled: true, server: entries[0], bypass: entries[1]);
  }
}

Future<http.Client> createSpeechHttpClient() async {
  final native = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    if (Platform.isWindows) {
      final settings = await WindowsSpeechProxy.read();
      native.findProxy = settings.findProxy;
    } else {
      native.findProxy = HttpClient.findProxyFromEnvironment;
    }
    return IOClient(native);
  } catch (_) {
    native.close(force: true);
    rethrow;
  }
}
