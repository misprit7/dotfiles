// Chrome opens its own dropdown ("Use a passkey from another device") on login fields
// whenever a page asks for passkey autofill, i.e. calls navigator.credentials.get() with
// mediation "conditional". Chrome has no setting for this, and Bitwarden hands such a
// request on to Chrome as well as answering it itself, so the dropdown covers
// Bitwarden's menu.
//
// This keeps those requests away from Chrome. They stay pending, as if the dropdown had
// been ignored, until the page cancels them. A request started by a "sign in with a
// passkey" button is not conditional and goes through untouched.
//
// The "key" in manifest.json fixes the extension ID to one starting with "a". Chrome
// runs extensions' page scripts in ID order, so this runs before Bitwarden's (ID "nng...")
// and ends up underneath it: Bitwarden still sees the request and can offer its own
// passkeys, and only the copy it passes on to Chrome is held back.
(() => {
  // Not defined on insecure (plain http) pages, where passkeys do not exist.
  if (typeof CredentialsContainer === "undefined") {
    return;
  }

  const pendingUntilAborted = (signal) =>
    new Promise((_resolve, reject) => {
      if (!signal) {
        return;
      }
      if (signal.aborted) {
        reject(signal.reason);
        return;
      }
      signal.addEventListener("abort", () => reject(signal.reason), { once: true });
    });

  const withoutPasskeyAutofill = (get) =>
    function (options) {
      if (options?.mediation === "conditional" && options.publicKey) {
        return pendingUntilAborted(options.signal);
      }
      return get.apply(this, arguments);
    };

  const proto = CredentialsContainer.prototype;
  proto.get = withoutPasskeyAutofill(proto.get);

  // If another script got in first and replaced get() on the object itself, it already
  // holds Chrome's original, so the request has to be stopped before it gets there.
  const credentials = navigator.credentials;
  if (Object.hasOwn(credentials, "get")) {
    credentials.get = withoutPasskeyAutofill(credentials.get);
  }
})();
