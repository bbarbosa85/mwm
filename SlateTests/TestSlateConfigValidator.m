//
//  TestSlateConfigValidator.m
//  Slate
//
//  Tests for validating ~/.mwm.yml text without applying it.
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

- (NSString *)configWithBindings:(NSString *)bindings {
  return [NSString stringWithFormat:
    @"settings:\n"                                                   // 1
    @"  defaultToCurrentScreen: true\n"                              // 2
    @"modifiers:\n"                                                  // 3
    @"  hyper: ctrl;alt;cmd\n"                                       // 4
    @"positions:\n"                                                  // 5
    @"  full: move screenOriginX;screenOriginY screenSizeX;screenSizeY\n"  // 6
    @"bindings:\n"                                                   // 7
    @"%@", bindings];                                                // 8...
}

- (SlateConfigIssue *)onlyIssue:(SlateConfigValidationResult *)result {
  XCTAssertEqual([result.issues count], 1u, @"%@", result.issues);
  return [result.issues firstObject];
}

- (void)testValidConfig {
  NSString *source = [self configWithBindings:
    @"  - key: pad5\n    mods: ${hyper}\n    action: ${full}\n"
    @"  - key: r\n    mods: ${hyper}\n    action: relaunch\n"
    @"  - key: g\n    mods: cmd\n    action: frobnicate\n    enabled: false\n"];
  SlateConfigValidationResult *result = [SlateConfigValidator validateSource:source];
  XCTAssertEqualObjects(result.issues, @[]);
  XCTAssertEqual(result.bindingCount, 2u, @"disabled bindings aren't checked or counted");
  XCTAssertEqual(result.settingCount, 1u);
}

- (void)testBadBindingPointsAtItsLineAndIndex {
  NSString *source = [self configWithBindings:
    @"  - key: pad5\n    mods: ${hyper}\n    action: ${full}\n"
    @"  - key: x\n    mods: cmd\n    action: frobnicate now\n"];
  SlateConfigIssue *issue = [self onlyIssue:[SlateConfigValidator validateSource:source]];
  XCTAssertTrue(issue.isError);
  XCTAssertEqual(issue.line, 11u);
  XCTAssertEqual(issue.bindingIndex, 1u);
  XCTAssertTrue([issue.message hasPrefix:@"Binding #2 (x:cmd): "], @"%@", issue.message);
}

- (void)testUnknownKeyIsAnError {
  SlateConfigIssue *issue = [self onlyIssue:[SlateConfigValidator validateSource:
    [self configWithBindings:@"  - key: notakey\n    mods: cmd\n    action: relaunch\n"]]];
  XCTAssertTrue(issue.isError);
  XCTAssertEqual(issue.line, 8u);
  XCTAssertTrue([issue.message rangeOfString:@"Unrecognized key"].location != NSNotFound, @"%@", issue.message);
}

- (void)testUnknownAliasPointsAtTheBinding {
  SlateConfigIssue *issue = [self onlyIssue:[SlateConfigValidator validateSource:
    [self configWithBindings:@"  - key: r\n    mods: ${nope}\n    action: relaunch\n"]]];
  XCTAssertTrue(issue.isError);
  XCTAssertEqual(issue.line, 8u);
  XCTAssertEqual(issue.bindingIndex, 0u);
  XCTAssertTrue([issue.message rangeOfString:@"Unknown alias ${nope}"].location != NSNotFound, @"%@", issue.message);
}

- (void)testAllProblemsAreListed {
  NSString *source =
    @"settings:\n"
    @"  defaultToCurrentScreen: true\n"
    @"  notASetting: 1\n"
    @"bindings:\n"
    @"  - key: a\n    mods: cmd\n    action: frobnicate\n"   // 5
    @"  - key: b\n    mods: cmd\n    action: ${missing}\n"   // 8
    @"  - key: c\n    mods: cmd\n    action: relaunch\n"     // 11
    @"  - key: c\n    mods: cmd\n    action: undo\n";        // 14
  SlateConfigValidationResult *result = [SlateConfigValidator validateSource:source];
  XCTAssertEqual(result.errorCount, 2u, @"%@", result.issues);
  XCTAssertEqual(result.warningCount, 2u, @"%@", result.issues);
  XCTAssertEqual(result.bindingCount, 3u, @"the binding with an unknown alias can't be checked");
  XCTAssertEqual(result.issues[0].line, 5u);
  XCTAssertEqual(result.issues[1].line, 8u);
  XCTAssertEqualObjects(result.issues[2].entryName, @"notASetting");
  XCTAssertEqual(result.issues[3].line, 14u);
  XCTAssertEqualObjects(result.issues[3].message, @"Binding #4 (c:cmd) uses the same keys as binding #3.");
}

- (void)testDuplicateShortcutsIgnoreModifierOrder {
  NSString *source = [self configWithBindings:
    @"  - key: r\n    mods: cmd;alt\n    action: relaunch\n"
    @"  - key: r\n    mods: alt,cmd\n    action: undo\n"];
  SlateConfigValidationResult *result = [SlateConfigValidator validateSource:source];
  XCTAssertEqual(result.errorCount, 0u, @"%@", result.issues);
  XCTAssertEqual(result.warningCount, 1u, @"%@", result.issues);
  XCTAssertTrue([result.issues[0].message containsString:@"same keys as binding #1"], @"%@", result.issues[0].message);
}

- (void)testSyntaxErrorHasLine {
  SlateConfigIssue *issue = [self onlyIssue:[SlateConfigValidator validateSource:@"settings:\n  a: [1, 2]\n"]];
  XCTAssertTrue(issue.isError);
  XCTAssertEqual(issue.line, 2u);
}

- (void)testShellCommandsAreNotRun {
  NSString *marker = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  NSString *source = [self configWithBindings:[NSString stringWithFormat:
    @"  - key: t\n    mods: cmd\n    action: \"shell wait '/usr/bin/touch %@'\"\n", marker]];
  SlateConfigValidationResult *result = [SlateConfigValidator validateSource:source];
  XCTAssertEqual(result.errorCount, 0u, @"%@", result.issues);
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:marker], @"validation must not run shell commands");
}

// What a new user sees: the bundled default.slate converted to YAML.
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
