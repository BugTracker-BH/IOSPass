#import <UIKit/UIKit.h>

// WKContentView is WebKit's per-process content view — it lives inside the
// sandboxed com.apple.WebKit.WebContent process, not inside Safari's own UI
// process (a common mistake when targeting Safari/WebKit tweaks). UIKit
// reads -textContentType off the focused field to decide what input
// affordances to show: keyboard type, QuickType bar, and — specifically
// when the value is UITextContentTypeNewPassword — the "Automatic Strong
// Password" suggestion sheet.
//
// Returning nil for that one case tells the system "no special content
// type here." The field keeps working exactly as before for typing,
// pasting, and AutoFilling a *saved* password; it just no longer gets
// flagged as a new-password field, so the suggestion sheet never appears.
// Every other content type (username, one-time-code, etc.) passes through
// completely untouched.

%hook WKContentView

- (UITextContentType)textContentType {
    UITextContentType orig = %orig;

    // This getter can fire on practically every keystroke and layout pass
    // in a process where a crash is highly visible to the user — it shows
    // up as Safari's "This webpage was reloaded because a problem
    // occurred" loop. Never let anything here propagate past us; worst
    // case, fail open and hand back the untouched original value.
    @try {
        if (orig && [orig isEqualToString:UITextContentTypeNewPassword]) {
            return nil;
        }
    } @catch (NSException *exception) {
        return orig;
    }

    return orig;
}

%end

%ctor {
    @try {
        NSLog(@"[NoStrongPass] active in %@",
              [[NSBundle mainBundle] bundleIdentifier] ?: NSProcessInfo.processInfo.processName);
    } @catch (NSException *exception) {
        // Never let ctor-time logging take the host process down.
    }
}
