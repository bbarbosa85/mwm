//
//  TestMWMAction.m
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
#import "MWMAction.h"
#import "MWMConfigDocument.h"
#import "ConfigurationActionView.h"

@interface TestMWMAction : XCTestCase <ConfigurationActionViewDelegate>
@property (copy) NSString *changedAction;
@end

@implementation TestMWMAction

- (void)actionView:(ConfigurationActionView *)view didChangeAction:(NSString *)action {
  self.changedAction = action;
}

// What's written back is what was read, for every shape the app's own config uses.
- (void)testActionsRoundTrip {
  for (NSString *text in @[@"${full}", @"${lefthalf} ${monitor-samsung}", @"focus 'Google Chrome'", @"focus left", @"focus behind",
                           @"throw ${monitor-macbook} resize full", @"throw next", @"nudge +0 +10%", @"resize -5% +0",
                           @"push up bar-resize:screenSizeY/2", @"hint ASDFHJKL", @"grid padding:5 0:6,2 1:8,3", @"switch", @"relaunch",
                           @"chain push up | push right", @"shell 'ls'"]) {
    XCTAssertEqualObjects([[MWMAction parse:text] string], text, @"%@", text);
  }
}

- (void)testKindsAreRecognized {
  XCTAssertEqual([MWMAction parse:@"${lefthalf} ${monitor-a}"].kind, MWMActionKindMove);
  XCTAssertEqualObjects([MWMAction parse:@"${lefthalf} ${monitor-a}"].b, @"monitor-a");
  XCTAssertEqual([MWMAction parse:@"focus 'Finder'"].kind, MWMActionKindFocusApp);
  XCTAssertEqualObjects([MWMAction parse:@"focus \"Finder\""].a, @"Finder");
  XCTAssertEqual([MWMAction parse:@"focus left"].kind, MWMActionKindFocusDirection);
  XCTAssertEqual([MWMAction parse:@"nudge +0   -10%"].kind, MWMActionKindNudge);
  XCTAssertEqualObjects([MWMAction parse:@"nudge +0   -10%"].b, @"-10%");
  XCTAssertEqual([MWMAction parse:@"chain push up | push right"].kind, MWMActionKindCustom);
  XCTAssertEqual([MWMAction parse:@""].kind, MWMActionKindCustom);
}

- (void)testPositionPreview {
  CGRect rect;
  XCTAssertTrue([MWMAction previewForPositionText:@"move screenOriginX+screenSizeX/2;screenOriginY screenSizeX/2;screenSizeY" rect:&rect]);
  XCTAssertTrue(CGRectEqualToRect(rect, CGRectMake(0.5, 0, 0.5, 1)));
  XCTAssertTrue([MWMAction previewForPositionText:@"move screenOriginX+(2*screenSizeX/3);screenOriginY screenSizeX/3;screenSizeY" rect:&rect]);
  XCTAssertEqualWithAccuracy(rect.origin.x, 2.0 / 3, 0.001);
  XCTAssertFalse([MWMAction previewForPositionText:@"move windowTopLeftX;0 100;100" rect:&rect], @"depends on the window");
  XCTAssertFalse([MWMAction previewForPositionText:@"chain a | b" rect:&rect]);
}

- (void)testViewEditsAndReports {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:
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
  NSArray *kinds = [MWMAction allKinds];
  [view selectKindAtIndex:[kinds indexOfObject:@(MWMActionKindCustom)]];
  XCTAssertEqualObjects(view.action, @"${lefthalf}");
  [view selectKindAtIndex:[kinds indexOfObject:@(MWMActionKindFocusDirection)]];
  XCTAssertEqualObjects(self.changedAction, @"focus left");
}


- (void)testSnapshotActionsReadAndWriteTheEngineText {
  MWMAction *save = [MWMAction parse:@"snapshot work save-to-disk"];
  XCTAssertEqual(save.kind, MWMActionKindSnapshot);
  XCTAssertEqualObjects(save.a, @"work");
  XCTAssertEqualObjects(save.b, @"save-to-disk");
  XCTAssertEqualObjects([save string], @"snapshot work save-to-disk");
  XCTAssertEqualObjects([[MWMAction parse:@"snapshot work"] string], @"snapshot work");
  MWMAction *restore = [MWMAction parse:@"activate-snapshot work"];
  XCTAssertEqual(restore.kind, MWMActionKindRestoreSnapshot);
  XCTAssertEqualObjects([restore string], @"activate-snapshot work");
  // Options this window doesn't offer stay as written text.
  XCTAssertEqual([MWMAction parse:@"snapshot work save-to-disk;stack"].kind, MWMActionKindCustom);
  XCTAssertEqual([MWMAction parse:@"activate-snapshot work delete"].kind, MWMActionKindCustom);
  XCTAssertEqualObjects([[MWMAction actionOfKind:MWMActionKindSnapshot] string], @"snapshot  save-to-disk");
}

- (void)testMoveAndPushTextsAreWorkedOutOnASampleScreen {
  CGRect rect;
  BOOL applies = NO;
  NSString *error = nil;
  XCTAssertTrue([MWMAction getWindowRect:&rect forActionText:@"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY" applies:&applies error:&error]);
  XCTAssertTrue(applies);
  XCTAssertEqualWithAccuracy(rect.size.width, 0.5, 0.001);
  XCTAssertTrue([MWMAction getWindowRect:&rect forActionText:@"push right bar-resize:screenSizeX/4" applies:&applies error:&error]);
  XCTAssertEqualWithAccuracy(rect.origin.x, 0.75, 0.001);
  XCTAssertTrue([MWMAction getWindowRect:&rect forActionText:@"push up center" applies:&applies error:&error], @"a window is drawn for names that mean the window");
  XCTAssertFalse([MWMAction getWindowRect:&rect forActionText:@"push sideways" applies:&applies error:&error]);
  XCTAssertTrue(applies);
  XCTAssertTrue([error containsString:@"Push where"], @"%@", error);
  XCTAssertFalse([MWMAction getWindowRect:&rect forActionText:@"push left wobble" applies:&applies error:&error]);
  XCTAssertTrue([error containsString:@"isn't a push style"], @"%@", error);
  XCTAssertFalse([MWMAction getWindowRect:&rect forActionText:@"push left bar-resize:screenSizeX / 3" applies:&applies error:&error]);
  XCTAssertFalse([MWMAction getWindowRect:&rect forActionText:@"move screenSizeX / 2;0 10;10" applies:&applies error:&error]);
  XCTAssertTrue(applies);
  XCTAssertFalse([MWMAction getWindowRect:&rect forActionText:@"chain push up | push right" applies:&applies error:&error]);
  XCTAssertFalse(applies, @"only moves and pushes are checked");
  XCTAssertNil(error);
}

@end
