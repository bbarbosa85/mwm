//
//  TestSlateConfigFormat.m
//
//  Version 2 of ~/.mwm.yml: objects for monitors, slots and actions, plain names, lists.
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
#import "SlateConfigDocument.h"
#import "SlateConfigFormat.h"

// A version 1 file using everything the format has.
static NSString *const kVersionOne =
  @"settings:\n  defaultToCurrentScreen: true\n  windowHintsFontSize: 14\n  secondaryBrowsers: \"Safari;Firefox\"\n"
  @"modifiers:\n  hyper: ctrl;alt;cmd\n  shyper: shift;ctrl;alt;cmd\n"
  @"monitors:\n  monitor-samsung: \"display: Samsung Odyssey 5120x1440\"\n  monitor-samsung-size: 5120x1440\n  monitor-laptop: \"display: built-in\"\n  monitor-old: \"1\"\n  loose-size: 1920x1080\n"
  @"positions:\n"
  @"  lefthalf: move screenOriginX;screenOriginY screenSizeX/2;screenSizeY\n"
  @"  third2: move screenOriginX+screenSizeX/3;screenOriginY screenSizeX/3;screenSizeY\n"
  @"  samsung-full: move screenOriginX;screenOriginY screenSizeX;screenSizeY ${monitor-samsung-size}\n"
  @"  floating: move windowTopLeftX;windowTopLeftY screenSizeX/3;screenSizeY/2\n"
  @"aliases:\n  mine: ${lefthalf}\n"
  @"bindings:\n"
  @"  - group: Layout\n    key: pad4\n    mods: ${hyper}\n    action: ${lefthalf}\n    note: Left half\n"
  @"  - group: Layout\n    key: pad6\n    mods: ${hyper}\n    action: ${third2} ${monitor-samsung}\n"
  @"  - key: c\n    mods: alt;shift\n    action: focus 'Google Chrome'\n"
  @"  - key: left\n    mods: ${shyper}\n    action: focus left\n"
  @"  - key: n\n    mods: ctrl;alt\n    action: throw ${monitor-samsung} resize\n"
  @"  - key: m\n    mods: ctrl;alt\n    action: throw next\n"
  @"  - key: h\n    mods: ${shyper}\n    action: hint ASDF\n    repeat: false\n"
  @"  - key: g\n    mods: ${shyper}\n    action: grid padding:5 0:6,2\n"
  @"  - key: r\n    mods: ${hyper}\n    action: relaunch\n    enabled: false\n"
  @"  - key: s\n    mods: ${hyper}\n    action: switch\n"
  @"  - key: p\n    mods: ${hyper}\n    action: push up bar-resize:screenSizeY/2\n"
  @"  - key: u\n    mods: ${hyper}\n    action: nudge +10% +0\n"
  @"  - key: i\n    mods: ${hyper}\n    action: resize +5% +0\n"
  @"  - key: z\n    mods: ${hyper}\n    action: chain push up | push right\n"
  @"  - key: x\n    mods: ${hyper}\n    action: ${mine}\n"
  @"  - key: k\n    mods: ctrl;cmd\n    action: resize +0   -5%\n"
  @"  - key: l\n    mods: ctrl;cmd\n    action: focus \"Mail\"\n";

@interface TestSlateConfigFormat : XCTestCase
@end

@implementation TestSlateConfigFormat

- (SlateConfigDocument *)documentFrom:(NSString *)source {
  NSError *error = nil;
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:source error:&error];
  XCTAssertNotNil(doc, @"%@", error);
  return doc;
}

// What the engine would load: settings and bindings with every name expanded.
- (NSString *)loadedFrom:(SlateConfigDocument *)doc {
  SlateResolvedConfig *resolved = [doc resolve:nil];
  NSMutableArray *lines = [NSMutableArray array];
  for (SlateConfigEntry *setting in resolved.settings) [lines addObject:[NSString stringWithFormat:@"set %@=%@", setting.name, setting.value]];
  for (SlateResolvedBinding *binding in resolved.bindings) [lines addObject:[NSString stringWithFormat:@"%@ -> %@ (repeat %@)", binding.hotkey, binding.action, binding.repeat]];
  return [lines componentsJoinedByString:@"\n"];
}

