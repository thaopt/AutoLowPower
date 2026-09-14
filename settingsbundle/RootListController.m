#import "RootListController.h"
#import <UIKit/UIKit.h>

@implementation RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)runTest {
    // Post a Darwin notification so the injected SpringBoard tweak applies the
    // currently-selected "Test Action" immediately, without needing to plug/unplug.
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.user.autolowpower.test"),
        NULL, NULL, YES);
}

@end