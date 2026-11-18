//
//  TestSlateAction.m
//  Slate
//
//  Tests for reading actions into dropdown fields, writing them back, and the position preview.
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
#import "SlateAction.h"
#import "SlateConfigDocument.h"
#import "ConfigurationActionView.h"

@interface TestSlateAction : XCTestCase <ConfigurationActionViewDelegate>
@property (copy) NSString *changedAction;
@end

@implementation TestSlateAction

- (void)actionView:(ConfigurationActionView *)view didChangeAction:(NSString *)action {
  self.changedAction = action;
}

// What's written back is what was read, for every shape the app's own config uses.
- (void)testActionsRoundTrip {
  for (NSString *text in @[@"${full}", @"${lefthalf} ${monitor-samsung}", @"focus 'Google Chrome'", @"focus left", @"focus behind",
                           @"throw ${monitor-macbook} resize full", @"throw next", @"nudge +0 +10%", @"resize -5% +0",
                           @"push up bar-resize:screenSizeY/2", @"hint ASDFHJKL", @"grid padding:5 0:6,2 1:8,3", @"switch", @"relaunch",
                           @"chain push up | push right", @"shell 'ls'"]) {
    XCTAssertEqualObjects([[SlateAction parse:text] string], text, @"%@", text);
  }
}

- (void)testKindsAreRecognized {
  XCTAssertEqual([SlateAction parse:@"${lefthalf} ${monitor-a}"].kind, SlateActionKindMove);
  XCTAssertEqualObjects([SlateAction parse:@"${lefthalf} ${monitor-a}"].b, @"monitor-a");
  XCTAssertEqual([SlateAction parse:@"focus 'Finder'"].kind, SlateActionKindFocusApp);
  XCTAssertEqualObjects([SlateAction parse:@"focus \"Finder\""].a, @"Finder");
  XCTAssertEqual([SlateAction parse:@"focus left"].kind, SlateActionKindFocusDirection);
  XCTAssertEqual([SlateAction parse:@"nudge +0   -10%"].kind, SlateActionKindNudge);
  XCTAssertEqualObjects([SlateAction parse:@"nudge +0   -10%"].b, @"-10%");
  XCTAssertEqual([SlateAction parse:@"chain push up | push right"].kind, SlateActionKindCustom);
  XCTAssertEqual([SlateAction parse:@""].kind, SlateActionKindCustom);
}

- (void)testPositionPreview {
  CGRect rect;
  XCTAssertTrue([SlateAction previewForPositionText:@"move screenOriginX+screenSizeX/2;screenOriginY screenSizeX/2;screenSizeY" rect:&rect]);
  XCTAssertTrue(CGRectEqualToRect(rect, CGRectMake(0.5, 0, 0.5, 1)));
  XCTAssertTrue([SlateAction previewForPositionText:@"move screenOriginX+(2*screenSizeX/3);screenOriginY screenSizeX/3;screenSizeY" rect:&rect]);
  XCTAssertEqualWithAccuracy(rect.origin.x, 2.0 / 3, 0.001);
  XCTAssertFalse([SlateAction previewForPositionText:@"move windowTopLeftX;0 100;100" rect:&rect], @"depends on the window");
  XCTAssertFalse([SlateAction previewForPositionText:@"chain a | b" rect:&rect]);
}

- (void)testViewEditsAndReports {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:
      @"positions:\n  full: \"move screenOriginX;screenOriginY screenSizeX;screenSizeY\"\n  lefthalf: \"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY\"\n"
       "monitors:\n  monitor-a: \"0\"\n  monitor-a-size: \"5120x1440\"\n" error:nil];
  ConfigurationActionView *view = [[ConfigurationActionView alloc] initWithFrame:NSMakeRect(0, 0, 480, 24)];
  view.delegate = self;
  [view setAction:@"${full}" positions:doc.positions monitors:doc.monitors];
  XCTAssertEqualObjects(view.action, @"${full}");

  // Picking another position changes the action.
  NSPopUpButton *position = nil;
  for (NSView *v in [(NSStackView *)[[view subviews] firstObject] arrangedSubviews]) {
    if ([v isKindOfClass:[NSPopUpButton class]] && ![[v identifier] isEqualToString:@"kind"] && position == nil) position = (NSPopUpButton *)v;
  }
  XCTAssertNotNil(position);
  XCTAssertEqual([position numberOfItems], 2);
  [position selectItemAtIndex:1];
  [NSApp sendAction:[position action] to:[position target] from:position];
  XCTAssertEqualObjects(self.changedAction, @"${lefthalf}");

  // Switching to Advanced… keeps the text, and other kinds start with sensible values.
  NSArray *kinds = [SlateAction allKinds];
  [view selectKindAtIndex:[kinds indexOfObject:@(SlateActionKindCustom)]];
  XCTAssertEqualObjects(view.action, @"${lefthalf}");
  [view selectKindAtIndex:[kinds indexOfObject:@(SlateActionKindFocusDirection)]];
  XCTAssertEqualObjects(self.changedAction, @"focus left");
}


- (void)testSnapshotActionsReadAndWriteTheEngineText {
  SlateAction *save = [SlateAction parse:@"snapshot work save-to-disk"];
  XCTAssertEqual(save.kind, SlateActionKindSnapshot);
  XCTAssertEqualObjects(save.a, @"work");
  XCTAssertEqualObjects(save.b, @"save-to-disk");
  XCTAssertEqualObjects([save string], @"snapshot work save-to-disk");
  XCTAssertEqualObjects([[SlateAction parse:@"snapshot work"] string], @"snapshot work");
  SlateAction *restore = [SlateAction parse:@"activate-snapshot work"];
  XCTAssertEqual(restore.kind, SlateActionKindRestoreSnapshot);
  XCTAssertEqualObjects([restore string], @"activate-snapshot work");
  // Options this window doesn't offer stay as written text.
  XCTAssertEqual([SlateAction parse:@"snapshot work save-to-disk;stack"].kind, SlateActionKindCustom);
  XCTAssertEqual([SlateAction parse:@"activate-snapshot work delete"].kind, SlateActionKindCustom);
  XCTAssertEqualObjects([[SlateAction actionOfKind:SlateActionKindSnapshot] string], @"snapshot  save-to-disk");
}

@end