- (void)testAVersionOneFileKeepsEverythingWhenWrittenAsVersionTwo {
  SlateConfigDocument *old = [self documentFrom:kVersionOne];
  XCTAssertEqual(old.sourceVersion, 1);
  NSString *written = [old stringRepresentation];
  SlateConfigDocument *reread = [self documentFrom:written];
  XCTAssertEqual(reread.sourceVersion, 2);
  XCTAssertEqualObjects([self loadedFrom:reread], [self loadedFrom:old], @"the engine loads the same thing");
  XCTAssertEqualObjects(reread.settings, old.settings);
  XCTAssertEqualObjects(reread.modifiers, old.modifiers);
  XCTAssertEqualObjects(reread.positions, old.positions, @"every slot keeps its exact formula");
  XCTAssertEqualObjects(reread.aliases, old.aliases);
  XCTAssertEqualObjects(reread.bindings, old.bindings);
  NSArray *oldMonitors = [[old.monitors valueForKey:@"description"] sortedArrayUsingSelector:@selector(compare:)];
  XCTAssertEqual([reread.monitors count], [old.monitors count]);
  for (SlateConfigEntry *entry in old.monitors) {
    BOOL found = NO;
    for (SlateConfigEntry *other in reread.monitors) if ([other isEqual:entry]) found = YES;
    XCTAssertTrue(found, @"monitor %@ survives (%@)", entry.name, oldMonitors);
  }
  XCTAssertEqualObjects([reread stringRepresentation], written, @"writing is stable");
}

