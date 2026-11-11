//
//  JSOperation.m
//  Slate
//
//  Created by Jigish Patel on 1/22/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import "JSOperation.h"
#import "JSController.h"
#import "AccessibilityWrapper.h"
#import "ScreenWrapper.h"
#import "SlateLogger.h"
#import "JSWindowWrapper.h"
#import "JSInfoWrapper.h"

@implementation JSOperation

@synthesize function;

- (id)init {
  self = [super init];
  if (self) {
    [self setOpName:@"js"];
  }
  return self;
}

- (id)initWithFunction:(JSValue *)_function {
  self = [super init];
  if (self) {
    [self setOpName:@"js"];
    [self setFunction:_function];
  }
  return self;
}

- (BOOL)doOperationWithAccessibilityWrapper:(AccessibilityWrapper *)aw screenWrapper:(ScreenWrapper *)sw {
  BOOL success = YES;
  [self evalOptionsWithAccessibilityWrapper:aw screenWrapper:sw];
  [[JSInfoWrapper getInstance] setSw:sw];
  [[JSInfoWrapper getInstance] setAw:aw];
  JSWindowWrapper *window = nil;
  if (aw != nil && [aw inited]) window = [[JSWindowWrapper alloc] initWithAccessibilityWrapper:aw screenWrapper:sw];
  [[JSController getInstance] runFunction:[self function] withArg:window];
  return success;
}

- (BOOL)testOperation {
  return YES;
}

- (BOOL)testOperationWithAccessibilityWrapper:(AccessibilityWrapper *)aw screenWrapper:(ScreenWrapper *)sw {
  return YES;
}

- (NSArray *)requiredOptions {
  return [NSArray array];
}

- (void)parseOption:(NSString *)name value:(id)value {
  // empty
}

+ (JSOperation *)jsOperationWithFunction:(JSValue *)function {
  return [[JSOperation alloc] initWithFunction:function];
}

@end
