//
//  TestSlateDisplays.m
//  Slate
//
//  Tests for screen roles: matching displays, numbering identical ones, and
//  turning a role into a screen reference when the config loads.
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
#import "SlateDisplays.h"
#import "SlateConfigDocument.h"
#import "ConfigurationDisplaysView.h"

@interface TestSlateDisplays : XCTestCase
@property (strong) NSArray<SlateDisplay *> *dock;   // built-in + two identical external screens
@end

@implementation TestSlateDisplays

- (void)setUp {
  // Listed out of order on purpose: roles go by position, not by list order.
  SlateDisplay *right = [SlateDisplay displayNamed:@"Samsung S27" width:2560 height:1440 builtIn:NO x:1800 + 2560 y:0];
  SlateDisplay *builtIn = [SlateDisplay displayNamed:@"Built-in Retina Display" width:1800 height:1169 builtIn:YES x:0 y:0];
  SlateDisplay *left = [SlateDisplay displayNamed:@"Samsung S27" width:2560 height:1440 builtIn:NO x:1800 y:0];
  self.dock = @[right, builtIn, left];
  [SlateDisplays setConnectedOverride:self.dock];
}

- (void)tearDown {
  [SlateDisplays setConnectedOverride:nil];
}

- (void)testBuiltInRole {
  SlateDisplay *found = [SlateDisplays displayForRole:@"display: built-in" in:self.dock];
  XCTAssertTrue(found.builtIn);
  XCTAssertEqualObjects([SlateDisplays roleForDisplay:found in:self.dock], @"display: built-in");
}

- (void)testIdenticalScreensAreNumberedLeftToRight {
  SlateDisplay *first = [SlateDisplays displayForRole:@"display: Samsung S27 2560x1440 #1" in:self.dock];
  SlateDisplay *second = [SlateDisplays displayForRole:@"display: Samsung S27 2560x1440 #2" in:self.dock];
  XCTAssertEqual(first.originX, 1800);
  XCTAssertEqual(second.originX, 1800 + 2560);
  XCTAssertEqualObjects([SlateDisplays roleForDisplay:second in:self.dock], @"display: Samsung S27 2560x1440 #2");
  XCTAssertNil([SlateDisplays displayForRole:@"display: Samsung S27 2560x1440 #3" in:self.dock]);
}

- (void)testAUniqueScreenNeedsNoNumber {
  NSArray *undocked = @[self.dock[1], self.dock[2]];
  SlateDisplay *only = undocked[1];
  XCTAssertEqualObjects([SlateDisplays roleForDisplay:only in:undocked], @"display: Samsung S27 2560x1440");
  XCTAssertEqual([SlateDisplays displayForRole:@"display: Samsung S27" in:undocked], only, @"size is optional");
  XCTAssertEqual([SlateDisplays displayForRole:@"display: Samsung S27 #1" in:undocked], only);
  XCTAssertNil([SlateDisplays displayForRole:@"display: Samsung S27 3840x2160" in:undocked], @"another size is another screen");
}

- (void)testRolesBecomeReferencesAndMissingScreensFallBack {
  XCTAssertEqualObjects([SlateDisplays referenceForValue:@"display: built-in" displays:self.dock], @"ordered:0");
  XCTAssertEqualObjects([SlateDisplays referenceForValue:@"display: Samsung S27 2560x1440 #2" displays:self.dock], @"ordered:2");
  XCTAssertEqualObjects([SlateDisplays referenceForValue:@"display: Dell U2723QE" displays:self.dock], @"ordered:99", @"not connected: no such screen, so the current one is used");
  XCTAssertEqualObjects([SlateDisplays referenceForValue:@"0" displays:self.dock], @"0", @"old numeric references are left alone");
  XCTAssertEqualObjects([SlateDisplays referenceForValue:@"5120x1440" displays:self.dock], @"5120x1440");
}

