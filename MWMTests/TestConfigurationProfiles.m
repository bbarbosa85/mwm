//
//  TestConfigurationProfiles.m
//
//  The Profiles page. Every test uses a temporary home folder and doesn't ask anything.
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
#import "ConfigurationProfilesView.h"
#import "MWMComponents.h"
#import "MWMProfiles.h"

@interface TestConfigurationProfiles : XCTestCase <ConfigurationProfilesViewDelegate>
@property (copy) NSString *home;
@property (copy) NSString *switchedTo;
@property (assign) NSUInteger renamedActive;
@end

@implementation TestConfigurationProfiles

- (void)setUp {
  self.home = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:self.home withIntermediateDirectories:YES attributes:nil error:nil];
  [MWMProfiles setHomeDirectory:self.home];
  self.switchedTo = nil;
  self.renamedActive = 0;
}

- (void)tearDown {
  [MWMProfiles setHomeDirectory:nil];
  [[NSFileManager defaultManager] removeItemAtPath:self.home error:nil];
}

- (void)profilesView:(ConfigurationProfilesView *)view useProfileNamed:(NSString *)name { self.switchedTo = name; }
- (void)profilesView:(ConfigurationProfilesView *)view didRenameProfileNamed:(NSString *)name to:(NSString *)newName { self.renamedActive++; }

- (ConfigurationProfilesView *)page {
  ConfigurationProfilesView *page = [[ConfigurationProfilesView alloc] initWithFrame:NSMakeRect(0, 0, 840, 640)];
  page.interactive = NO;
  page.delegate = self;
  return page;
}

- (NSView *)viewIn:(NSView *)root identifier:(NSString *)identifier {
  if ([root.identifier isEqualToString:identifier]) return root;
  for (NSView *sub in root.subviews) { NSView *found = [self viewIn:sub identifier:identifier]; if (found) return found; }
  return nil;
}

- (void)make:(NSString *)name { [MWMProfiles createNamed:name text:@"version: 2\n" error:nil]; }

- (void)testAnEmptyFolderSaysSoAndOffersANewOne {
  ConfigurationProfilesView *page = [self page];
  XCTAssertNotNil([self viewIn:page identifier:@"profile-empty"]);
  XCTAssertNotNil([self viewIn:page identifier:@"profile-add"]);
}

- (void)testEachProfileIsACardAndTheActiveOneIsMarked {
  [self make:@"default"];
  [self make:@"desk"];
  ConfigurationProfilesView *page = [self page];
  XCTAssertNotNil([self viewIn:page identifier:@"profile-default"]);
  XCTAssertNotNil([self viewIn:page identifier:@"profile-desk"]);
  NSView *activeCard = [self viewIn:page identifier:@"profile-default"];
  XCTAssertNotNil([self viewIn:activeCard identifier:@"profile-active"]);
  XCTAssertNil([self viewIn:[self viewIn:page identifier:@"profile-desk"] identifier:@"profile-active"]);
  XCTAssertFalse([(NSButton *)[self viewIn:page identifier:@"use-default"] isEnabled], @"already active");
  XCTAssertTrue([(NSButton *)[self viewIn:page identifier:@"use-desk"] isEnabled]);
  XCTAssertFalse([(NSButton *)[self viewIn:page identifier:@"delete-default"] isEnabled], @"the active one can't be deleted");
  XCTAssertTrue([(NSButton *)[self viewIn:page identifier:@"delete-desk"] isEnabled]);
}

- (void)testTheOnlyProfileCantBeDeleted {
  [self make:@"default"];
  XCTAssertFalse([(NSButton *)[self viewIn:[self page] identifier:@"delete-default"] isEnabled]);
}

- (void)testUseAsksTheWindowToEditThatProfile {
  [self make:@"default"];
  [self make:@"desk"];
  ConfigurationProfilesView *page = [self page];
  [page useNamed:@"default"];
  XCTAssertNil(self.switchedTo, @"it's the one being edited");
  [page useNamed:@"desk"];
  XCTAssertEqualObjects(self.switchedTo, @"desk");
}

- (void)testAProfileChosenButNotAppliedIsMarkedAndCantBeDeleted {
  [self make:@"default"];
  [self make:@"desk"];
  [self make:@"couch"];
  ConfigurationProfilesView *page = [self page];
  page.editingName = @"desk";
  XCTAssertNotNil([self viewIn:[self viewIn:page identifier:@"profile-desk"] identifier:@"profile-pending"], @"editing, not applied");
  XCTAssertNotNil([self viewIn:[self viewIn:page identifier:@"profile-default"] identifier:@"profile-active"], @"still the running one");
  XCTAssertFalse([(NSButton *)[self viewIn:page identifier:@"use-desk"] isEnabled], @"it is the one being edited");
  XCTAssertTrue([(NSButton *)[self viewIn:page identifier:@"use-default"] isEnabled], @"going back to the running one");
  XCTAssertFalse([(NSButton *)[self viewIn:page identifier:@"delete-desk"] isEnabled], @"open in the window");
  XCTAssertTrue([(NSButton *)[self viewIn:page identifier:@"delete-couch"] isEnabled]);
  [page deleteNamed:@"desk"];
  XCTAssertNotNil(page.problem);
  XCTAssertTrue([MWMProfiles existsNamed:@"desk"]);
}

