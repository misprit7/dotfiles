// Canonical Firefox prefs, installed into every profile by
// run_onchange_install-firefox-prefs.sh. Firefox reads user.js only from inside
// a profile directory, and profile directory names are randomly prefixed, so
// this file is the source and the script fans it out.
//
// Note: user.js is re-applied on every Firefox start, so these cannot be
// changed persistently from about:config — edit this file instead.

// Two-finger touchpad swipe = browser back/forward, the way macOS does it.
// This has to live in the browser rather than the sway config: libinput
// classifies 2-finger motion as scrolling and only emits swipe events for
// 3 fingers or more, so the compositor never sees it as a gesture.
//
// Direction follows macOS: content tracks the fingers, so dragging the page
// rightwards goes back.
user_pref("browser.gesture.swipe.right", "Browser:BackOrBackDuplicate");
user_pref("browser.gesture.swipe.left", "Browser:ForwardOrForwardDuplicate");
user_pref("widget.disable-swipe-tracker", false);
user_pref("apz.overscroll.enabled", true);
