//
//  JSOperationWrapper.m
//  Slate
//
//  Created by Jigish Patel on 1/25/13.
//  Copyright 2013 Jigish Patel. All rights reserved.
//

#import "JSOperationWrapper.h"
#import "Operation.h"
#import "JSController.h"
#import "SlateLogger.h"
#import "SlateConfig.h"

@implementation JSOperationWrapper

@synthesize op;

- (id)init {
  self = [super init];
  return self;
}

- (id)initWithOperation:(Operation *)_op {
  self = [self init];
  if (self) {
    @try {
      [self setOp:_op];
      if ([self op] == nil) { return nil; }
    } @catch (NSException *ex) {
      SlateLogger(@"   ERROR %@",[ex name]);
      NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
      [alert setMessageText:[ex name]];
      [alert setInformativeText:[ex reason]];
      if ([alert runModal] == NSAlertFirstButtonReturn) {
        SlateLogger(@"User selected exit");
        [NSApp terminate:nil];
      }
      return nil;
    }
  }
  return self;
}

- (id)initWithName:(NSString*)name options:(id)opts {
  self = [self init];
  if (self) {
    @try {
      [self setOp:[Operation operationWithName:name options:[[JSController getInstance] unmarshall:opts]]];
      if ([self op] == nil) { return nil; }
    } @catch (NSException *ex) {
      SlateLogger(@"   ERROR %@",[ex name]);
      NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
      [alert setMessageText:[ex name]];
      [alert setInformativeText:[ex reason]];
      if ([alert runModal] == NSAlertFirstButtonReturn) {
        SlateLogger(@"User selected exit");
        [NSApp terminate:nil];
      }
      return nil;
    }
  }
  return self;
}

- (id)initWithString:(NSString *)str {
  self = [self init];
  if (self) {
    @try {
      [self setOp:[Operation operationFromString:str]];
      if ([self op] == nil) { return nil; }
    } @catch (NSException *ex) {
      SlateLogger(@"   ERROR %@",[ex name]);
      NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
      [alert setMessageText:[ex name]];
      [alert setInformativeText:[ex reason]];
      if ([alert runModal] == NSAlertFirstButtonReturn) {
        SlateLogger(@"User selected exit");
        [NSApp terminate:nil];
      }
      return nil;
    }
  }
  return self;
}

- (BOOL)run {
  return [[self op] doOperation];
}

- (BOOL)doOperation {
  return [[self op] doOperation];
}

- (BOOL)doOperationWithAccessibilityWrapper:(AccessibilityWrapper *)aw screenWrapper:(ScreenWrapper *)sw {
  return [[self op] doOperationWithAccessibilityWrapper:aw screenWrapper:sw];
}

- (JSOperationWrapper *)dup:(id)opts {
  id unmarshalledOpts = [[JSController getInstance] unmarshall:opts];
  if (![unmarshalledOpts isKindOfClass:[NSDictionary class]]) {
    SlateLogger(@"   ERROR operation.dup parameter must be a hash");
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
    [alert setMessageText:@"ERROR: invalid dup options"];
    [alert setInformativeText:@"operation.dup parameter must be a hash"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
      SlateLogger(@"User selected exit");
      [NSApp terminate:nil];
    }
    return nil;
  }
  return [[JSOperationWrapper alloc] initWithOperation:[[self op] dup:unmarshalledOpts]];
}

+ (JSOperationWrapper *)operation:(NSString*)name options:(id)opts {
  return [[JSOperationWrapper alloc] initWithName:name options:opts];
}

+ (JSOperationWrapper *)operationFromString:(NSString *)opString {
  return [[JSOperationWrapper alloc] initWithString:opString];
}

@end
