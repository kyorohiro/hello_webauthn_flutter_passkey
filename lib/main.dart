import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:js_interop';           // ← これを使う
import 'package:web/web.dart' as web; // Promise/DOM 補助（あると便利）

const apiBase = 'http://localhost:3000'; // Express 側
const defaultUserId = 'u123';            // デモ用。実運用はサーバ割当が安全

// --- JS関数バインド（window._webauthn.* 直指定） ---
@JS('window._webauthn.registerWithWebAuthn')
external JSPromise<JSString> _registerWithWebAuthn(JSString optionsJson);

@JS('window._webauthn.authenticateWithWebAuthn')
external JSPromise<JSString> _authenticateWithWebAuthn(JSString optionsJson, bool useConditional);

// ラッパ（DartのFuture<String>に変換）
Future<String> registerWithWebAuthn(String optionsJson) async {
  final JSPromise<JSString> p = _registerWithWebAuthn(optionsJson.toJS);
  final JSString s = await p.toDart;       // Promise -> Future
  return s.toDart;                          // JSString -> String
}

Future<String> authenticateWithWebAuthn(String optionsJson, bool useConditional) async {
  final JSPromise<JSString> p = _authenticateWithWebAuthn(optionsJson.toJS, useConditional);
  final JSString s = await p.toDart;
  return s.toDart;
}
void main() => runApp(const MyApp());

class MyApp extends StatefulWidget { const MyApp({super.key}); @override State<MyApp> createState() => _MyAppState(); }

class _MyAppState extends State<MyApp> {
  bool isLoggedIn = false;
  String log = '';
  final userIdCtl = TextEditingController(text: defaultUserId);
  final displayCtl = TextEditingController(text: 'Kiyohiro');

  void _append(String s) => setState(() => log = '$s\n$log');

  Future<void> registerPasskey() async {
    try {
      final userId = userIdCtl.text.trim();
      final displayName = displayCtl.text.trim().isEmpty ? 'User' : displayCtl.text.trim();

      final optsRes = await http.post(
        Uri.parse('$apiBase/api/webauthn/registration/options'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'username': userId, 'displayName': displayName}),
      );
      if (!optsRes.ok) throw Exception('options failed: ${optsRes.statusCode}');
      final attRespJson = await registerWithWebAuthn(optsRes.body);

      final vr = await http.post(
        Uri.parse('$apiBase/api/webauthn/registration/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'attResp': json.decode(attRespJson)}),
      );
      if (!vr.ok) throw Exception('verify failed: ${vr.body}');
      _append('✅ Passkey registered');
    } catch (e) { _append('❌ $e'); }
  }

  Future<void> loginPasskey({bool conditional = false}) async {
    try {
      final userId = userIdCtl.text.trim();
      final optsRes = await http.post(
        Uri.parse('$apiBase/api/webauthn/authentication/options'),
        headers: {'Content-Type': 'application/json'},
        // usernameless運用なら body は空でもOK。今回は userId 付き例
        body: json.encode({'userId': userId}),
      );
      if (!optsRes.ok) throw Exception('options failed: ${optsRes.statusCode}');
      final assertionJson = await authenticateWithWebAuthn(optsRes.body, conditional);

      final vr = await http.post(
        Uri.parse('$apiBase/api/webauthn/authentication/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'assertionResp': json.decode(assertionJson)}),
      );
      if (!vr.ok) throw Exception('verify failed: ${vr.body}');
      setState(() => isLoggedIn = true);
      _append('✅ Login OK');
    } catch (e) { _append('❌ $e'); }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter WebAuthn Demo')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('LoggedIn: $isLoggedIn'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: userIdCtl, decoration: const InputDecoration(labelText: 'User ID (server-assigned推奨)'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: displayCtl, decoration: const InputDecoration(labelText: 'Display Name'))),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  FilledButton(onPressed: registerPasskey, child: const Text('Register Passkey')),
                  FilledButton(onPressed: () => loginPasskey(), child: const Text('Login')),
                  FilledButton(onPressed: () => loginPasskey(conditional: true), child: const Text('Login (Conditional UI)')),
                ]),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerLeft, child: Text('Log')),
                Expanded(child: SingleChildScrollView(reverse: true, child: SelectableText(log, style: const TextStyle(fontFamily: 'monospace')))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

extension on http.Response { bool get ok => statusCode >= 200 && statusCode < 300; }
