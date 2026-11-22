//
//  JSInfoWrapper.m
//  Slate
//
//  Created by Jigish Patel on 1/21/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import "JSInfoWrapper.h"
#import "ScreenWrapper.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "JSWindowWrapper.h"
#import "JSApplicationWrapper.h"
#import "AccessibilityWrapper.h"
#import "JSController.h"
#import "RunningApplications.h"
#import "ExpressionPoint.h"
#import "JSScreenWrapper.h"
#import "JSWrapperUtils.h"

@implementation JSInfoWrapper

@synthesize sw, aw;

static JSInfoWrapper *_instance = nil;

+ (JSInfoWrapper *)getInstance {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _instance = [[[JSInfoWrapper class] alloc] init];
  });
  return _instance;
}

- (id)init {
  self = [super init];
  if (self) {
    [self setAw:[[AccessibilityWrapper alloc] init]];
    [self setSw:[[ScreenWrapper alloc] init]];
  }
  return self;
}

- (id)initWithAccessibilityWrapper:(AccessibilityWrapper *)_aw screenWrapper:(ScreenWrapper *)_sw {
  self = [super init];
  if (self) {
    [self setAw:_aw];
    [self setSw:_sw];
  }
  return self;
}

- (JSWindowWrapper *)window {
  return [[JSWindowWrapper alloc] initWithAccessibilityWrapper:aw screenWrapper:sw];
}

- (JSApplicationWrapper *)app {
  return [[JSApplicationWrapper alloc] initWithAccessibilityWrapper:aw screenWrapper:sw];
}

- (JSWindowWrapper *)wup:(id)point {
  return [self windowUnderPoint:point];
}

- (JSWindowWrapper *)windowUnderPoint:(id)point {
  id pointDict = [[JSController getInstance] unmarshall:point];
  NSValue *p = [JSWrapperUtils pointFromDict:pointDict aw:aw sw:sw];
  if (p == nil) { return nil; }
  AXUIElementRef win = [AccessibilityWrapper windowUnderPoint:[p pointValue]];
  if (win == nil || win == NULL) { return nil; }
  AXUIElementRef aRef = [AccessibilityWrapper applicationForElement:win];
  AccessibilityWrapper *_aw = [[AccessibilityWrapper alloc] initWithApp:aRef window:win];
  return [[JSWindowWrapper alloc] initWithAccessibilityWrapper:_aw screenWrapper:sw];
}

- (JSScreenWrapper *)sup:(id)point {
  return [self screenUnderPoint:point];
}

- (JSScreenWrapper *)screenUnderPoint:(id)point {
  id pointDict = [[JSController getInstance] unmarshall:point];
  NSValue *p = [JSWrapperUtils pointFromDict:pointDict aw:aw sw:sw];
  if (p == nil) { return nil; }
  return [[JSScreenWrapper alloc] initWithScreenId:[sw getScreenRefIdForPoint:[p pointValue]] screenWrapper:sw];
}

- (void)eapp:(id)func {
  [self eachApp:func];
}

- (void)eachApp:(id)func {
  for (NSRunningApplication *runningApp in [RunningApplications getInstance]) {
    JSApplicationWrapper *appWrapper = [[JSApplicationWrapper alloc] initWithRunningApplication:runningApp screenWrapper:sw];
    if ([func isKindOfClass:[JSValue class]]) {
      [(JSValue *)func callWithArguments:@[appWrapper]];
    } else {
      [[JSController getInstance] runFunction:func withArg:appWrapper];
    }
  }
}

- (JSScreenWrapper *)screen {
  NSPoint tl = [aw getCurrentTopLeft];
  NSSize size = [aw getCurrentSize];
  NSRect wRect = NSMakeRect(tl.x, tl.y, size.width, size.height);
  return [[JSScreenWrapper alloc] initWithScreenId:[sw getScreenRefIdForRect:wRect] screenWrapper:sw];
}

- (BOOL)rectoff:(id)rect {
  return [self isRectOffScreen:rect];
}

- (BOOL)isRectOffScreen:(id)rect {
  id rectDict = [[JSController getInstance] unmarshall:rect];
  NSValue *r = [JSWrapperUtils rectFromDict:rectDict aw:aw sw:sw];
  if (r == nil) { return NO; }

  return [sw isRectOffScreen:[r rectValue]];
}

- (BOOL)pntoff:(id)point {
  return [self isPointOffScreen:point];
}

- (BOOL)isPointOffScreen:(id)point {
  id pointDict = [[JSController getInstance] unmarshall:point];
  NSValue *p = [JSWrapperUtils pointFromDict:pointDict aw:aw sw:sw];
  if (p == nil) { return NO; }
  NSPoint _point = [p pointValue];
  return [sw isRectOffScreen:NSMakeRect(_point.x, _point.y, 0, 0)];
}

- (JSScreenWrapper *)screenr:(id)ref {
  return [self screenForRef:ref];
}

- (JSScreenWrapper *)screenForRef:(id)ref {
  NSString *stringRef = nil;
  if ([ref isKindOfClass:[NSString class]]) {
    stringRef = ref;
  } else if ([ref isKindOfClass:[NSNumber class]]) {
    stringRef = [ref stringValue];
  } else {
    return nil;
  }
  NSPoint tl = [aw getCurrentTopLeft];
  NSSize size = [aw getCurrentSize];
  NSRect wRect = NSMakeRect(tl.x, tl.y, size.width, size.height);
  return [[JSScreenWrapper alloc] initWithScreenId:[sw getScreenRefId:stringRef windowRect:wRect] screenWrapper:sw];
}

- (NSInteger)screenc {
  return [self screenCount];
}

- (NSInteger)screenCount {
  return [sw getScreenCount];
}

- (void)escreen:(id)func {
  [self eachScreen:func];
}

- (void)eachScreen:(id)func {
  for (NSInteger i = 0; i < [sw getScreenCount]; i++) {
    JSScreenWrapper *screenWrapper = [[JSScreenWrapper alloc] initWithScreenId:i screenWrapper:sw];
    if ([func isKindOfClass:[JSValue class]]) {
      [(JSValue *)func callWithArguments:@[screenWrapper]];
    } else {
      [[JSController getInstance] runFunction:func withArg:screenWrapper];
    }
  }
}

- (id)jsMethods {
  return @[
    @"window", @"app", @"screen", @"eachApp", @"eapp",
    @"windowUnderPoint", @"wup", @"isRectOffScreen", @"rectoff",
    @"isPointOffScreen", @"pntoff", @"screenForRef", @"screenr",
    @"screenCount", @"screenc", @"screenUnderPoint", @"sup",
    @"eachScreen", @"escreen"
  ];
}

@end
