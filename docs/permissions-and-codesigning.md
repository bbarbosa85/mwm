# macOS Accessibility Permissions & Code Signing Guide

This guide explains how macOS Transparency, Consent, and Control (TCC) manages permissions for **Slate**, why Accessibility permissions break after application updates, and how to configure persistent code signing so permissions are preserved across all future builds.

---

## 1. Overview of macOS Accessibility (TCC)

Slate is a window manager that operates by interacting with the macOS **Accessibility APIs** (`AXUIElementRef`, `AXObserverRef`) and creating Quartz event taps (`CGEventTapCreate`) to listen for system-wide hotkeys and window focus events.

Because these APIs can manipulate other applications' windows and intercept keystrokes, macOS subjects Slate to strict privacy controls governed by the **TCC (Transparency, Consent, and Control)** subsystem.

* **Target API**: `AXIsProcessTrustedWithOptions`
* **Target Privacy Domain**: `kTCCServiceAccessibility`
* **System Settings Location**: **System Settings → Privacy & Security → Accessibility**

---

## 2. Why Permissions Fail After Updating the App

A common problem when developing or updating macOS window managers (such as Slate, Rectangle, or Amethyst) is that **Accessibility stops working after rebuilding or updating the app**, even though Slate still appears with an "ON" toggle in System Settings.

### The Mechanism: Designated Requirements and `cdhash`

When an application is granted permission in System Settings, macOS TCC saves a cryptographic identity record called the **Designated Requirement (DR)** in its internal database (`/Library/Application Support/com.apple.TCC/TCC.db`).

#### Case A: Ad-Hoc Signed Binary (`codesign -s -`)
When an application is built without a persistent developer certificate (ad-hoc signed), macOS cannot tie the application to a verified authority. As a fallback, macOS binds the permission directly to the **Code Directory Hash (`cdhash`)** of that exact binary:

```text
Designated Requirement: identifier "com.slate.Slate" and cdhash H"a2512db6f3a614b496c225ed8805724b22571e3f"
```

* **The Problem**: Whenever the code is modified and rebuilt, the binary hash (`cdhash`) changes.
* **The Silent Revocation**: macOS detects that the binary on disk does not match the approved `cdhash`. For security reasons, macOS **silently invalidates the permission**.
* **The UI Disconnect**: The macOS System Settings GUI often continues to show the checkbox as checked, but `AXIsProcessTrustedWithOptions()` returns `false` at runtime.

#### Case B: Stable Signed Binary (Persistent Certificate)
When Slate is signed with a persistent certificate (either an Apple Developer certificate or a local self-signed code signing certificate), the Designated Requirement is tied to the **certificate thumbprint** rather than the binary hash:

```text
Designated Requirement: identifier "com.slate.Slate" and certificate leaf = H"CERTIFICATE_HASH..."
```

* **The Result**: The binary hash is **not** part of the requirement. As long as future updates are signed with the same certificate, **macOS automatically preserves the Accessibility permission across every build and update**.

---

## 3. Can Permissions Be Granted Automatically via Script?

**No.** Apple intentionally designed macOS so that applications cannot grant themselves Accessibility permissions programmatically:

1. **System Integrity Protection (SIP)**: The TCC database (`/Library/Application Support/com.apple.TCC/TCC.db`) is locked down with SIP. Even running a script with `sudo` or `root` will fail with `Operation not permitted`.
2. **User Consent Requirement**: The user must explicitly approve the application in the System Settings GUI.

However, once approved with a **persistent certificate**, you will **never** have to approve or reset the permission again.

---

## 4. How to Configure Persistent Code Signing

You can use either a free self-signed certificate on your Mac (no Apple account needed) or an official Apple Developer certificate.

### Method A: Create a Free Local Code Signing Certificate (Recommended)

This creates a persistent certificate stored in your macOS Keychain.

1. Open **Keychain Access** on your Mac (press `Cmd + Space`, search for `Keychain Access`).
2. From the application menu bar, choose:
   **Keychain Access → Certificate Assistant → Create a Certificate...**
3. Configure the certificate with the following details:
   - **Name**: `Slate Code Signing` *(Exact match)*
   - **Identity Type**: `Self-Signed Root`
   - **Certificate Type**: `Code Signing`
4. Click **Create**, then click **Continue**.
5. Verify the certificate in Terminal:
   ```bash
   security find-identity -v -p codesigning
   ```
   You should see:
   ```text
   1) <HASH> "Slate Code Signing"
      1 valid identities found
   ```

### Method B: Use an Apple Developer Account (Xcode)

If you have an Apple Developer account or free Apple ID:

1. Open [`Slate.xcodeproj`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate.xcodeproj) in Xcode.
2. Select the top-level **Slate** project in the navigator, then select the **Slate** target.
3. Open the **Signing & Capabilities** tab.
4. Enable **Automatically manage signing** and choose your **Team**.
5. Xcode will automatically generate and install an `Apple Development` certificate in your keychain.

---

## 5. Building and Packaging with the Certificate

The release script [`script/build-dmg.sh`](file:///Users/brunobarbosa/Projetos/mwm/mwm/script/build-dmg.sh) automatically inspects your keychain:
1. It looks for `"Slate Code Signing"` first.
2. It looks for `"Apple Development"` second.
3. If neither is found, it falls back to ad-hoc signing (`-`).

To build and package a DMG:
```bash
./script/build-dmg.sh Release
```

To manually override or specify a specific identity:
```bash
SIGN_IDENTITY="Slate Code Signing" ./script/build-dmg.sh Release
```

To manually sign an installed application bundle:
```bash
codesign --force --deep --sign "Slate Code Signing" /Applications/Slate.app
```

---

## 6. Troubleshooting Stale Permissions

If you previously ran an ad-hoc build and permissions are stuck or failing:

### Step 1: Reset the TCC Entry in Terminal
Run the following command to clear any stale or invalidated permission records:
```bash
tccutil reset Accessibility com.slate.Slate
```

### Step 2: Remove Stale GUI Entries in System Settings
1. Open **System Settings → Privacy & Security → Accessibility**.
2. If `Slate` appears in the list, highlight it and click the **`—` (minus)** button at the bottom to remove it. *(Do not merely toggle the switch off and on).*

### Step 3: Launch the Signed Build
1. Copy the newly signed `Slate.app` to `/Applications/Slate.app`.
2. Launch `/Applications/Slate.app`.
3. When prompted, allow Slate in **System Settings → Privacy & Security → Accessibility**.

Because the binary is signed with your persistent certificate, you will never need to repeat this process for subsequent builds or updates.

---

## 7. Verifying the Signature

You can check whether your installed `Slate.app` has a proper bundle signature and designated requirement using `codesign`:

```bash
codesign -dvvv /Applications/Slate.app
```

Look for:
- `Identifier=com.slate.Slate` (matches bundle identifier).
- `Authority=Slate Code Signing` (or `Apple Development: ...`).
- `Sealed Resources=...` (resources and Info.plist are signed and sealed).

