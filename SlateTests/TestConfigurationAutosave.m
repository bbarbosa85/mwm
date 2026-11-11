//
//  TestConfigurationAutosave.m
//  Slate
//
//  Tests for the configuration window saving valid changes as they're made,
//  against a temporary file instead of ~/.slate.yml.
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
#import "SlateConfigDocument.h"

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
  self.path = [dir stringByAppendingPathComponent:@".slate.yml"];
  self.controller = [[ConfigurationWindowController alloc] init];
  [self.controller setValue:self.path forKey:@"configPathOverride"];
}

- (void)load {
  [self.controller performSelector:NSSelectorFromString(@"loadFromDisk")];
}

- (SlateConfigDocument *)document {
  return self.controller.formView.document;
}

// Changes the form's document the way a cell edit does, then tells the window.
- (void)edit:(void (^)(SlateConfigDocument *doc))change {
  XCTAssertNotNil([self document]);
  change([self document]);
  [(id<ConfigurationFormViewDelegate>)self.controller formViewDidChangeDocument:self.controller.formView];
}

- (NSString *)onDisk:(NSString *)path {
  return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
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

  [self edit:^(SlateConfigDocument *doc) { doc.bindings[0].action = @"hint ASDF"; }];
  XCTAssertEqualObjects([self onDisk:self.path], [[self document] stringRepresentation]);
  NSString *backup = [self.path stringByAppendingString:@".bak"];
  XCTAssertEqualObjects([self onDisk:backup], kOriginal);

  [self edit:^(SlateConfigDocument *doc) { doc.bindings[0].action = @"grid"; }];
  XCTAssertTrue([[self onDisk:self.path] containsString:@"action: \"grid\""]);
  XCTAssertEqualObjects([self onDisk:backup], kOriginal, @".bak keeps the version from before this session");
}

- (void)testChangesWithErrorsAreNotSaved {
  [kOriginal writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self load];

  [self edit:^(SlateConfigDocument *doc) { doc.bindings[0].modifiers = @"${hyperr}"; }];
  XCTAssertEqualObjects([self onDisk:self.path], kOriginal);
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[self.path stringByAppendingString:@".bak"]]);

  [self edit:^(SlateConfigDocument *doc) { doc.bindings[0].modifiers = @"${hyper}"; }];
  XCTAssertEqualObjects([self onDisk:self.path], kOriginal, @"back to the loaded configuration: nothing to write");

  [self edit:^(SlateConfigDocument *doc) { doc.bindings[0].action = @"undo"; }];
  XCTAssertTrue([[self onDisk:self.path] containsString:@"action: \"undo\""], @"saves again once it's valid");
}

- (void)testMissingFileIsNotCreatedUntilChanged {
  [self load];
  XCTAssertGreaterThan([[self document].bindings count], 0u, @"starts from the defaults");
  [self.controller performSelector:NSSelectorFromString(@"validateAndSave")];
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.path], @"untouched defaults aren't written");

  [self edit:^(SlateConfigDocument *doc) { [doc.aliases addObject:[SlateConfigEntry entryWithName:@"mine" value:@"x"]]; }];
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
