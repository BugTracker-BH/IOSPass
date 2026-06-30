# NoStrongPass

A jailbreak tweak for iOS 16.4.1 (rootless) that stops Safari/WebKit from
popping up the "Automatic Strong Password" suggestion on password fields,
without disabling AutoFill entirely (that's the only option Apple exposes in
Settings, and it's overkill if you just want the *suggestion* gone).

## How it works

iOS decides whether a field is a "create a new password" field using a
heuristic plus an explicit signal (`autocomplete="new-password"` in the
page's HTML, or `UITextContentType.newPassword` in native fields). Whatever
the source, the result funnels through `-[WKContentView textContentType]` —
WebKit's content view reports this to the system so it knows what input UI
to show. This tweak hooks that one method, in the sandboxed
`com.apple.WebKit.WebContent` process where WebKit actually renders pages
(not Safari's main process — a common mistake in WebKit tweaks), and strips
out `newPassword` specifically. The field still works for typing, pasting,
or filling a saved password normally; it just stops triggering the
strong-password popup.

## What changed from the first build

The first iteration used the right approach but had three issues that line
up with the "Safari stuck reloading" symptom and with CI build reliability:

1. **`Makefile` hardcoded `TARGET := iphone:clang:16.5:14.0`.** That only
   builds if `iPhoneOS16.5.sdk` *exactly* exists in `$THEOS/sdks` — brittle
   locally, and a guaranteed failure point in CI if the runner's SDK bundle
   differs. Switched to `iphone:clang:latest:14.0`, Theos's own documented
   pattern for this.
2. **`control` only depended on `mobilesubstrate`.** Modern rootless
   jailbreaks (Dopamine, palera1n) hook through **ElleKit**. Real-world
   rootless tweaks declare both (`mobilesubstrate` *and* `ellekit`) — now
   added explicitly.
3. **The hook had no crash-safety.** `-textContentType` fires on nearly
   every keystroke and layout pass inside the most heavily sandboxed
   process on the system. It's now wrapped to fail open — if anything
   ever goes wrong, it hands back the untouched original value instead of
   letting a problem escape into WebKit's call stack.

I can't fully guarantee this was *the* root cause without a device crash log
(no jailbroken hardware available to test against here) — but these are the
standard, documented fixes for this exact failure class. If it still
reproduces after installing this build, grab a crash log from
`/var/mobile/Library/Logs/CrashReporter/` for `com.apple.WebKit.WebContent`
and we can pinpoint it exactly.

## Requirements

- A jailbroken iPhone on iOS 16.4.1, **rootless** jailbreak (Dopamine is the
  standard for 16.4.1) — that's what `THEOS_PACKAGE_SCHEME = rootless` in
  the Makefile sets up.
- Either: Theos installed locally ([theos.dev/docs/installation](https://theos.dev/docs/installation)),
  **or**: just push this repo to GitHub and let the included Actions
  workflow build it for you (see below) — no Mac, no local Theos install
  needed.

## Build it yourself with GitHub Actions

This repo includes `.github/workflows/build.yml`. Push it to a GitHub repo
(`Makefile` etc. at the repo root, exactly as they are in this zip) and the
workflow will:

1. Install Theos via [`Randomblock1/theos-action`](https://github.com/Randomblock1/theos-action)
   (caches it after the first run, so later builds are fast).
2. Run `make package FINALPACKAGE=1` on both a macOS and an Ubuntu runner.
3. Upload the resulting `.deb` as a downloadable build artifact under the
   workflow run's **Artifacts** section.

No secrets or config needed — it works out of the box. Trigger it by
pushing, opening a PR, or running it manually from the **Actions** tab
(`workflow_dispatch`).

## Build locally instead

```bash
git clone --recursive https://github.com/theos/theos.git $THEOS   # if you don't have Theos yet
export THEOS=~/theos                                              # adjust to wherever you cloned it

make package
```

This produces a `.deb` in `packages/`. To build and install directly over
SSH to a connected/network-reachable device in one step:

```bash
make package install THEOS_DEVICE_IP=<your iPhone's IP>
```

Then respring (or it'll prompt you to).

## Installing the .deb

Transfer the `.deb` to your device (AirDrop, Filza, scp, or Sileo/Zebra's
"Install from file" if available) and install it through your package
manager so dependencies (`ellekit`, `mobilesubstrate`) get resolved. Fully
close Safari (swipe it away in the app switcher) afterward so it relaunches
the WebContent process with the tweak loaded.

## Testing it

Open Safari, go to a site with a signup form, tap into the password field —
the strong-password popup shouldn't appear anymore, but you can still type
or paste a password normally. To confirm the tweak loaded, grab a syslog
(`idevicesyslog`, or Sileo's built-in log viewer) and look for
`[NoStrongPass] active in com.apple.WebKit.WebContent`.

## If it doesn't fully suppress the popup

Private WebKit internals shift between iOS versions, so if this specific
hook point doesn't catch every case on your exact build, the next thing to
try is hooking further upstream — `-[WKContentView _startAssistingNode:...]`
or the Quickboard input-context creation methods
(`-createQuickboardTextInputContext` in WebKit's source) are the other
points in the same pipeline. Class-dump the `WebKit` private framework
on-device to confirm exact signatures for your build before hooking those,
since they're more likely to have changed across versions than the public
`textContentType` property used here.

## Note

This only removes the *suggestion popup*. It doesn't touch AutoFill itself —
saved password filling, and your ability to choose your own strong
password, both still work exactly as before.
