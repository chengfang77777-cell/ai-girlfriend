import 'package:flutter_test/flutter_test.dart';
import 'package:ai_girlfriend/data/speech_http_client.dart';

void main() {
  test('uses enabled Windows system proxy for the HTTPS speech endpoint', () {
    final config = WindowsSpeechProxy(enabled: true, server: '127.0.0.1:7890');
    expect(
        config.findProxy(
            Uri.parse('https://api.xiaomimimo.com/v1/chat/completions')),
        'PROXY 127.0.0.1:7890');
  });
  test('honors per protocol proxy, disabled state and local bypasses', () {
    final config = WindowsSpeechProxy(
        enabled: true,
        server: 'http=localhost:7890;https=localhost:7891',
        bypass: '*.example.com;<local>');
    expect(config.findProxy(Uri.parse('https://api.xiaomimimo.com')),
        'PROXY localhost:7891');
    expect(config.findProxy(Uri.parse('http://example.net')),
        'PROXY localhost:7890');
    for (final address in [
      'http://127.0.0.1:1234',
      'http://localhost',
      'http://[::1]',
      'https://x.example.com',
      'http://printer'
    ]) {
      expect(config.findProxy(Uri.parse(address)), 'DIRECT');
    }
    expect(
        WindowsSpeechProxy(enabled: false, server: '127.0.0.1:7890')
            .findProxy(Uri.parse('https://example.net')),
        'DIRECT');
  });
  test('malformed proxy entries cannot become injected proxy directives', () {
    for (final server in [
      'host:0',
      'host:99999',
      'http://host:80/path',
      'user:password@host:80'
    ]) {
      expect(
          WindowsSpeechProxy(enabled: true, server: server)
              .findProxy(Uri.parse('https://example.net')),
          'DIRECT');
    }
  });
}
