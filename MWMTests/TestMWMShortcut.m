//
//  TestMWMShortcut.m
//  Slate
//
//  Tests for key and modifier names, their display, and recording a shortcut.
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

#import <XCTest/XCTest.h>
#import "MWMShortcut.h"
#import "MWMConfigDocument.h"
#import "ConfigurationShortcutView.h"
#import "ConfigurationFormView.h"

@interface TestMWMShortcut : XCTestCase <ConfigurationShortcutViewDelegate>
@property (copy) NSString *recordedKey;
@property (copy) NSArray *recordedModifiers;
@end

@implementation TestMWMShortcut

- (void)shortcutView:(ConfigurationShortcutView *)view didRecordKey:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames {
  self.recordedKey = keyName;
  self.recordedModifiers = modifierNames;
}

- (void)testKeyNamesComeFromKeyCodes {
  XCTAssertEqualObjects([MWMShortcut keyNameForKeyCode:15], @"r");
  XCTAssertEqualObjects([MWMShortcut keyNameForKeyCode:123], @"left");
  XCTAssertEqualObjects([MWMShortcut keyNameForKeyCode:87], @"pad5");
  XCTAssertEqualObjects([MWMShortcut keyNameForKeyCode:105], @"f13");
  XCTAssertNil([MWMShortcut keyNameForKeyCode:200]);
}

- (void)testModifierNamesAreOrdered {
  XCTAssertEqualObjects([MWMShortcut modifierNamesFromString:@"cmd;ctrl,alt"], (@[@"ctrl", @"alt", @"cmd"]));
  XCTAssertEqualObjects([MWMShortcut modifierNamesFromString:@""], @[]);
  XCTAssertNil([MWMShortcut modifierNamesFromString:@"ctrl;hyper"]);
  NSEventModifierFlags flags = NSEventModifierFlagCommand | NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagFunction;
  XCTAssertEqualObjects([MWMShortcut modifierNamesFromFlags:flags], (@[@"ctrl", @"shift", @"cmd"]), @"fn is ignored");
  XCTAssertEqualObjects([MWMShortcut stringFromModifierNames:(@[@"ctrl", @"alt"])], @"ctrl;alt");
}

- (void)testDisplay {
  XCTAssertEqualObjects([MWMShortcut displayForKeyName:@"r"], @"R");
  XCTAssertEqualObjects([MWMShortcut displayForKeyName:@"left"], @"←");
  XCTAssertEqualObjects([MWMShortcut displayForKeyName:@"pad5"], @"Num 5");
  XCTAssertEqualObjects([MWMShortcut displayForKeyName:@"pad+"], @"Num +");
  XCTAssertEqualObjects([MWMShortcut displayForKeyName:@"f13"], @"F13");
  XCTAssertEqualObjects([MWMShortcut displayForKeyName:@"pageUp"], @"Page Up");
  XCTAssertEqualObjects([MWMShortcut symbolForModifierName:@"alt"], @"⌥");
}

- (void)testAliasMatchesNamedModifierGroups {
  NSArray *groups = @[[MWMConfigEntry entryWithName:@"hyper" value:@"ctrl;alt;cmd"],
                      [MWMConfigEntry entryWithName:@"other" value:@"${hyper};shift"]];
  XCTAssertEqualObjects([MWMShortcut aliasForModifierNames:(@[@"ctrl", @"alt", @"cmd"]) inEntries:groups], @"${hyper}");
  XCTAssertNil([MWMShortcut aliasForModifierNames:(@[@"alt", @"cmd"]) inEntries:groups]);
  XCTAssertNil([MWMShortcut aliasForModifierNames:@[] inEntries:groups]);
}

- (void)testIdentityIgnoresModifierOrder {
  XCTAssertEqualObjects([MWMShortcut identityForKey:@"r" modifiers:@"cmd;alt"], [MWMShortcut identityForKey:@"r" modifiers:@"alt,cmd"]);
  XCTAssertNotEqualObjects([MWMShortcut identityForKey:@"r" modifiers:@"cmd"], [MWMShortcut identityForKey:@"r" modifiers:@"alt"]);
  XCTAssertNil([MWMShortcut identityForKey:@"notakey" modifiers:@"cmd"]);
}