- (void)testNamesAreSuggestedFromTheModel {
  XCTAssertEqualObjects([SlateDisplays suggestedNameForDisplay:self.dock[1] in:self.dock], @"monitor-built-in");
  XCTAssertEqualObjects([SlateDisplays suggestedNameForDisplay:self.dock[2] in:self.dock], @"monitor-samsung-s27-1");
  XCTAssertEqualObjects([SlateDisplays suggestedNameForDisplay:self.dock[0] in:self.dock], @"monitor-samsung-s27-2");
  NSArray *undocked = @[self.dock[1], self.dock[2]];
  XCTAssertEqualObjects([SlateDisplays suggestedNameForDisplay:self.dock[2] in:undocked], @"monitor-samsung-s27");
}

- (void)testOldNumbersPointAtDisplays {
  XCTAssertTrue([SlateDisplays displayForNumber:0 leftToRight:YES in:self.dock].builtIn);
  XCTAssertEqual([SlateDisplays displayForNumber:2 leftToRight:YES in:self.dock].originX, 1800 + 2560);
  XCTAssertEqual([SlateDisplays displayForNumber:0 leftToRight:NO in:self.dock].originX, 1800 + 2560, @"listed order when not sorting");
  XCTAssertNil([SlateDisplays displayForNumber:3 leftToRight:YES in:self.dock]);
}

- (void)testTheConfigLoadsRolesAsReferences {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:
      @"monitors:\n  desk-right: \"display: Samsung S27 2560x1440 #2\"\n  gone: \"display: Dell U2723QE\"\n  old: \"1\"\n"
       "positions:\n  half: move 0;0 1;1\n"
       "bindings:\n  - key: a\n    mods: ctrl\n    action: ${half} ${desk-right}\n"
       "  - key: b\n    mods: ctrl\n    action: throw ${gone}\n"
       "  - key: c\n    mods: ctrl\n    action: throw ${old}\n" error:nil];
  NSError *error = nil;
  SlateResolvedConfig *resolved = [doc resolve:&error];
  XCTAssertNotNil(resolved, @"%@", error);
  XCTAssertEqualObjects(resolved.bindings[0].action, @"move 0;0 1;1 ordered:2");
  XCTAssertEqualObjects(resolved.bindings[1].action, @"throw ordered:99");
  XCTAssertEqualObjects(resolved.bindings[2].action, @"throw 1");
}

#pragma mark - Displays page

- (NSArray *)subviewsOf:(NSView *)view ofClass:(Class)cls {
  NSMutableArray *found = [NSMutableArray array];
  if ([view isKindOfClass:cls]) [found addObject:view];
  for (NSView *child in [view subviews]) [found addObjectsFromArray:[self subviewsOf:child ofClass:cls]];
  return found;
}

- (ConfigurationDisplaysView *)pageForDocument:(SlateConfigDocument *)doc {
  ConfigurationDisplaysView *page = [[ConfigurationDisplaysView alloc] initWithFrame:NSMakeRect(0, 0, 900, 600)];
  page.document = doc;
  return page;
}

- (NSButton *)buttonTitled:(NSString *)title in:(NSView *)root {
  for (NSButton *button in [self subviewsOf:root ofClass:[NSButton class]]) if ([[button title] isEqualToString:title]) return button;
  return nil;
}

- (void)testDetectingAddsEveryScreenOnce {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:@"monitors:\n  existing: \"0\"\n" error:nil];
  ConfigurationDisplaysView *page = [self pageForDocument:doc];
  [page detectAgain];
  NSArray *names = [doc.monitors valueForKey:@"name"];
  XCTAssertEqualObjects(names, (@[@"existing", @"monitor-built-in", @"monitor-samsung-s27-1", @"monitor-samsung-s27-2"]));
  XCTAssertEqualObjects([doc.monitors[3].value description], @"display: Samsung S27 2560x1440 #2");
  [page detectAgain];
  XCTAssertEqual([doc.monitors count], 4u, @"nothing new to add the second time");
}

