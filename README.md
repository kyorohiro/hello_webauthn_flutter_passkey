
```
fvm flutter run -d chrome --web-port 5173
```

# PS
サーバー側のコードは、https://github.com/kyorohiro/hello_webauthn_web

flutter web only のコードは、 https://github.com/kyorohiro/hello_webauthn_flutter_web

flutter package のコードは、 https://github.com/kyorohiro/hello_webauthn_flutter_passkey


# memo
## firebase 

プロジェクトの設定->全般->SHA 証明書フィンガープリント  を 登録


## android app

server側に、/.well-known/assetlinks.json を設定してください
server側の expectedOrigins に、
`android:apk-key-hash:GngWf_CVnazTEja0Z9re9WRMQelDiUNqZ3M8DR1zjpI'` // {fingerprint の base64} を追加


## ios app 

public/.well-known/apple-app-site-association を設定してください

XCode の ios/Runner/Runner.entitlements に、`com.apple.developer.associated-domains` を追加

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>webcredentials:example.com</string>
	</array>
</dict>
</plist>

```
