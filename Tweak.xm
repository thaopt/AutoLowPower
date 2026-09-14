#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>

// --- Debug logging ---
#define ALPLog(fmt, ...) NSLog(@"[AutoLowPower] " fmt, ##__VA_ARGS__)

// --- Private APIs ---
// LowPowerMode framework (iOS 15+). This is what Control Center / SpringBoard
// use to toggle Low Power Mode. (_CDBatterySaver is legacy iOS 11-12 and does
// not exist on modern iOS.)
@interface _PMLowPowerMode : NSObject
+ (instancetype)sharedInstance;
- (NSInteger)getPowerMode;
- (void)setPowerMode:(NSInteger)powerMode fromSource:(NSString *)source;
@end

@interface SBUIController : NSObject
+ (SBUIController *)sharedInstance;
- (BOOL)isOnAC;
@end

// --- Preferences ---
static NSString *const kBundleID = @"com.user.autolowpower";
static NSString *const kNotifChanged = @"com.user.autolowpower.changed";
static NSString *const kNotifTest = @"com.user.autolowpower.test";
static NSString *const kLPMSource = @"AutoLowPower";

typedef NS_ENUM(NSInteger, ALPAction) {
    ALPActionNoChange = 0,
    ALPActionOn      = 1,   // force Low Power Mode ON
    ALPActionOff     = 2,   // force Low Power Mode OFF
};

static BOOL  gEnabled          = YES;
static NSInteger gOnPlugAction = ALPActionOn;   // default: enable LPM when plugged in
static NSInteger gOnUnplugAction = ALPActionOff; // default: disable LPM when unplugged
static BOOL  gLastCharging     = NO;
static BOOL  gBooted           = NO;

static void ApplyLPM(BOOL on) {
    _PMLowPowerMode *lpm = [%c(_PMLowPowerMode) sharedInstance];
    if (!lpm) {
        ALPLog(@"ApplyLPM: _PMLowPowerMode sharedInstance is nil!");
        return;
    }
    NSInteger mode = [lpm getPowerMode];
    NSInteger target = on ? 1 : 0;
    ALPLog(@"ApplyLPM: current=%ld target=%ld", (long)mode, (long)target);
    if (mode != target) {
        [lpm setPowerMode:target fromSource:kLPMSource];
        ALPLog(@"ApplyLPM: setPowerMode:%ld fromSource:%@ done", (long)target, kLPMSource);
    } else {
        ALPLog(@"ApplyLPM: already in target mode, skipping");
    }
}

static void ReloadPrefs(void) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:kBundleID];
    gEnabled = [prefs objectForKey:@"enabled"] ? [[prefs objectForKey:@"enabled"] boolValue] : YES;
    gOnPlugAction   = [prefs objectForKey:@"onPlug"]   ? [[prefs objectForKey:@"onPlug"] integerValue]   : ALPActionOn;
    gOnUnplugAction = [prefs objectForKey:@"onUnplug"] ? [[prefs objectForKey:@"onUnplug"] integerValue] : ALPActionOff;
    ALPLog(@"ReloadPrefs: enabled=%d onPlug=%ld onUnplug=%ld", gEnabled, (long)gOnPlugAction, (long)gOnUnplugAction);
}

// Evaluate current charging state and apply the matching LPM action when it changes.
static void EvaluateCharging(BOOL charging) {
    if (!gEnabled) {
        ALPLog(@"EvaluateCharging: disabled, ignoring (charging=%d)", charging);
        return;
    }

    if (gBooted && charging == gLastCharging) {
        ALPLog(@"EvaluateCharging: no transition (charging=%d), skipping", charging);
        return; // only act on a real plug/unplug transition
    }

    NSInteger action = charging ? gOnPlugAction : gOnUnplugAction;
    ALPLog(@"EvaluateCharging: charging=%d (was %d) -> action=%ld", charging, gLastCharging, (long)action);

    if (action == ALPActionOn)       ApplyLPM(YES);
    else if (action == ALPActionOff) ApplyLPM(NO);

    gLastCharging = charging;
    gBooted = YES;
}

// Manual test trigger from the Settings "Test" button.
static void RunTestAction(void) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:kBundleID];
    NSInteger action = [prefs objectForKey:@"testAction"] ? [[prefs objectForKey:@"testAction"] integerValue] : ALPActionOn;
    ALPLog(@"RunTestAction: applying action=%ld", (long)action);

    if (action == ALPActionOn)       ApplyLPM(YES);
    else if (action == ALPActionOff) ApplyLPM(NO);
    else ALPLog(@"RunTestAction: action=NoChange, nothing to do");
}

%hook SBUIController
- (void)updateBatteryState:(id)state {
    %orig;
    ALPLog(@"updateBatteryState fired, isOnAC=%d", [self isOnAC]);
    EvaluateCharging([self isOnAC]);
}
%end

%ctor {
    @autoreleasepool {
        ALPLog(@"ctor: loading");
        ReloadPrefs();

        // Re-read prefs when changed from the Settings app (no respring needed).
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            (CFNotificationCallback)ReloadPrefs,
            (CFStringRef)kNotifChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);

        // Manual test trigger from the Settings "Test" button.
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            (CFNotificationCallback)RunTestAction,
            (CFStringRef)kNotifTest, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);

        // Apply once shortly after load so state is correct right away.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SBUIController *ctrl = [%c(SBUIController) sharedInstance];
            ALPLog(@"boot apply: isOnAC=%d", [ctrl isOnAC]);
            EvaluateCharging([ctrl isOnAC]);
        });
    }
}