//
//  TestConfigurationAutosave.m
//  Slate
//
//  Tests for the configuration window saving valid changes as they're made,
//  against a temporary file instead of ~/.mwm.yml.
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
#import "ConfigurationWindowController.h"
#import "ConfigurationFormView.h"
#import "MWMConfigDocument.h"

@interface TestConfigurationAutosave : XCTestCase
@property (copy) NSString *path;
@property (strong) ConfigurationWindowController *controller;
@end

@implementation TestConfigurationAutosave

// Hand-written: comments and layout the window doesn't produce.
static NSString *const kOriginal =
  @"# my config\n"
  @"modifiers:\n"
  @"  hyper: ctrl;alt;cmd   # the usual\n"
  @"bindings:\n"
  @"  - key: r\n"
  @"    mods: ${hyper}\n"
  @"    action: relaunch\n";

- (void)setUp {
  NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  [self addTeardownBlock:^{ [[NSFileManager defaultManager] removeItemAtPath:dir error:nil]; }];
  self.path = [dir stringByAppendingPathComponent:@".mwm.yml"];
  self.controller = [[ConfigurationWindowController alloc] init];
  [self.controller setValue:self.path forKey:@"configPathOverride"];
}

- (void)load {
  [self.controller performSelector:NSSelectorFromString(@"loadFromDisk")];
}

- (MWMConfigDocument *)document {
  return self.controller.formView.document;
}

// Changes the form's document the way a cell edit does, then tells the window.
- (void)edit:(void (^)(MWMConfigDocument *doc))change {
  XCTAssertNotNil([self document]);
  change([self document]);
  [(id<ConfigurationFormViewDelegate>)self.controller formViewDidChangeDocument:self.controller.formView];
}

- (NSString *)onDisk:(NSString *)path {
  return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

// Editing a slot is a sublevel page: its header and the bottom bar step aside, and
// the file only changes when its own Save is clicked.
- (void)testEditingASlotHidesTheBarAndSavesOnlyOnSave {
  NSString *text = @"positions:\n  centre: move screenOriginX+screenSizeX/4;screenOriginY screenSizeX/2;screenSizeY\n";
  [text writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  ConfigurationFormView *form = self.controller.formView;
  NSView *bar = [self.controller valueForKey:@"bar"];
  form.selectedSection = ConfigurationFormSectionPositions;
  XCTAssertFalse([bar isHidden], @"the gallery shows the bottom bar");
  XCTAssertFalse(form.sublevelActive);

  id slots = [form valueForKey:@"slotsView"];
  [slots performSelector:@selector(selectSlotNamed:) withObject:@"centre"];
  XCTAssertTrue(form.sublevelActive);
  XCTAssertTrue([bar isHidden], @"no saved/apply/close bar while a slot is open");
  XCTAssertTrue([[form valueForKey:@"titleLabel"] isHidden], @"the back button is the header");
  XCTAssertTrue([[form valueForKey:@"slotsSwitcher"] isHidden], @"so is the switcher");

  [slots setValue:[NSValue valueWithRect:NSMakeRect(0.1, 0, 0.3, 1)] forKey:@"draftRect"];
  XCTAssertEqualObjects([self onDisk:self.path], text, @"nothing is written until Save");
  [slots performSelector:NSSelectorFromString(@"save")];
  XCTAssertNotEqualObjects([self onDisk:self.path], text, @"Save writes the file");
  XCTAssertFalse(form.sublevelActive, @"saving goes back to the gallery");
  XCTAssertFalse([bar isHidden]);
  XCTAssertFalse([[form valueForKey:@"titleLabel"] isHidden]);
  XCTAssertFalse([[form valueForKey:@"slotsSwitcher"] isHidden], @"the switcher is back in the gallery header");
}

- (void)testLeavingThePageClosesTheSublevel {
  [@"positions:\n  centre: move screenOriginX+screenSizeX/4;screenOriginY screenSizeX/2;screenSizeY\n" writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  ConfigurationFormView *form = self.controller.formView;
  form.selectedSection = ConfigurationFormSectionPositions;
  [[form valueForKey:@"slotsView"] performSelector:@selector(selectSlotNamed:) withObject:@"centre"];
  XCTAssertTrue(form.sublevelActive);
  form.selectedSection = ConfigurationFormSectionGeneral;
  XCTAssertFalse(form.sublevelActive);
  XCTAssertFalse([[self.controller valueForKey:@"bar"] isHidden], @"the bar is back on the other pages");
}

- (void)testOpeningDoesNotRewriteTheFile {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  XCTAssertEqualObjects([self document].bindings[0].action, @"relaunch");
  [self.controller performSelector:NSSelectorFromString(@"validateAndSave")];
  XCTAssertEqualObjects([self onDisk:self.path], kOriginal, @"comments survive until something changes");
}

- (void)testValidChangesSaveAndBackUpOnce {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].action = @"hint ASDF"; }];
  XCTAssertEqualObjects([self onDisk:self.path], [[self document] stringRepresentation]);
  NSString *backup = [self.path stringByAppendingString:@".bak"];
  XCTAssertEqualObjects([self onDisk:backup], kOriginal);

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].action = @"grid"; }];
  XCTAssertTrue([[self onDisk:self.path] containsString:@"action: {type: grid}"]);
  XCTAssertEqualObjects([self onDisk:backup], kOriginal, @".bak keeps the version from before this session");
}

- (void)testChangesWithErrorsAreNotSaved {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].modifiers = @"${hyperr}"; }];
  XCTAssertEqualObjects([self onDisk:self.path], kOriginal);
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[self.path stringByAppendingString:@".bak"]]);

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].modifiers = @"${hyper}"; }];
  XCTAssertEqualObjects([self onDisk:self.path], kOriginal, @"back to the loaded configuration: nothing to write");

  [self edit:^(MWMConfigDocument *doc) { doc.bindings[0].action = @"undo"; }];
  XCTAssertTrue([[self onDisk:self.path] containsString:@"action: {type: custom, text: \"undo\"}"], @"saves again once it's valid");
}

- (void)testMissingFileIsNotCreatedUntilChanged {
  [self load];
  XCTAssertGreaterThan([[self document].bindings count], 0u, @"starts from the defaults");
  [self.controller performSelector:NSSelectorFromString(@"validateAndSave")];
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.path], @"untouched defaults aren't written");

  [self edit:^(MWMConfigDocument *doc) { [doc.aliases addObject:[MWMConfigEntry entryWithName:@"mine" value:@"x"]]; }];
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.path]);
}

- (void)testUnreadableFileIsLeftAlone {
  NSString *broken = @"bindings:\n  - key: r\n    action: [relaunch]\n";
  [broken writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];
  XCTAssertNil([self document], @"the form shows the error instead");
  [self.controller performSelector:NSSelectorFromString(@"validateAndSave")];
  XCTAssertEqualObjects([self onDisk:self.path], broken);
}

@end
