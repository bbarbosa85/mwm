//
//  SnapshotOperation.m
//  Slate
//
//  Created by Jigish Patel on 2/28/12.
//  Copyright 2012 Jigish Patel. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see http://www.gnu.org/licenses

#import "SnapshotOperation.h"
#import "Constants.h"
#import "Snapshot.h"
#import "WindowSnapshot.h"
#import "MWMConfig.h"
#import "StringTokenizer.h"
#import "MWMLogger.h"
#import "RunningApplications.h"
#import "MWMDisplays.h"

@implementation SnapshotOperation

@synthesize name, saveToDisk, isStack, stackSize;

- (id)init {
  self = [super init];
  if (self) {
    saveToDisk = NO;
    isStack = NO;
    stackSize = [[MWMConfig getInstance] getIntegerConfig:SNAPSHOT_MAX_STACK_SIZE];
    [self setName:nil];
  }
  return self;
}

- (id)initWithName:(NSString *)theName options:(NSString *)_options {
  self = [self init];
  if (self) {
    [self setStackSize:[[MWMConfig getInstance] getIntegerConfig:SNAPSHOT_MAX_STACK_SIZE]];
    [self setName:theName];
    if (_options) {
      NSArray *optionsTokens = [_options componentsSeparatedByString:SEMICOLON];
      for (NSInteger i = 0; i < [optionsTokens count]; i++) {
        NSString *option = [optionsTokens objectAtIndex:i];
        if ([SAVE_TO_DISK isEqualToString:option]) {
          saveToDisk = YES;
        } else if ([STACK isEqualToString:option]) {
          isStack = YES;
        }
      }
    }
  }
  return self;
}

- (BOOL)doOperation {
  MWMLogger(@"----------------- Begin Snapshot Operation -----------------");
  BOOL success = [self doOperationWithAccessibilityWrapper:nil screenWrapper:nil];
  MWMLogger(@"-----------------  End Snapshot Operation  -----------------");
  return success;
}

// Where every open window is right now, with the screens connected, without keeping it anywhere.
+ (Snapshot *)captureSnapshot {
  Snapshot *snapshot = [[Snapshot alloc] init];
  NSMutableArray *screenDicts = [NSMutableArray array];
  for (MWMDisplay *display in [MWMDisplays connected]) {
    [screenDicts addObject:@{@"name": display.name ?: @"", @"width": @(display.width), @"height": @(display.height),
                             @"x": @(display.originX), @"y": @(display.originY), @"builtIn": @(display.builtIn)}];
  }
  snapshot.screens = screenDicts;
  for (NSRunningApplication *app in [RunningApplications getInstance]) {
    NSString *appName = [app localizedName];
    pid_t appPID = [app processIdentifier];
    MWMLogger(@"I see application '%@' with pid '%d'", appName, appPID);
    AXUIElementRef appRef = AXUIElementCreateApplication(appPID);
    CFArrayRef windowsArrRef = [AccessibilityWrapper windowsInApp:appRef];
    if (!windowsArrRef || CFArrayGetCount(windowsArrRef) == 0) continue;
    CFMutableArrayRef windowsArr = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, windowsArrRef);
    for (NSInteger i = 0; i < CFArrayGetCount(windowsArr); i++) {
      MWMLogger(@" Printing Window: %@", [AccessibilityWrapper getTitle:CFArrayGetValueAtIndex(windowsArr, i)]);
      NSString *title = [AccessibilityWrapper getTitle:CFArrayGetValueAtIndex(windowsArr, i)];
      if ([title isEqualToString:@""]) continue;
      AccessibilityWrapper *aw = [[AccessibilityWrapper alloc] initWithApp:appRef window:CFArrayGetValueAtIndex(windowsArr, i)];
      NSSize size = [aw getCurrentSize];
      NSPoint tl = [aw getCurrentTopLeft];
      [snapshot addWindow:[[WindowSnapshot alloc] initWithAppName:appName title:title topLeft:tl size:size] app:appName];
    }
  }
  return snapshot;
}

- (BOOL)doOperationWithAccessibilityWrapper:(AccessibilityWrapper *)iamnil screenWrapper:(ScreenWrapper *)iamalsonil {
  [self evalOptionsWithAccessibilityWrapper:iamnil screenWrapper:iamalsonil];
  Snapshot *snapshot = [SnapshotOperation captureSnapshot];
  [[MWMConfig getInstance] addSnapshot:snapshot name:name saveToDisk:saveToDisk isStack:isStack stackSize:stackSize];
  return YES;
}

- (BOOL)testOperation {
  return YES;
}

- (NSArray *)requiredOptions {
  return [NSArray arrayWithObject:OPT_NAME];
}

- (void)parseOption:(NSString *)_name value:(id)value {
  if (value == nil) { return; }
  if ([_name isEqualToString:OPT_NAME]) {
    if (![value isKindOfClass:[NSString class]]) {
      @throw([NSException exceptionWithName:[NSString stringWithFormat:@"Invalid %@", _name] reason:[NSString stringWithFormat:@"Invalid %@ '%@'", _name, value] userInfo:nil]);
      return;
    }
    [self setName:_name];
  } else if ([_name isEqualToString:OPT_SAVE]) {
    if (![value isKindOfClass:[NSValue class]] && ![value isKindOfClass:[NSString class]] && ![value isKindOfClass:[NSNumber class]]) {
      @throw([NSException exceptionWithName:[NSString stringWithFormat:@"Invalid %@", _name] reason:[NSString stringWithFormat:@"Invalid %@ '%@'", _name, value] userInfo:nil]);
      return;
    }
    [self setSaveToDisk:[value boolValue]];
  } else if ([_name isEqualToString:OPT_STACK]) {
    if (![value isKindOfClass:[NSValue class]] && ![value isKindOfClass:[NSString class]] && ![value isKindOfClass:[NSNumber class]]) {
      @throw([NSException exceptionWithName:[NSString stringWithFormat:@"Invalid %@", _name] reason:[NSString stringWithFormat:@"Invalid %@ '%@'", _name, value] userInfo:nil]);
      return;
    }
    [self setIsStack:[value boolValue]];
  }
}

+ (id)snapshotOperation {
  return [[SnapshotOperation alloc] init];
}

+ (id)snapshotOperationFromString:(NSString *)snapshotOperation {
  // snapshot name options
  NSMutableArray *tokens = [[NSMutableArray alloc] initWithCapacity:10];
  [StringTokenizer tokenize:snapshotOperation into:tokens maxTokens:3];

  if ([tokens count] < 2) {
    MWMLogger(@"ERROR: Invalid Parameters '%@'", snapshotOperation);
    @throw([NSException exceptionWithName:@"Invalid Parameters" reason:[NSString stringWithFormat:@"Invalid Parameters in '%@'. Snapshot operations require the following format: 'snapshot name options'", snapshotOperation] userInfo:nil]);
  }

  Operation *op = [[SnapshotOperation alloc] initWithName:[tokens objectAtIndex:1] options:([tokens count] > 2 ? [tokens objectAtIndex:2] : nil)];
  return op;
}

@end
