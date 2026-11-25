//
//  TestConfigurationConfigurations.m
//
//  The Configurations page. Every test uses a temporary home folder and doesn't ask anything.
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
#import "ConfigurationConfigurationsView.h"
#import "MWMConfigurations.h"

@interface TestConfigurationConfigurations : XCTestCase <ConfigurationConfigurationsViewDelegate>
@property (copy) NSString *home;
@property (copy) NSString *switchedTo;
@property (assign) NSUInteger renamedActive;
@end

@implementation TestConfigurationConfigurations

- (void)setUp {
  self.home = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:self.home withIntermediateDirectories:YES attributes:nil error:nil];
  [MWMConfigurations setHomeDirectory:self.home];
  self.switchedTo = nil;
  self.renamedActive = 0;
}

- (void)tearDown {
  [MWMConfigurations setHomeDirectory:nil];
  [[NSFileManager defaultManager] removeItemAtPath:self.home error:nil];
}

- (void)configurationsView:(ConfigurationConfigurationsView *)view switchToConfigurationNamed:(NSString *)name { self.switchedTo = name; }
- (void)configurationsViewDidRenameActive:(ConfigurationConfigurationsView *)view { self.renamedActive++; }

- (ConfigurationConfigurationsView *)page {
  ConfigurationConfigurationsView *page = [[ConfigurationConfigurationsView alloc] initWithFrame:NSMakeRect(0, 0, 840, 640)];
  page.interactive = NO;
  page.delegate = self;
  return page;
}

- (NSView *)viewIn:(NSView *)root identifier:(NSString *)identifier {
  if ([root.identifier isEqualToString:identifier]) return root;
  for (NSView *sub in root.subviews) { NSView *found = [self viewIn:sub identifier:identifier]; if (found) return found; }
  return nil;
}

- (void)make:(NSString *)name { [MWMConfigurations createNamed:name text:@"version: 2\n" error:nil]; }

- (void)testAnEmptyFolderSaysSoAndOffersANewOne {
  ConfigurationConfigurationsView *page = [self page];
  XCTAssertNotNil([self viewIn:page identifier:@"config-empty"]);
  XCTAssertNotNil([self viewIn:page identifier:@"config-new"]);
}

- (void)testEachConfigurationIsACardAndTheActiveOneIsMarked {
  [self make:@"default"];
  [self make:@"desk"];
  ConfigurationConfigurationsView *page = [self page];
  XCTAssertNotNil([self viewIn:page identifier:@"config-default"]);
  XCTAssertNotNil([self viewIn:page identifier:@"config-desk"]);
  NSView *activeCard = [self viewIn:page identifier:@"config-default"];
  XCTAssertNotNil([self viewIn:activeCard identifier:@"config-active"]);
  XCTAssertNil([self viewIn:[self viewIn:page identifier:@"config-desk"] identifier:@"config-active"]);
  XCTAssertFalse([(NSButton *)[self viewIn:page identifier:@"activate-default"] isEnabled], @"already active");
  XCTAssertTrue([(NSButton *)[self viewIn:page identifier:@"activate-desk"] isEnabled]);
  XCTAssertFalse([(NSButton *)[self viewIn:page identifier:@"delete-default"] isEnabled], @"the active one can't be deleted");
  XCTAssertTrue([(NSButton *)[self viewIn:page identifier:@"delete-desk"] isEnabled]);
}

- (void)testTheOnlyConfigurationCantBeDeleted {
  [self make:@"default"];
  XCTAssertFalse([(NSButton *)[self viewIn:[self page] identifier:@"delete-default"] isEnabled]);
}

- (void)testActivateAsksTheWindowToSwitch {
  [self make:@"default"];
  [self make:@"desk"];
  ConfigurationConfigurationsView *page = [self page];
  [page activateNamed:@"default"];
  XCTAssertNil(self.switchedTo, @"it already is the active one");
  [page activateNamed:@"desk"];
  XCTAssertEqualObjects(self.switchedTo, @"desk");
}

- (void)testNewFromTheDefaultsAndAsACopy {
  [self make:@"default"];
  [MWMConfigurations writeText:@"version: 2\n# mine\n" named:@"default" error:nil];
  ConfigurationConfigurationsView *page = [self page];
  [page createNamed:@"fresh" copyingActive:NO];
  [page createNamed:@"clone" copyingActive:YES];
  XCTAssertEqualObjects([MWMConfigurations names], (@[@"clone", @"default", @"fresh"]));
  XCTAssertTrue([[NSString stringWithContentsOfFile:[MWMConfigurations pathForName:@"clone"] encoding:NSUTF8StringEncoding error:nil] containsString:@"# mine"]);
  XCTAssertTrue([[NSString stringWithContentsOfFile:[MWMConfigurations pathForName:@"fresh"] encoding:NSUTF8StringEncoding error:nil] containsString:@"bindings"], @"the defaults have shortcuts");
  XCTAssertNil(page.problem);
}

- (void)testATakenNameShowsAProblemInWords {
  [self make:@"default"];
  ConfigurationConfigurationsView *page = [self page];
  [page createNamed:@"DEFAULT" copyingActive:NO];
  XCTAssertEqualObjects(page.problem, @"A configuration with that name already exists.");
  XCTAssertNotNil([self viewIn:page identifier:@"config-problem"]);
  [page createNamed:@"another" copyingActive:NO];
  XCTAssertNil(page.problem, @"the problem clears with the next change");
}

- (void)testDuplicateRenameAndDelete {
  [self make:@"default"];
  [self make:@"desk"];
  ConfigurationConfigurationsView *page = [self page];
  [page duplicateNamed:@"desk" as:@"desk 2"];
  [page renameNamed:@"desk 2" to:@"couch"];
  XCTAssertEqualObjects([MWMConfigurations names], (@[@"couch", @"default", @"desk"]));
  XCTAssertEqual(self.renamedActive, 0u, @"only the active one asks the window to reload");
  [page deleteNamed:@"couch"];
  XCTAssertEqualObjects([MWMConfigurations names], (@[@"default", @"desk"]));
}

- (void)testRenamingTheActiveOneTellsTheWindow {
  [self make:@"default"];
  ConfigurationConfigurationsView *page = [self page];
  [page renameNamed:@"default" to:@"main"];
  XCTAssertEqualObjects([MWMConfigurations activeName], @"main");
  XCTAssertEqual(self.renamedActive, 1u);
}

- (void)testAddFromFileCopiesItInAndRefusesOneThatCantBeRead {
  NSString *good = [self.home stringByAppendingPathComponent:@"starter.mwm.yml"];
  [@"version: 2\nbindings:\n  - key: r\n    action: relaunch\n" writeToFile:good atomically:YES encoding:NSUTF8StringEncoding error:nil];
  ConfigurationConfigurationsView *page = [self page];
  [page addFromFileAtPath:good];
  XCTAssertEqualObjects([MWMConfigurations names], (@[@"starter"]));
  XCTAssertNil(page.problem);
  NSString *bad = [self.home stringByAppendingPathComponent:@"broken.mwm.yml"];
  [@"bindings: [unclosed\n" writeToFile:bad atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [page addFromFileAtPath:bad];
  XCTAssertNotNil(page.problem);
  XCTAssertEqual([[MWMConfigurations names] count], 1u);
}

@end