#pragma mark - Adding

- (void)testAddProfileOpensTheThreeSourcesAndBackReturns {
  [self make:@"default"];
  ConfigurationProfilesView *page = [self page];
  XCTAssertNil([self viewIn:page identifier:@"profile-source-running"]);
  [(NSButton *)[self viewIn:page identifier:@"profile-add"] performClick:nil];
  XCTAssertEqual(page.mode, ConfigurationProfilesModeSource);
  for (NSString *identifier in @[@"profile-source-running", @"profile-source-duplicate", @"profile-source-file"]) XCTAssertNotNil([self viewIn:page identifier:identifier], @"%@", identifier);
  XCTAssertNil([self viewIn:page identifier:@"profile-default"], @"the list steps aside");
  [(NSButton *)[self viewIn:page identifier:@"profile-add-back"] performClick:nil];
  XCTAssertEqual(page.mode, ConfigurationProfilesModeList);
  XCTAssertNotNil([self viewIn:page identifier:@"profile-default"]);
}

- (void)testFromWhatsRunningSuggestsANameAndSummarisesIt {
  [self make:@"default"];
  [MWMProfiles writeText:@"version: 2\nbindings:\n  - group: Windows\n    key: left\n    action: relaunch\n  - group: Apps\n    key: f\n    action: relaunch\n" named:@"default" error:nil];
  ConfigurationProfilesView *page = [self page];
  [page beginAdd];
  [(NSButton *)[self viewIn:page identifier:@"profile-source-running"] performClick:nil];
  XCTAssertEqual(page.mode, ConfigurationProfilesModeName);
  XCTAssertEqualObjects([page.nameField stringValue], @"default copy");
  XCTAssertNotNil([self viewIn:page identifier:@"profile-draft-summary"]);
  XCTAssertTrue([[(NSTextField *)[self viewIn:page identifier:@"profile-draft-groups"] stringValue] containsString:@"Windows, Apps"]);
  XCTAssertTrue([[(NSTextField *)[self viewIn:page identifier:@"profile-draft-from"] stringValue] containsString:@"default (running)"]);
}

- (void)testCreatingWritesTheCopyUnderTheChosenName {
  [self make:@"default"];
  [MWMProfiles writeText:@"version: 2\n# mine\n" named:@"default" error:nil];
  ConfigurationProfilesView *page = [self page];
  [page beginDraftFromRunning];
  [page createDraftNamed:@"  couch  "];
  XCTAssertNil(page.problem);
  XCTAssertEqual(page.mode, ConfigurationProfilesModeList);
  XCTAssertEqualObjects([MWMProfiles names], (@[@"couch", @"default"]));
  XCTAssertTrue([[NSString stringWithContentsOfFile:[MWMProfiles pathForName:@"couch"] encoding:NSUTF8StringEncoding error:nil] containsString:@"# mine"]);
}

- (void)testTheCopyIconOnACardGoesStraightToNamingAndBackLeavesToTheList {
  [self make:@"default"];
  [self make:@"desk"];
  ConfigurationProfilesView *page = [self page];
  [(NSButton *)[self viewIn:page identifier:@"duplicate-desk"] performClick:nil];
  XCTAssertEqual(page.mode, ConfigurationProfilesModeName);
  XCTAssertEqualObjects([page.nameField stringValue], @"desk copy");
  [page goBack];
  XCTAssertEqual(page.mode, ConfigurationProfilesModeList);
}

- (void)testDuplicateOnePicksFromTheListFirst {
  [self make:@"default"];
  [self make:@"desk"];
  ConfigurationProfilesView *page = [self page];
  [page beginAdd];
  [(NSButton *)[self viewIn:page identifier:@"profile-source-duplicate"] performClick:nil];
  XCTAssertEqual(page.mode, ConfigurationProfilesModePickDuplicate);
  [(NSButton *)[self viewIn:page identifier:@"profile-copy-desk"] performClick:nil];
  XCTAssertEqual(page.mode, ConfigurationProfilesModeName);
  XCTAssertEqualObjects(page.draftFrom, @"desk");
  [page goBack];
  XCTAssertEqual(page.mode, ConfigurationProfilesModeSource);
}

