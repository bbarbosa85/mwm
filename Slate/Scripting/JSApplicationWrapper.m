//
//  JSApplicationWrapper.m
//  Slate
//
//  Created by Jigish Patel on 1/21/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import "JSApplicationWrapper.h"
#import "AccessibilityWrapper.h"
#import "ScreenWrapper.h"
#import "JSController.h"
#import "JSWindowWrapper.h"
#import "JSOperationWrapper.h"

@implementation JSApplicationWrapper

@synthesize aw, sw, app;

- (id)init {
  self = [super init];
  if (self) {
    [self setAw:[[AccessibilityWrapper alloc] init]];
    [self setSw:[[ScreenWrapper alloc] init]];
    [self setApp:[NSRunningApplication runningApplicationWithProcessIdentifier:[aw processIdentifier]]];
  }
  return self;
}

- (id)initWithAccessibilityWrapper:(AccessibilityWrapper *)_aw screenWrapper:(ScreenWrapper *)_sw {
  self = [super init];
  if (self) {
    [self setAw:_aw];
    [self setSw:_sw];
    [self setApp:[NSRunningApplication runningApplicationWithProcessIdentifier:[aw processIdentifier]]];
  }
  return self;
}

- (id)initWithRunningApplication:(NSRunningApplication *)_app screenWrapper:(ScreenWrapper *)_sw {
  self = [super init];
  if (self) {
    [self setApp:_app];
    [self setAw:nil];
    [self setSw:_sw];
  }
  return self;
}

- (pid_t)pid {
  return [app processIdentifier];
}

- (NSString *)name {
  return [app localizedName];
}

- (id)mwindow {
 return [self mainWindow];
}

- (id)mainWindow {
  AccessibilityWrapper *_aw = [[AccessibilityWrapper alloc] initWithApp:AXUIElementCreateApplication([app processIdentifier])
                                                                 window:[AccessibilityWrapper focusedWindowInRunningApp:app]];
  return [[JSWindowWrapper alloc] initWithAccessibilityWrapper:_aw screenWrapper:sw];
}

- (void)ewindow:(id)obj {
  [self eachWindow:obj];
}

- (void)eachWindow:(id)funcOrOp {
  CFArrayRef windowsArrRef = [AccessibilityWrapper windowsInRunningApp:app];
  if (!windowsArrRef || CFArrayGetCount(windowsArrRef) == 0) return;
  CFMutableArrayRef windowsArr = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, windowsArrRef);
  if ([funcOrOp isKindOfClass:[Operation class]] || [funcOrOp isKindOfClass:[JSOperationWrapper class]]) {
    for (NSInteger i = 0; i < CFArrayGetCount(windowsArr); i++) {
      AccessibilityWrapper *_aw = [[AccessibilityWrapper alloc] initWithApp:AXUIElementCreateApplication([app processIdentifier])
                                                                     window:CFArrayGetValueAtIndex(windowsArr, i)];
      [funcOrOp doOperationWithAccessibilityWrapper:_aw screenWrapper:sw];
    }
  } else if ([funcOrOp isKindOfClass:[JSValue class]]) {
    JSValue *val = (JSValue *)funcOrOp;
    for (NSInteger i = 0; i < CFArrayGetCount(windowsArr); i++) {
      AccessibilityWrapper *_aw = [[AccessibilityWrapper alloc] initWithApp:AXUIElementCreateApplication([app processIdentifier])
                                                                     window:CFArrayGetValueAtIndex(windowsArr, i)];
      [val callWithArguments:@[[[JSWindowWrapper alloc] initWithAccessibilityWrapper:_aw screenWrapper:sw]]];
    }
  }
  CFRelease(windowsArr);
}

- (NSString *)toString {
  return [self name];
}

@end
