//
//  TestConfigurationProfileChoice.m
//
//  The profile row at the top of the Settings window: which profile the pages edit, choosing another one (which only
//  queues it), and Apply and Restart making it the running one. Every test uses a temporary home folder, and
//  applying never restarts the app.
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

#import <XCTest/XCTest.h>
#import "ConfigurationFormView.h"
#import "ConfigurationProfileBar.h"
#import "ConfigurationWindowController.h"
#import "MWMConfigDocument.h"
#import "MWMProfiles.h"

@interface TestConfigurationProfileChoice : XCTestCase
@property (copy) NSString *home;
@property (strong) ConfigurationWindowController *controller;
@property (assign) NSUInteger relaunches;
@end

@implementation TestConfigurationProfileChoice

static NSString *const kDefault = @"version: 2\nbindings:\n  - key: r\n    action: relaunch\n";
static NSString *const kDesk = @"version: 2\nbindings:\n  - key: r\n    action: relaunch\n  - key: u\n    action: undo\n";

- (void)setUp {
  self.home = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:self.home withIntermediateDirectories:YES attributes:nil error:nil];
  [MWMProfiles setHomeDirectory:self.home];
  [MWMProfiles createNamed:@"default" text:kDefault error:nil];
  [MWMProfiles createNamed:@"desk" text:kDesk error:nil];
  self.relaunches = 0;
  self.controller = [[ConfigurationWindowController alloc] init];
  __weak TestConfigurationProfileChoice *weak = self;
  [self.controller setValue:^{ weak.relaunches++; } forKey:@"relaunchHandler"];
  [self.controller performSelector:@selector(loadFromDisk)];
  [self.controller.window orderFront:nil];   // a sheet needs a window that is on screen
}

- (void)tearDown {
  [self.controller setValue:nil forKey:@"editingProfile"];
  [self.controller.window orderOut:nil];
  [self.controller close];
  self.controller = nil;
  [MWMProfiles setHomeDirectory:nil];
  [[NSFileManager defaultManager] removeItemAtPath:self.home error:nil];
}

- (ConfigurationProfileBar *)bar { return [self.controller valueForKey:@"profileBar"]; }
- (ConfigurationFormView *)form { return [self.controller valueForKey:@"formView"]; }
- (void)choose:(NSString *)name { [self.controller performSelector:@selector(selectProfileNamed:) withObject:name]; }
- (NSUInteger)bindingCount { return [self.form.document.bindings count]; }

- (NSArray<NSString *> *)titlesOf:(NSMenu *)menu {
  NSMutableArray *titles = [NSMutableArray array];
  for (NSMenuItem *item in menu.itemArray) [titles addObject:item.isSeparatorItem ? @"-" : item.attributedTitle ? item.attributedTitle.string : item.title];
  return titles;
}

#pragma mark - The row

- (void)testTheWindowStartsOnTheRunningProfile {
  XCTAssertFalse([self bar].pending);
  XCTAssertEqual([self bindingCount], 1u);
  XCTAssertTrue([[self.controller valueForKey:@"configPath"] hasSuffix:@"default.mwm.yaml"]);
}

- (void)testTheDropdownListsTheProfilesAndManage {
  NSMenu *menu = [[self bar] profileMenu];
  NSArray *titles = [self titlesOf:menu];
  XCTAssertEqualObjects(titles[0], @"default   running");
  XCTAssertEqualObjects(titles[1], @"desk");
  XCTAssertEqualObjects(titles[2], @"-");
  XCTAssertEqualObjects(titles[3], @"Manage profiles…");
  XCTAssertEqual([menu itemAtIndex:0].state, NSControlStateValueOn, @"being edited");
  XCTAssertNotNil([menu itemAtIndex:3].image, @"the profile icon");
}

#pragma mark - Choosing only queues it

- (void)testChoosingAnotherProfileShowsItAndMarksItNotApplied {
  [self choose:@"desk"];
  XCTAssertTrue([self bar].pending);
  XCTAssertEqual([self bindingCount], 2u, @"the desk profile is on the pages now");
  XCTAssertTrue([[self.controller valueForKey:@"configPath"] hasSuffix:@"desk.mwm.yaml"]);
  XCTAssertEqualObjects([MWMProfiles activeName], @"default", @"nothing is applied yet");
  XCTAssertEqual(self.relaunches, 0u);
  XCTAssertEqualObjects([[[self bar] profileMenu] itemAtIndex:1].title, @"desk");
  XCTAssertEqual([[[self bar] profileMenu] itemAtIndex:1].state, NSControlStateValueOn);
}

