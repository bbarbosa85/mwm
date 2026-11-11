//
//  TestSlateConfigValidator.m
//  Slate
//
//  Tests for validating ~/.slate.js text without applying it.
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
#import "SlateConfigValidator.h"
#import "SlateConfigDocument.h"
#import "SlateLegacyMigration.h"

@interface TestSlateConfigValidator : XCTestCase
@end

@implementation TestSlateConfigValidator

- (NSString *)managedWithBindings:(NSString *)bindings {
  return [NSString stringWithFormat:
    @"var config = {\n"                                        // 1
    @"  settings: {\n"                                         // 2
    @"    defaultToCurrentScreen: true,\n"                     // 3
    @"  },\n"                                                  // 4
    @"  modifiers: {\n"                                        // 5
    @"    hyper: \"ctrl;alt;cmd\",\n"                          // 6
    @"  },\n"                                                  // 7
    @"  positions: {\n"                                        // 8
    @"    full: \"move screenOriginX;screenOriginY screenSizeX;screenSizeY\",\n"  // 9
    @"  },\n"                                                  // 10
    @"  bindings: [\n"                                         // 11
    @"%@"                                                      // 12...
    @"  ],\n"
    @"};\n"
    @"\n"
    @"slate.applyConfig(config);\n", bindings];
}

- (SlateConfigIssue *)onlyIssue:(SlateConfigValidationResult *)result {
  XCTAssertEqual([result.issues count], 1u, @"%@", result.issues);
  return [result.issues firstObject];
}

- (void)testValidManagedConfig {
  NSString *source = [self managedWithBindings:
    @"    { key: \"pad5\", mods: \"${hyper}\", action: \"${full}\" },\n"
    @"    { key: \"r\", mods: \"${hyper}\", action: \"relaunch\" },\n"
    @"    { key: \"g\", mods: \"cmd\", action: \"frobnicate\", enabled: false },\n"];
  SlateConfigValidationResult *result = [SlateConfigValidator validateSource:source];
  XCTAssertEqualObjects(result.issues, @[]);
  XCTAssertEqual(result.bindingCount, 2u, @"disabled bindings aren't checked or counted");
  XCTAssertEqual(result.settingCount, 1u);
}

- (void)testBadManagedBindingPointsAtItsLine {
  NSString *source = [self managedWithBindings:
    @"    { key: \"pad5\", mods: \"${hyper}\", action: \"${full}\" },\n"
    @"    { key: \"x\", mods: \"cmd\", action: \"frobnicate now\" },\n"];
  SlateConfigIssue *issue = [self onlyIssue:[SlateConfigValidator validateSource:source]];
  XCTAssertTrue(issue.isError);
  XCTAssertEqual(issue.line, 13u);
  XCTAssertTrue([issue.message hasPrefix:@"x:cmd: "], @"%@", issue.message);
}

- (void)testUnknownKeyIsAnError {
  NSString *source = [self managedWithBindings:@"    { key: \"notakey\", mods: \"cmd\", action: \"relaunch\" },\n"];
  SlateConfigIssue *issue = [self onlyIssue:[SlateConfigValidator validateSource:source]];
  XCTAssertTrue(issue.isError);
  XCTAssertEqual(issue.line, 12u);
  XCTAssertTrue([issue.message rangeOfString:@"Unrecognized key"].location != NSNotFound, @"%@", issue.message);
}

- (void)testUnknownAliasPointsAtApplyConfig {
  NSString *source = [self managedWithBindings:@"    { key: \"r\", mods: \"${nope}\", action: \"relaunch\" },\n"];
  SlateConfigIssue *issue = [self onlyIssue:[SlateConfigValidator validateSource:source]];
  XCTAssertTrue(issue.isError);
  XCTAssertEqual(issue.line, 16u, @"resolve errors point at the slate.applyConfig call");
  XCTAssertTrue([issue.message rangeOfString:@"Unrecognized alias ${nope}"].location != NSNotFound, @"%@", issue.message);
}

- (void)testSyntaxErrorHasLine {
  SlateConfigIssue *issue = [self onlyIssue:[SlateConfigValidator validateSource:@"slate.log('a');\nvar x = {;\n"]];
  XCTAssertTrue(issue.isError);
  XCTAssertEqual(issue.line, 2u);
}

- (void)testHandWrittenCallsAreChecked {
  NSString *source =
    @"slate.config('defaultToCurrentScreen', true);\n"
    @"slate.config('notASetting', 1);\n"
    @"slate.bind('a:cmd', slate.operationFromString('frobnicate'));\n"
    @"slate.bind('b:cmd', function(win) { win.move({}); });\n"
    @"slate.bind('b:cmd', slate.op('relaunch'));\n"
    @"var w = slate.window(); slate.on('appOpened', function() {});\n";
  SlateConfigValidationResult *result = [SlateConfigValidator validateSource:source];
  XCTAssertEqual(result.errorCount, 1u, @"%@", result.issues);
  XCTAssertEqual(result.warningCount, 2u, @"%@", result.issues);
  XCTAssertEqual(result.bindingCount, 3u);
  XCTAssertEqual(result.settingCount, 2u);

  SlateConfigIssue *error = result.issues[0];
  XCTAssertEqual(error.line, 3u);
  XCTAssertTrue([error.message rangeOfString:@"frobnicate"].location != NSNotFound, @"%@", error.message);
  XCTAssertEqual(result.issues[1].line, 2u, @"unknown setting");
  XCTAssertEqual(result.issues[2].line, 5u, @"duplicate hotkey");
  XCTAssertTrue([result.issues[2].message isEqualToString:@"b:cmd is also bound on line 4."], @"%@", result.issues[2].message);
}

- (void)testShellCommandsAreNotRun {
  NSString *marker = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  NSString *source = [NSString stringWithFormat:
    @"slate.shell('/usr/bin/touch %@', true);\n"
    @"slate.bind('t:cmd', slate.operationFromString('shell wait \\'/usr/bin/touch %@\\''));\n", marker, marker];
  SlateConfigValidationResult *result = [SlateConfigValidator validateSource:source];
  XCTAssertEqual(result.errorCount, 0u, @"%@", result.issues);
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:marker], @"validation must not run shell commands");
}

// What a new user sees: the bundled default.slate converted to the managed format.
- (void)testBundledDefaultsAreValid {
  NSString *path = [[NSBundle bundleForClass:[SlateConfigValidator class]] pathForResource:@"default" ofType:@"slate"];
  NSString *legacy = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  XCTAssertNotNil(legacy);
  NSMutableArray *warnings = [NSMutableArray array];
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromLegacySource:legacy warnings:warnings];
  XCTAssertEqualObjects(warnings, @[]);
  SlateConfigValidationResult *result = [SlateConfigValidator validateSource:[doc stringRepresentation]];
  XCTAssertEqualObjects(result.issues, @[]);
  XCTAssertGreaterThan(result.bindingCount, 0u);
}

@end