- (void)testRecordingReportsKeyAndModifiers {
  ConfigurationShortcutView *view = [[ConfigurationShortcutView alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
  view.delegate = self;
  [view finishRecordingWithKeyCode:87 modifierFlags:NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand];
  XCTAssertEqualObjects(self.recordedKey, @"pad5");
  XCTAssertEqualObjects(self.recordedModifiers, (@[@"ctrl", @"alt", @"cmd"]));

  self.recordedKey = nil;
  [view finishRecordingWithKeyCode:200 modifierFlags:0];
  XCTAssertNil(self.recordedKey, @"an unsupported key isn't recorded");
}

#pragma mark - In the form

static NSString *const kConfig =
  @"modifiers:\n  hyper: ctrl;alt;cmd\n"
  @"bindings:\n"
  @"  - key: r\n    mods: ${hyper}\n    action: relaunch\n"
  @"  - key: r\n    mods: cmd;alt;ctrl\n    action: undo\n"
  @"  - key: g\n    mods: cmd\n    action: grid\n";

- (NSTableView *)tableOf:(ConfigurationFormView *)form { return [form valueForKey:@"table"]; }

- (void)testRecordedShortcutKeepsNamedModifiersAndFlagsConflicts {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
  ConfigurationFormView *form = [[ConfigurationFormView alloc] initWithFrame:NSMakeRect(0, 0, 900, 500)];
  form.document = doc;
  form.selectedSection = ConfigurationFormSectionFeatures;
  NSTableView *table = [self tableOf:form];
  NSInteger column = [table columnWithIdentifier:@"shortcut"];
  XCTAssertGreaterThanOrEqual(column, 0);

  // Row 1 of Features is "grid" (undo is a window action). ctrl+alt+cmd is the ${hyper} group.
  NSView *cell = [table viewAtColumn:column row:1 makeIfNecessary:YES];
  ConfigurationShortcutView *view = (ConfigurationShortcutView *)[[cell subviews] firstObject];
  XCTAssertTrue([view isKindOfClass:[ConfigurationShortcutView class]]);
  [view finishRecordingWithKeyCode:5 modifierFlags:NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand];
  XCTAssertEqualObjects(doc.bindings[2].key, @"g");
  XCTAssertEqualObjects(doc.bindings[2].modifiers, @"${hyper}");

  // Without a matching group the names are written out.
  view = (ConfigurationShortcutView *)[[[table viewAtColumn:column row:1 makeIfNecessary:YES] subviews] firstObject];
  [view finishRecordingWithKeyCode:5 modifierFlags:NSEventModifierFlagShift | NSEventModifierFlagCommand];
  XCTAssertEqualObjects(doc.bindings[2].modifiers, @"shift;cmd");

  // Rows 0 and 1 are the same shortcut, written two ways.
  NSDictionary *groups = [form performSelector:NSSelectorFromString(@"bindingsByShortcut")];
  NSUInteger shared = 0;
  for (NSArray *same in [groups allValues]) if ([same count] > 1) shared++;
  XCTAssertEqual(shared, 1u, @"%@", groups);
}

- (void)testClickingRecordsInAWindow {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
  ConfigurationFormView *form = [[ConfigurationFormView alloc] initWithFrame:NSMakeRect(0, 0, 900, 500)];
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 500) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:form];
  form.document = doc;
  form.selectedSection = ConfigurationFormSectionFeatures;
  [window layoutIfNeeded];
  NSTableView *table = [self tableOf:form];
  NSView *cell = [table viewAtColumn:[table columnWithIdentifier:@"shortcut"] row:1 makeIfNecessary:YES];
  [window layoutIfNeeded];
  ConfigurationShortcutView *view = (ConfigurationShortcutView *)[[cell subviews] firstObject];
  XCTAssertGreaterThan(NSHeight([view frame]), 10, @"the cell has a height, so clicks reach it");
  NSMutableArray *texts = [NSMutableArray array];
  NSMutableArray *queue = [NSMutableArray arrayWithObject:view];
  while ([queue count] > 0) {
    NSView *next = queue[0];
    [queue removeObjectAtIndex:0];
    if ([next isKindOfClass:[NSTextField class]]) [texts addObject:[(NSTextField *)next stringValue]];
    [queue addObjectsFromArray:[next subviews]];
  }
  XCTAssertEqualObjects(texts, (@[@"⌘", @"G"]), @"key caps show the modifiers and the key");

  NSPoint inWindow = [view convertPoint:NSMakePoint(NSMidX([view bounds]), NSMidY([view bounds])) toView:nil];
  XCTAssertEqual([[window contentView] hitTest:inWindow], view);
  [window orderFront:nil];
  [window sendEvent:[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:inWindow modifierFlags:0 timestamp:0
                                  windowNumber:[window windowNumber] context:nil eventNumber:1 clickCount:1 pressure:1]];
  XCTAssertTrue(view.recording, @"clicking starts recording");
  // Typing while recording sets the shortcut; the row is "grid" (bindings[2]).
  [NSApp sendEvent:[NSEvent keyEventWithType:NSEventTypeFlagsChanged location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand timestamp:0
                                windowNumber:[window windowNumber] context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:55]];
  [NSApp sendEvent:[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagShift timestamp:0
                                windowNumber:[window windowNumber] context:nil characters:@"x" charactersIgnoringModifiers:@"x" isARepeat:NO keyCode:7]];
  XCTAssertFalse(view.recording, @"a key finishes the recording");
  XCTAssertEqualObjects(doc.bindings[2].key, @"x");
  XCTAssertEqualObjects(doc.bindings[2].modifiers, @"shift;cmd");
}

@end
