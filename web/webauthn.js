(function () {
  const b64urlToBuf = (b64url) => {
    const pad = "=".repeat((4 - (b64url.length % 4)) % 4);
    const b64 = (b64url + pad).replace(/-/g, "+").replace(/_/g, "/");
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes.buffer;
  };
  const bufToB64url = (buf) => {
    const bytes = new Uint8Array(buf);
    let bin = "";
    for (let i = 0; i < bytes.byteLength; i++) {
      bin += String.fromCharCode(bytes[i]);
    }
    return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  };

  async function registerWithWebAuthn(optionsJson) {
    const o = JSON.parse(optionsJson);
    o.challenge = b64urlToBuf(o.challenge);
    o.user.id = b64urlToBuf(o.user.id);
    if (Array.isArray(o.excludeCredentials)) {
      o.excludeCredentials = o.excludeCredentials.map((c) => ({
        ...c,
        id: b64urlToBuf(c.id),
      }));
    }
    const cred = await navigator.credentials.create({ publicKey: o });
    return JSON.stringify({
      id: cred.id,
      rawId: bufToB64url(cred.rawId),
      type: cred.type,
      authenticatorAttachment: cred.authenticatorAttachment ?? null,
      response: {
        attestationObject: bufToB64url(cred.response.attestationObject),
        clientDataJSON: bufToB64url(cred.response.clientDataJSON),
      },
      clientExtensionResults: cred.getClientExtensionResults?.() ?? {},
    });
  }

  async function authenticateWithWebAuthn(optionsJson, useConditional) {
    const o = JSON.parse(optionsJson);
    o.challenge = b64urlToBuf(o.challenge);
    if (Array.isArray(o.allowCredentials)) {
      o.allowCredentials = o.allowCredentials.map((c) => ({
        ...c,
        id: b64urlToBuf(c.id),
      }));
    }
    const opts = { publicKey: o };
    if (useConditional) opts.mediation = "conditional"; // 対応ブラウザなら“ボタンなしUI”
    const cred = await navigator.credentials.get(opts);
    return JSON.stringify({
      id: cred.id,
      rawId: bufToB64url(cred.rawId),
      type: cred.type,
      response: {
        authenticatorData: bufToB64url(cred.response.authenticatorData),
        clientDataJSON: bufToB64url(cred.response.clientDataJSON),
        signature: bufToB64url(cred.response.signature),
        userHandle: cred.response.userHandle
          ? bufToB64url(cred.response.userHandle)
          : null,
      },
      clientExtensionResults: cred.getClientExtensionResults?.() ?? {},
    });
  }

  window._webauthn = { registerWithWebAuthn, authenticateWithWebAuthn };
})();