- (void)testPageShowsUnnamedScreensAndAddsOneAtATime {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:@"monitors:\n  desk-left: \"display: Samsung S27 2560x1440 #1\"\n" error:nil];
  ConfigurationDisplaysView *page = [self pageForDocument:doc];
  NSButton *add = [self buttonTitled:@"Add" in:page];
  XCTAssertNotNil(add, @"the built-in and the second Samsung have no name yet");
  XCTAssertEqual([[self subviewsOf:page ofClass:[NSButton class]] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title == 'Add'"]].count, 2u);
  [NSApp sendAction:[add action] to:[add target] from:add];
  XCTAssertEqual([doc.monitors count], 2u);
  XCTAssertEqual([[[self subviewsOf:page ofClass:[NSButton class]] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title == 'Add'"]] count], 1u);
}

- (void)testScreensThatAreGoneStayAsRows {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:@"monitors:\n  office: \"display: Dell U2723QE 3840x2160\"\n" error:nil];
  ConfigurationDisplaysView *page = [self pageForDocument:doc];
  BOOL found = NO;
  for (NSTextField *label in [self subviewsOf:page ofClass:[NSTextField class]]) if ([[label stringValue] isEqualToString:@"Not connected"]) found = YES;
  XCTAssertTrue(found);
  XCTAssertEqual([doc.monitors count], 1u, @"opening the page never changes the file");
}

- (void)testEveryRowShowsAScreenAndASize {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:
      @"monitors:\n  here: \"display: Samsung S27 2560x1440 #1\"\n  gone: \"display: Dell U2723QE 3840x2160\"\n  gone2: \"display: Old Monitor\"\n"
       "  number: \"0\"\n  stale: \"7\"\n  size-ref: 5120x1440\n" error:nil];
  NSMutableArray *texts = [NSMutableArray array];
  for (NSTextField *label in [self subviewsOf:[self pageForDocument:doc] ofClass:[NSTextField class]]) [texts addObject:[label stringValue]];
  for (NSString *expected in @[@"Samsung S27", @"2560x1440", @"Dell U2723QE", @"3840x2160", @"Old Monitor", @"size unknown",
                               @"Built-in display", @"1800x1169", @"Any screen", @"5120x1440", @"No connected screen"]) {
    XCTAssertTrue([texts containsObject:expected], @"%@", expected);
  }
  XCTAssertEqual([[texts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 'Size'"]] count], 2u, @"a header over each list");
}

- (void)testRenamingNeedsANewName {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:
      @"monitors:\n  a: \"display: built-in\"\n  b: \"display: Samsung S27 2560x1440 #1\"\npositions:\n  half: move 0;0 1;1\n" error:nil];
  ConfigurationDisplaysView *page = [self pageForDocument:doc];
  NSTextField *field = nil;
  for (NSTextField *f in [self subviewsOf:page ofClass:[NSTextField class]]) if ([[f identifier] isEqualToString:@"a"]) field = f;
  [field setStringValue:@"half"];  // taken by a position
  [NSApp sendAction:[field action] to:[field target] from:field];
  XCTAssertEqualObjects(doc.monitors[0].name, @"a");
  [field setStringValue:@"laptop"];
  [NSApp sendAction:[field action] to:[field target] from:field];
  XCTAssertEqualObjects(doc.monitors[0].name, @"laptop");
}

- (void)testAnOldNumberCanBecomeARole {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:@"monitors:\n  macbook: \"0\"\n  samsung-size: 5120x1440\n" error:nil];
  ConfigurationDisplaysView *page = [self pageForDocument:doc];
  NSButton *convert = [self buttonTitled:@"Use role" in:page];
  XCTAssertNotNil(convert, @"0 is a screen that's connected");
  [NSApp sendAction:[convert action] to:[convert target] from:convert];
  XCTAssertEqualObjects([doc.monitors[0].value description], @"display: built-in");
  XCTAssertEqualObjects([doc.monitors[1].value description], @"5120x1440", @"sizes are left as they are");
  XCTAssertNil([self buttonTitled:@"Use role" in:page]);
}

@end