- (void)testVersionTwoReadsAsObjectsAndPlainNames {
  NSString *written = [[self documentFrom:kVersionOne] stringRepresentation];
  XCTAssertTrue([written containsString:@"\nversion: 2\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"  hyper: [ctrl, alt, cmd]\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"  monitor-samsung: {display: Samsung Odyssey 5120x1440, size: 5120x1440}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"  loose-size: {size: 1920x1080}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"  monitor-laptop: {display: built-in}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"  monitor-old: {screen: \"1\"}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"\nslots:\n  lefthalf: {x: 0%, y: 0%, width: 50%, height: 100%}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"  third2: {x: 33.333333%, y: 0%, width: 33.333333%, height: 100%}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"  floating: {formula: \"move windowTopLeftX;windowTopLeftY screenSizeX/3;screenSizeY/2\"}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"    mods: hyper\n    action: {type: move, slot: lefthalf}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"    action: {type: move, slot: third2, screen: monitor-samsung}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"    mods: [alt, shift]\n    action: {type: focus-app, app: Google Chrome}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"    action: {type: throw, screen: monitor-samsung, style: resize}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"    action: {type: custom, text: \"chain push up | push right\"}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"action: {type: custom, text: \"resize +0   -5%\"}"], @"text that wouldn't read back the same is kept as written: %@", written);
  XCTAssertFalse([written containsString:@"${hyper}"], @"modifier groups are plain names: %@", written);
}

- (void)testAHandWrittenVersionTwoFileLoads {
  NSString *source =
    @"version: 2\n"
    @"modifiers:\n  hyper: [ctrl, alt, cmd]\n"
    @"monitors:\n  tv: {display: LG TV 3840x2160, size: 3840x2160}\n"
    @"slots:\n  quarter: {x: 0%, y: 0%, width: 50%, height: 50%}\n"
    @"bindings:\n"
    @"  - key: q\n    mods: hyper\n    action: {type: move, slot: quarter, screen: tv}\n"
    @"  - key: w\n    mods: [alt, shift]\n    action: {type: focus-app, app: Safari}\n"
    @"  - key: e\n    mods: hyper\n    action: relaunch\n";
  SlateConfigDocument *doc = [self documentFrom:source];
  SlateResolvedConfig *resolved = [doc resolve:nil];
  XCTAssertEqualObjects(resolved.bindings[0].hotkey, @"q:ctrl;alt;cmd");
  XCTAssertTrue([resolved.bindings[0].action hasPrefix:@"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY/2 "], @"%@", resolved.bindings[0].action);
  XCTAssertEqualObjects(resolved.bindings[1].hotkey, @"w:alt;shift");
  XCTAssertEqualObjects(resolved.bindings[1].action, @"focus 'Safari'");
  XCTAssertEqualObjects(resolved.bindings[2].action, @"relaunch", @"an action with no fields can be plain text");
}

- (void)assertV2:(NSString *)body failsWith:(NSString *)fragment line:(NSUInteger)line {
  NSError *error = nil;
  XCTAssertNil([SlateConfigDocument documentFromString:[@"version: 2\n" stringByAppendingString:body] error:&error], @"%@ should fail", body);
  XCTAssertTrue([[error localizedDescription] containsString:fragment], @"%@ should mention %@", [error localizedDescription], fragment);
  if (line > 0) XCTAssertEqualObjects(error.userInfo[SlateConfigDocumentErrorLineKey], @(line + 1), @"%@", [error localizedDescription]);
}

- (void)testVersionTwoMistakesNameTheLine {
  [self assertV2:@"positions:\n  a: x\n" failsWith:@"Unknown section" line:1];
  [self assertV2:@"slots:\n  a: {x: 0%, y: 0%, width: half, height: 100%}\n" failsWith:@"width should be a percent" line:2];
  [self assertV2:@"slots:\n  a: {x: 0%, y: 0%, width: 50%}\n" failsWith:@"needs height" line:2];
  [self assertV2:@"slots:\n  a: {x: 0%, y: 0%, width: 50%, height: 50%, depth: 1%}\n" failsWith:@"unknown field \"depth\"" line:2];
  [self assertV2:@"monitors:\n  a: {display: built-in, colour: red}\n" failsWith:@"unknown field \"colour\"" line:2];
  [self assertV2:@"monitors:\n  a: {display: built-in, screen: 0}\n" failsWith:@"not both" line:2];
  [self assertV2:@"modifiers:\n  hyper: {a: 1}\n" failsWith:@"should be a list" line:2];
  [self assertV2:@"bindings:\n  - key: a\n    action: {type: teleport}\n" failsWith:@"unknown action type \"teleport\"" line:3];
  [self assertV2:@"bindings:\n  - key: a\n    action: {type: move}\n" failsWith:@"needs a slot" line:0];
  [self assertV2:@"bindings:\n  - key: a\n    action: {type: focus, direction: sideways}\n" failsWith:@"needs a direction" line:0];
  [self assertV2:@"bindings:\n  - key: a\n    action: {type: relaunch, app: x}\n" failsWith:@"no \"app\"" line:3];
  [self assertV2:@"bindings:\n  - key: a\n    action: {slot: x}\n" failsWith:@"needs a type" line:0];
  [self assertV2:@"bindings:\n  - key: a\n    mods: {x: 1}\n    action: relaunch\n" failsWith:@"mods" line:0];
}

- (void)testTheVersionKeyIsChecked {
  NSError *error = nil;
  XCTAssertNil([SlateConfigDocument documentFromString:@"version: 3\n" error:&error]);
  XCTAssertTrue([[error localizedDescription] containsString:@"version should be 1 or 2"], @"%@", [error localizedDescription]);
  SlateConfigDocument *one = [SlateConfigDocument documentFromString:@"version: 1\nsettings:\n  a: 1\n" error:nil];
  XCTAssertEqual(one.sourceVersion, 1);
  XCTAssertEqual([SlateConfigDocument documentFromString:@"" error:nil].sourceVersion, 0, @"an empty file has no version");
}


#pragma mark - Migrating a file

- (NSString *)temporaryFileWith:(NSString *)contents {
  NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  NSString *path = [dir stringByAppendingPathComponent:@".mwm.yml"];
  [contents writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  return path;
}

- (void)testMigratingAFileKeepsTheOldOneAndWritesTheNewFormat {
  NSString *path = [self temporaryFileWith:kVersionOne];
  NSString *backup = nil;
  NSError *error = nil;
  XCTAssertTrue([SlateConfigFormat migrateFileAtPath:path backupPath:&backup error:&error], @"%@", error);
  XCTAssertNotNil(backup);
  XCTAssertTrue([[backup lastPathComponent] hasPrefix:@".mwm.yml.v1-"]);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:backup encoding:NSUTF8StringEncoding error:nil], kVersionOne, @"the old file is kept as it was");
  SlateConfigDocument *now = [SlateConfigDocument documentWithContentsOfFile:path error:&error];
  XCTAssertNotNil(now, @"%@", error);
  XCTAssertEqual(now.sourceVersion, 2);
  XCTAssertEqualObjects([self loadedFrom:now], [self loadedFrom:[self documentFrom:kVersionOne]]);

  // Once is enough.
  NSString *again = nil;
  XCTAssertFalse([SlateConfigFormat migrateFileAtPath:path backupPath:&again error:&error]);
  XCTAssertNil(again);
  XCTAssertNil(error);
}

- (void)testMigrationLeavesAlonePathsThatNeedNothingOrCannotBeRead {
  NSError *error = nil;
  NSString *missing = [NSTemporaryDirectory() stringByAppendingPathComponent:@"no-such-mwm.yml"];
  XCTAssertFalse([SlateConfigFormat migrateFileAtPath:missing backupPath:nil error:&error]);
  XCTAssertNil(error);

  NSString *v2 = [self temporaryFileWith:@"version: 2\nsettings: {}\n"];
  XCTAssertFalse([SlateConfigFormat migrateFileAtPath:v2 backupPath:nil error:&error]);
  XCTAssertNil(error);

  NSString *empty = [self temporaryFileWith:@""];
  XCTAssertFalse([SlateConfigFormat migrateFileAtPath:empty backupPath:nil error:&error]);

  NSString *broken = [self temporaryFileWith:@"settings:\n  a: [1, 2\n"];
  XCTAssertFalse([SlateConfigFormat migrateFileAtPath:broken backupPath:nil error:&error]);
  XCTAssertNotNil(error, @"a file that doesn't read is reported, and left as it was");
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:broken encoding:NSUTF8StringEncoding error:nil], @"settings:\n  a: [1, 2\n");
}

- (void)testMigratingAFileWithAnUnknownAliasStillConvertsAsWritten {
  NSString *source = @"bindings:\n  - key: a\n    mods: cmd\n    action: ${nothing}\n";
  NSString *path = [self temporaryFileWith:source];
  NSString *backup = nil;
  XCTAssertTrue([SlateConfigFormat migrateFileAtPath:path backupPath:&backup error:nil]);
  NSString *now = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  XCTAssertTrue([now containsString:@"action: {type: move, slot: nothing}"], @"%@", now);
}


- (void)testSnapshotActionsAreObjectsInVersionTwo {
  NSString *source =
    @"bindings:\n"
    @"  - key: s\n    mods: ctrl;cmd\n    action: snapshot work save-to-disk\n"
    @"  - key: d\n    mods: ctrl;cmd\n    action: snapshot temp\n"
    @"  - key: a\n    mods: ctrl;cmd\n    action: activate-snapshot work\n"
    @"  - key: f\n    mods: ctrl;cmd\n    action: activate-snapshot work delete\n";
  SlateConfigDocument *old = [self documentFrom:source];
  NSString *written = [old stringRepresentation];
  XCTAssertTrue([written containsString:@"action: {type: save-snapshot, name: work, keep: true}"], @"%@", written);
  XCTAssertTrue([written containsString:@"action: {type: save-snapshot, name: temp, keep: false}"], @"%@", written);
  XCTAssertTrue([written containsString:@"action: {type: restore-snapshot, name: work}"], @"%@", written);
  XCTAssertTrue([written containsString:@"action: {type: custom, text: \"activate-snapshot work delete\"}"], @"%@", written);
  SlateConfigDocument *back = [self documentFrom:written];
  XCTAssertEqualObjects(back.bindings, old.bindings);
  [self assertV2:@"bindings:\n  - key: a\n    action: {type: save-snapshot}\n" failsWith:@"needs a snapshot name" line:0];
  [self assertV2:@"bindings:\n  - key: a\n    action: {type: save-snapshot, name: w, keep: yes please}\n" failsWith:@"keep should be true or false" line:3];
  [self assertV2:@"bindings:\n  - key: a\n    action: {type: restore-snapshot, name: w, keep: true}\n" failsWith:@"no \"keep\"" line:3];
}

@end