- (void)testFromAFileNamesItAfterTheFileAndRefusesOneThatCantBeRead {
  NSString *good = [self.home stringByAppendingPathComponent:@"starter.mwm.yml"];
  [@"version: 2\nbindings:\n  - key: r\n    action: relaunch\n" writeToFile:good atomically:YES encoding:NSUTF8StringEncoding error:nil];
  ConfigurationProfilesView *page = [self page];
  [page beginDraftFromFileAtPath:good];
  XCTAssertEqual(page.mode, ConfigurationProfilesModeName);
  XCTAssertEqualObjects([page.nameField stringValue], @"starter");
  [page createDraftNamed:@"starter"];
  XCTAssertEqualObjects([MWMProfiles names], (@[@"starter"]));
  NSString *bad = [self.home stringByAppendingPathComponent:@"broken.mwm.yml"];
  [@"bindings: [unclosed\n" writeToFile:bad atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [page beginAdd];
  [page beginDraftFromFileAtPath:bad];
  XCTAssertNotNil(page.problem);
  XCTAssertEqual(page.mode, ConfigurationProfilesModeSource, @"stays on the source step");
  XCTAssertEqual([[MWMProfiles names] count], 1u);
}

- (void)testATakenOrEmptyNameShowsAProblemAndStaysOnTheNameStep {
  [self make:@"default"];
  ConfigurationProfilesView *page = [self page];
  [page beginDraftFromRunning];
  [page createDraftNamed:@"DEFAULT"];
  XCTAssertEqualObjects(page.problem, @"A profile with that name already exists.");
  XCTAssertEqual(page.mode, ConfigurationProfilesModeName);
  XCTAssertNotNil([self viewIn:page identifier:@"profile-problem"]);
  [page createDraftNamed:@"   "];
  XCTAssertEqualObjects(page.problem, @"Give the profile a name.");
  [page cancelAdd];
  XCTAssertNil(page.problem);
  XCTAssertEqual(page.mode, ConfigurationProfilesModeList);
}

- (void)testWithNoProfileTheRunningSourceStartsFromTheDefaults {
  ConfigurationProfilesView *page = [self page];
  [page beginDraftFromRunning];
  XCTAssertEqual(page.mode, ConfigurationProfilesModeName);
  XCTAssertEqualObjects(page.draftFrom, @"the defaults");
}

- (void)testTheNameFieldIsRoomyAndHasACompactSize {
  MWMNameField *field = [MWMNameField nameFieldWithPlaceholder:@"Name" identifier:@"x" compact:NO];
  MWMNameField *small = [MWMNameField nameFieldWithPlaceholder:@"Name" identifier:@"y" compact:YES];
  NSView *host = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];
  [host addSubview:field];
  [host addSubview:small];
  [NSLayoutConstraint activateConstraints:@[[field.widthAnchor constraintEqualToConstant:300], [small.widthAnchor constraintEqualToConstant:300]]];
  [host layoutSubtreeIfNeeded];
  XCTAssertEqual(NSHeight(field.frame), 44);
  XCTAssertEqual(NSHeight(small.frame), 26);
  XCTAssertGreaterThan(field.font.pointSize, small.font.pointSize);
  XCTAssertFalse(field.invalid);
  field.invalid = YES;
  XCTAssertTrue(field.invalid);
}

- (void)testTheNameStepUsesTheNameFieldAndMarksAProblem {
  [self make:@"default"];
  ConfigurationProfilesView *page = [self page];
  [page beginDraftFromRunning];
  XCTAssertTrue([page.nameField isKindOfClass:[MWMNameField class]]);
  [page createDraftNamed:@"default"];
  XCTAssertTrue([(MWMNameField *)page.nameField invalid]);
}

- (void)testTheSummaryCountsWhatTheTextHolds {
  ConfigurationProfilesView *page = [self page];
  NSDictionary *summary = [page summaryForText:@"version: 2\nsettings:\n  defaultToCurrentScreen: true\nmodifiers:\n  hyper: [ctrl, alt, cmd]\nbindings:\n  - group: Windows\n    key: left\n    action: relaunch\n  - group: Windows\n    key: right\n    action: relaunch\n"];
  XCTAssertEqualObjects(summary[@"shortcuts"], @2);
  XCTAssertEqualObjects(summary[@"modifiers"], @1);
  XCTAssertEqualObjects(summary[@"settings"], @1);
  XCTAssertEqualObjects(summary[@"groups"], @[@"Windows"]);
}

- (void)testDuplicateRenameAndDelete {
  [self make:@"default"];
  [self make:@"desk"];
  ConfigurationProfilesView *page = [self page];
  [page duplicateNamed:@"desk" as:@"desk 2"];
  [page renameNamed:@"desk 2" to:@"couch"];
  XCTAssertEqualObjects([MWMProfiles names], (@[@"couch", @"default", @"desk"]));
  XCTAssertEqual(self.renamedActive, 1u, @"the window is told about every rename, so it can follow the one it has open");
  [page deleteNamed:@"couch"];
  XCTAssertEqualObjects([MWMProfiles names], (@[@"default", @"desk"]));
}

- (void)testRenamingTheActiveOneTellsTheWindow {
  [self make:@"default"];
  ConfigurationProfilesView *page = [self page];
  [page renameNamed:@"default" to:@"main"];
  XCTAssertEqualObjects([MWMProfiles activeName], @"main");
  XCTAssertEqual(self.renamedActive, 1u);
}

@end