- (void)testGoingBackToTheRunningProfileClearsIt {
  [self choose:@"desk"];
  [self choose:@"default"];
  XCTAssertFalse([self bar].pending);
  XCTAssertEqual([self bindingCount], 1u);
}

- (void)testApplyMakesItTheRunningProfileAndRestarts {
  [self choose:@"desk"];
  [self.controller performSelector:@selector(apply:) withObject:nil];
  XCTAssertEqualObjects([MWMProfiles activeName], @"desk");
  XCTAssertEqual(self.relaunches, 1u);
  XCTAssertFalse([self bar].pending);
}

- (void)testApplyWithoutAChoiceKeepsTheRunningProfile {
  [self.controller performSelector:@selector(apply:) withObject:nil];
  XCTAssertEqualObjects([MWMProfiles activeName], @"default");
  XCTAssertEqual(self.relaunches, 1u);
}

- (void)testTheMenuBarOpensSettingsOnThatProfileNotApplied {
  [self.controller showSettingsOnProfileNamed:@"desk"];
  XCTAssertTrue([self bar].pending);
  XCTAssertEqualObjects([MWMProfiles activeName], @"default");
  XCTAssertEqual(self.relaunches, 0u);
}

#pragma mark - Closing

- (void)testClosingWithoutAChoiceJustCloses {
  XCTAssertTrue([self.controller windowShouldClose:self.controller.window]);
}

- (void)testClosingWithAChoiceAsksFirst {
  [self choose:@"desk"];
  XCTAssertFalse([self.controller windowShouldClose:self.controller.window]);
  NSWindow *sheet = self.controller.window.attachedSheet;
  XCTAssertNotNil(sheet, @"it asks");
  [self.controller.window endSheet:sheet returnCode:NSAlertThirdButtonReturn];   // Cancel
  XCTAssertTrue([self bar].pending, @"the choice stays");
  XCTAssertEqual(self.relaunches, 0u);
}

- (void)testDiscardingTheChoiceGoesBackToTheRunningProfile {
  [self choose:@"desk"];
  [self.controller windowShouldClose:self.controller.window];
  [self.controller.window endSheet:self.controller.window.attachedSheet returnCode:NSAlertSecondButtonReturn];
  XCTAssertEqualObjects([MWMProfiles activeName], @"default");
  [self.controller performSelector:@selector(loadFromDisk)];
  XCTAssertFalse([self bar].pending);
}

- (void)testApplyingFromTheQuestionActivatesIt {
  [self choose:@"desk"];
  [self.controller windowShouldClose:self.controller.window];
  [self.controller.window endSheet:self.controller.window.attachedSheet returnCode:NSAlertFirstButtonReturn];
  XCTAssertEqualObjects([MWMProfiles activeName], @"desk");
  XCTAssertEqual(self.relaunches, 1u);
}

#pragma mark - Managing

- (void)testTheProfileButtonSitsAtTheLeftOfTheBottomBar {
  [self.controller.window layoutIfNeeded];
  NSView *statusBar = [self.controller valueForKey:@"bar"];
  XCTAssertTrue([[self bar] isDescendantOf:statusBar]);
  NSRect buttonFrame = [[self bar] convertRect:[[self bar] bounds] toView:nil];
  NSRect barFrame = [statusBar convertRect:[statusBar bounds] toView:nil];
  XCTAssertLessThan(NSMinX(buttonFrame) - NSMinX(barFrame), 30, @"first thing in the bar");
  XCTAssertFalse([[self bar] isHidden]);
  [[self form] setSelectedSection:ConfigurationFormSectionSnapshots];
  XCTAssertFalse([[self bar] isHidden], @"always visible, on the shared pages too");
}

- (void)testManageProfilesIsTheLastItemOfTheGeneralGroup {
  NSTableView *sidebar = [[self form] valueForKey:@"sidebar"];
  NSInteger last = [sidebar numberOfRows] - 1;
  [[self form] setSelectedSection:ConfigurationFormSectionProfiles];
  XCTAssertEqual([sidebar selectedRow], last);
}

- (void)testManageProfilesOpensTheProfilesPage {
  [[self bar].delegate profileBarWantsManage:[self bar]];
  XCTAssertEqual([self form].selectedSection, ConfigurationFormSectionProfiles);
}

@end
