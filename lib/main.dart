import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

const apiBase = 'http://localhost:3000'; // Express 側
const defaultUserId = 'u123'; // デモ用。実運用はサーバ割当が安全

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isLoggedIn = false;
  String log = '';
  final userIdCtl = TextEditingController(text: defaultUserId);
  final displayCtl = TextEditingController(text: 'Kiyohiro');
  final PasskeyAuthenticator _authenticator = PasskeyAuthenticator(
    debugMode: true,
  );

  void _append(String s) => setState(() => log = '$s\n$log');

  Future<void> registerPasskey() async {
    print("> registerPasskey");
    try {
      final userId = userIdCtl.text.trim();
      final displayName = displayCtl.text.trim().isEmpty
          ? 'User'
          : displayCtl.text.trim();

      print(">> requesting options");
      final optsRes = await http.post(
        Uri.parse('$apiBase/api/webauthn/registration/options'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'username': userId,
          'displayName': displayName,
        }),
      );
      if (!optsRes.ok) throw Exception('options failed: ${optsRes.statusCode}');
      final responseJsonSrc = optsRes.body;
      final responseJson = json.decode(responseJsonSrc);
      print(responseJsonSrc);

      print(">> requesting attestation");
      print(responseJson['challenge']);
      print(responseJson['rp']);
      print(responseJson['user']);
      print({
        "challenge": responseJson['challenge'] as String,
        "relyingParty": RelyingPartyType(
          id: responseJson['rp']['id'],
          name: responseJson['rp']['name'],
        ),
        //.fromJson(responseJson['rp'] as Map<String, dynamic>),
        "user1": UserType.fromJson(
          responseJson['user'] as Map<String, dynamic>,
        ),
        "user": UserType(
          displayName: responseJson['user']['displayName'],
          id: responseJson['user']['id'],
          name: responseJson['user']['name'],
        ),
        "excludeCredentials": [],
      });
      final attRespJson = await _authenticator.register(
        RegisterRequestType.fromJson(responseJson),
        /*
        RegisterRequestType(
          challenge: responseJson['challenge'] as String,
          relyingParty: RelyingPartyType(
            id: responseJson['rp']['id'],
            name: responseJson['rp']['name'],
          ),
          //.fromJson(responseJson['rp'] as Map<String, dynamic>),
          //user: UserType.fromJson(responseJson['user'] as Map<String, dynamic>), excludeCredentials: []
          user: UserType(
            displayName: responseJson['user']['displayName'],
            id: responseJson['user']['id'],
            name: responseJson['user']['name'],
          ),
          excludeCredentials: [],
        ),*/
      );
      print(">>> / attestation response");
      print(attRespJson);
      print(attRespJson.toJson());

      print(">> requesting verification");
      final vr = await http.post(
        Uri.parse('$apiBase/api/webauthn/registration/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'attResp': attRespJson.toJson()}),
      );

      if (!vr.ok) throw Exception('verify failed: ${vr.body}');

      _append('✅ Passkey registered');
    } catch (e) {
      print("> error in registerPasskey");
      print(e);
      _append('❌ $e');
    }
  }

  Future<void> loginPasskey({bool conditional = false}) async {
    print("> loginPasskey");
    try {
      final userId = userIdCtl.text.trim();
      print(">> requesting options");
      final optsRes = await http.post(
        Uri.parse('$apiBase/api/webauthn/authentication/options'),
        headers: {'Content-Type': 'application/json'},
        // usernameless運用なら body は空でもOK。今回は userId 付き例
        body: json.encode({'userId': userId}),
      );
      print(">> requesting options response");
      if (!optsRes.ok) throw Exception('options failed: ${optsRes.statusCode}');
      print(optsRes.body);
      /*
      {
       "rpId":"localhost",
       "challenge":"9V-yhs3pRbazNic8UKpeoMuOulpECC3mjujy4jLNjRM",
       "allowCredentials":[
       {"id":"40hOVADJ2q-IAUd3effxow","type":"public-key"},
       {"id":"nbdMp1Xp4R5_PiV41-qgzrZoLUw","type":"public-key"},
       {"id":"TlBuGjVdKocNqw8riwBv6EyxC-g","type":"public-key"},{"id":"CdKb4nSbaiAyqdKZR6WC6_xr7MY","type":"public-key"}],
       "timeout":60000,"userVerification":"required"}
      */
      print(">> requesting authentication");
      final optsRespJson = json.decode(optsRes.body);
      print(optsRespJson);
      print(">>> / allowCredentials:");
      print(">>> prepare");
      final rawAllowCreds = optsRespJson['allowCredentials'];
      final List<CredentialType> allowCredentials = rawAllowCreds is List
          ? rawAllowCreds
                .whereType<Map<String, dynamic>>() // 念のため
                .map(
                  (e) => CredentialType(
                    type: e['type'] as String,
                    id: e['id'] as String,
                    // transports はサーバレスポンス側にまだ無いので、とりあえず空でOK
                    transports: const <String>[],
                  ),
                )
                .toList()
          : <CredentialType>[];
      print(">>> start");
      final assertionJson = await _authenticator.authenticate(
        //AuthenticateRequestType.fromJson(optsRespJson));
        AuthenticateRequestType(
          relyingPartyId: optsRespJson['rpId'] as String,
          challenge: optsRespJson['challenge'] as String,
          timeout: optsRespJson['timeout'] as int?,
          //userVerification: optsRespJson['userVerification'] as String?,
          allowCredentials: allowCredentials,
          mediation: conditional
              ? MediationType.Conditional
              : MediationType.Optional,
          preferImmediatelyAvailableCredentials: false,
        ),
      );
      // authenticateWithWebAuthn(optsRes.body, conditional);
      print(">> requesting verification");
      final vr = await http.post(
        Uri.parse('$apiBase/api/webauthn/authentication/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'assertionResp': assertionJson.toJson(),
        }),
      );
      print(">> requesting verification response");
      if (!vr.ok) throw Exception('verify failed: ${vr.body}');
      setState(() => isLoggedIn = true);
      _append('✅ Login OK');
    } catch (e) {
      _append('❌ $e');
    }
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('LoggedIn: $isLoggedIn'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: userIdCtl,
                          decoration: const InputDecoration(
                            labelText: 'User ID (server-assigned推奨)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: displayCtl,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: registerPasskey,
                        child: const Text('Register Passkey'),
                      ),
                      FilledButton(
                        onPressed: () => loginPasskey(),
                        child: const Text('Login'),
                      ),
                      FilledButton(
                        onPressed: () => loginPasskey(conditional: true),
                        child: const Text('Login (Conditional UI)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Log'),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      reverse: true,
                      child: SelectableText(
                        log,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on http.Response {
  bool get ok => statusCode >= 200 && statusCode < 300;
}
