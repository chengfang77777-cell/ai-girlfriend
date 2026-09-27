import 'package:ai_girlfriend/data/speech_http_client.dart';
Future<void> main() async {
 final c=await WindowsSpeechProxy.read();
 print('enabled=${c.enabled} decision=${c.findProxy(Uri.parse("https://api.xiaomimimo.com"))}');
}
