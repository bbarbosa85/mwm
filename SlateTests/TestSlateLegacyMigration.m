//
//  TestSlateLegacyMigration.m
//  Slate
//
//  Tests for converting ~/.slate into the managed ~/.slate.js format.
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
#import <JavaScriptCore/JavaScriptCore.h>
#import "SlateConfigDocument.h"
#import "SlateLegacyMigration.h"
#import "StringTokenizer.h"

@interface TestSlateLegacyMigration : XCTestCase
@end

@implementation TestSlateLegacyMigration

// Shaped like a real-world config: section headers with underlines, a hyper
// key, monitor aliases, positions built from aliases, and commented-out lines.
static NSString *const kLegacy =
  @"# GLOBAL CONFIGURATIONS\n"
  @"# -------------------------------------------------------------------\n"
  @"# See https://github.com/jigish/slate/wiki/Global-Configs\n"
  @"\n"
  @"config defaultToCurrentScreen true\n"
  @"config secondsBeforeRepeat 0.4\n"
  @"config keyboardLayout \"qwerty\"\n"
  @"config nudgePercentOf screenSize\n"
  @"\n"
  @"# HYPER KEY\n"
  @"# -------------------------------------------------------------------\n"
  @"\n"
  @"alias hyper ctrl;alt;cmd\n"
  @"alias shyper shift;ctrl;alt;cmd\n"
  @"\n"
  @"# MONITOR ALIASES\n"
  @"# -------------------------------------------------------------------\n"
  @"\n"
  @"alias monitor-macbook 1\n"
  @"alias monitor-samsung 0\n"
  @"alias monitor-samsung-size 5120x1440\n"
  @"\n"
  @"# APPLICATION ALIASES AND BINDINGS\n"
  @"# -------------------------------------------------------------------\n"
  @"\n"
  @"bind c:alt;shift focus 'Google Chrome'\n"
  @"bind f:alt;shift focus 'Finder'\n"
  @"\n"
  @"# SLATE FEATURES\n"
  @"# -------------------------------------------------------------------\n"
  @"\n"
  @"# Show quick key overlays for each window\n"
  @"config windowHintsShowIcons true\n"
  @"bind h:cmd;shift hint ASDFHJKLQWERTYUIOPCVBNG\n"
  @"\n"
  @"# Show a positioning grid for each monitor\n"
  @"#bind g:cmd grid padding:5 0:6,2 1:8,3\n"
  @"\n"
  @"# Reload Slate configuration file\n"
  @"bind r:${hyper} relaunch\n"
  @"# GENERAL POSITION ALIASES AND BINDINGS\n"
  @"# -------------------------------------------------------------------\n"
  @"# These positions are not tied to any screen. Each position gets an \n"
  @"# alias and then a keybinding. The keybindings are all mapped to the \n"
  @"# numberpad, with each row grouping a denominator.\n"
  @"\n"
  @"# Aliases\n"
  @"alias full move screenOriginX;screenOriginY screenSizeX;screenSizeY\n"
  @"alias lefthalf move screenOriginX;screenOriginY screenSizeX/2;screenSizeY\n"
  @"alias third1 move screenOriginX;screenOriginY screenSizeX/3;screenSizeY\n"
  @"# alias tophalf move screenOriginX;screenOriginY screenSizeX;screenSizeY/2\n"
  @"\n"
  @"# Keypad 5 = fullscreen\n"
  @"bind pad5:${hyper} ${full}\n"
  @"bind 5:${hyper} ${full}\n"
  @"\n"
  @"# Keypad 7 9 = thirds\n"
  @"#bind pad7:${hyper} ${third1}\n"
  @"\n"
  @"# MONITOR-BASED POSITION ALIASES\n"
  @"# -------------------------------------------------------------------\n"
  @"\n"
  @"alias samsung-full move screenOriginX;screenOriginY screenSizeX;screenSizeY ${monitor-samsung-size}\n"
  @"\n"
  @"# BINDINGS\n"
  @"# -------------------------------------------------------------------\n"
  @"\n"
  @"# Throw\n"
  @"bind pad4:${hyper}  ${lefthalf} ${monitor-samsung}\n"
  @"bind pad2:${hyper}     throw ${monitor-macbook} resize full\n"
  @"bind s:${shyper} ${samsung-full}\n"
  @"\n"
  @"# Resize \n"
  @"bind right:ctrl;cmd       resize +5% +0\n"
  @"\n"
  @"# Push \n"
  @"# bind right:ctrl;cmd  push right bar-resize:screenSizeX/3\n";

#pragma mark - Helpers

// The legacy pipeline for active bind lines: strip comments, expand aliases
// as they were defined so far, then split "bind <keystroke> <op>".
- (NSArray<NSString *> *)legacyExpandedBindings:(NSString *)source {
  NSMutableDictionary *aliases = [NSMutableDictionary dictionary];
  NSMutableArray *result = [NSMutableArray array];
  for (NSString *raw in [source componentsSeparatedByString:@"\n"]) {
    NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSRange hash = [line rangeOfString:@"#"];
    if (hash.location != NSNotFound) line = [[line substringToIndex:hash.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([line length] == 0) continue;
    for (NSString *name in aliases) line = [line stringByReplacingOccurrencesOfString:name withString:aliases[name]];
    NSMutableArray *tokens = [NSMutableArray array];
    [StringTokenizer tokenize:line into:tokens maxTokens:3];
    if ([tokens[0] isEqualToString:@"alias"]) {
      aliases[[NSString stringWithFormat:@"${%@}", tokens[1]]] = tokens[2];
    } else if ([tokens[0] isEqualToString:@"bind"]) {
      NSString *op = [tokens[2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      [result addObject:[NSString stringWithFormat:@"%@ %@", tokens[1], op]];
    }
  }
  return result;
}

// Runs a written ~/.slate.js through the same resolver slate.applyConfig uses.
- (NSArray<NSString *> *)resolvedBindings:(SlateConfigDocument *)doc {
  JSContext *context = [[JSContext alloc] init];
  NSString *path = [[NSBundle bundleForClass:[SlateConfigDocument class]] pathForResource:@"managed-config" ofType:@"js"];
  [context evaluateScript:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]];
  [context evaluateScript:@"var captured; var slate = { applyConfig: function(c) { captured = c; } };"];
  [context evaluateScript:[doc stringRepresentation]];
  NSArray *bindings = [[context evaluateScript:@"_slateManagedConfig.resolve(captured).bindings"] toArray];
  XCTAssertNil(context.exception, @"%@", context.exception);
  NSMutableArray *result = [NSMutableArray array];
  for (NSDictionary *b in bindings) [result addObject:[NSString stringWithFormat:@"%@ %@", b[@"hotkey"], b[@"action"]]];
  return result;
}

- (SlateBindingEntry *)bindingWithKey:(NSString *)key modifiers:(NSString *)mods in:(SlateConfigDocument *)doc {
  for (SlateBindingEntry *b in doc.bindings) {
    if ([b.key isEqualToString:key] && ((mods == nil && b.modifiers == nil) || [b.modifiers isEqualToString:mods])) return b;
  }
  return nil;
}

- (NSString *)tempDirectory {
  NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  [self addTeardownBlock:^{ [[NSFileManager defaultManager] removeItemAtPath:dir error:nil]; }];
  return dir;
}

#pragma mark - Converting

- (void)testBindingsMatchLegacyBehavior {
  NSMutableArray *warnings = [NSMutableArray array];
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromLegacySource:kLegacy warnings:warnings];
  XCTAssertEqualObjects(warnings, @[]);
  XCTAssertEqualObjects([self resolvedBindings:doc], [self legacyExpandedBindings:kLegacy],
                        @"every active binding expands to the same hotkey and operation as before");
}

- (void)testSettingsAreTyped {
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromLegacySource:kLegacy warnings:[NSMutableArray array]];
  NSDictionary *expected = @{ @"defaultToCurrentScreen": @YES, @"secondsBeforeRepeat": @0.4, @"keyboardLayout": @"qwerty",
                              @"nudgePercentOf": @"screenSize", @"windowHintsShowIcons": @YES };
  XCTAssertEqual([doc.settings count], [expected count]);
  for (SlateConfigEntry *entry in doc.settings) {
    XCTAssertEqualObjects(entry, [SlateConfigEntry entryWithName:entry.name value:expected[entry.name]]);
  }
}

- (void)testAliasesAreSortedIntoSections {
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromLegacySource:kLegacy warnings:[NSMutableArray array]];
  XCTAssertEqualObjects([doc.modifiers valueForKey:@"name"], (@[@"hyper", @"shyper"]));
  XCTAssertEqualObjects([doc.monitors valueForKey:@"name"], (@[@"monitor-macbook", @"monitor-samsung", @"monitor-samsung-size"]));
  XCTAssertEqualObjects([doc.positions valueForKey:@"name"], (@[@"full", @"lefthalf", @"third1", @"samsung-full"]));
  XCTAssertEqual([doc.aliases count], 0u);
  SlateConfigEntry *samsungFull = doc.positions[3];
  XCTAssertTrue([samsungFull.value hasSuffix:@"${monitor-samsung-size}"], @"references stay as written: %@", samsungFull.value);
}

- (void)testGroupsNotesAndDisabledBindings {
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromLegacySource:kLegacy warnings:[NSMutableArray array]];

  SlateBindingEntry *chrome = [self bindingWithKey:@"c" modifiers:@"alt;shift" in:doc];
  XCTAssertEqualObjects(chrome.group, @"Application aliases and bindings");
  XCTAssertEqualObjects(chrome.action, @"focus 'Google Chrome'");
  XCTAssertNil(chrome.note);

  SlateBindingEntry *hint = [self bindingWithKey:@"h" modifiers:@"cmd;shift" in:doc];
  XCTAssertEqualObjects(hint.group, @"Slate features");
  XCTAssertEqualObjects(hint.note, @"Show quick key overlays for each window");

  SlateBindingEntry *grid = [self bindingWithKey:@"g" modifiers:@"cmd" in:doc];
  XCTAssertFalse(grid.enabled, @"commented-out binds become disabled bindings");
  XCTAssertEqualObjects(grid.action, @"grid padding:5 0:6,2 1:8,3");
  XCTAssertEqualObjects(grid.note, @"Show a positioning grid for each monitor");

  SlateBindingEntry *full = [self bindingWithKey:@"5" modifiers:@"${hyper}" in:doc];
  XCTAssertEqualObjects(full.note, @"Keypad 5 = fullscreen", @"a note applies to every binding in its paragraph");

  SlateBindingEntry *thirds = [self bindingWithKey:@"pad7" modifiers:@"${hyper}" in:doc];
  XCTAssertFalse(thirds.enabled);
  XCTAssertEqualObjects(thirds.group, @"General position aliases and bindings");

  SlateBindingEntry *push = [self bindingWithKey:@"right" modifiers:@"ctrl;cmd" in:doc];
  XCTAssertTrue(push.enabled, @"the active resize binding, not the commented-out push");
  XCTAssertEqualObjects(push.action, @"resize +5% +0");
  XCTAssertEqualObjects(push.group, @"Bindings");
  XCTAssertEqualObjects(push.note, @"Resize");

  XCTAssertEqual([doc.bindings count], 13u);
  XCTAssertEqual([[doc.bindings filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"enabled == NO"]] count], 3u);
}

- (void)testCommentedOutLinesAreKeptAsComments {
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromLegacySource:kLegacy warnings:[NSMutableArray array]];
  XCTAssertTrue([doc.customCode rangeOfString:@"// alias tophalf move screenOriginX;screenOriginY screenSizeX;screenSizeY/2\n"].location != NSNotFound,
                @"%@", doc.customCode);
  XCTAssertTrue([doc.customCode rangeOfString:@"alias and then a keybinding"].location == NSNotFound,
                @"prose starting with 'alias' isn't a commented-out alias: %@", doc.customCode);
}

- (void)testUnsupportedLinesWarnAndAreKept {
  NSString *legacy = @"alias hyper ctrl;alt;cmd\n"
                     @"layout work 'iTerm2':REPEAT move screenOriginX;screenOriginY screenSizeX;screenSizeY\n"
                     @"config windowHintsFontColor:'Finder' 255;255;255;1.0\n"
                     @"alias hyper cmd\n"
                     @"bind r:${hyper} relaunch\n";
  NSMutableArray *warnings = [NSMutableArray array];
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromLegacySource:legacy warnings:warnings];
  XCTAssertEqual([warnings count], 3u, @"%@", warnings);
  XCTAssertTrue([warnings[0] hasPrefix:@"Line 2 \"layout\" lines aren't supported"], @"%@", warnings[0]);
  XCTAssertTrue([warnings[1] hasPrefix:@"Line 3: per-app configs"], @"%@", warnings[1]);
  XCTAssertTrue([warnings[2] hasPrefix:@"Line 4: alias \"hyper\" is defined twice"], @"%@", warnings[2]);
  XCTAssertTrue([doc.customCode rangeOfString:@"// layout work 'iTerm2':REPEAT"].location != NSNotFound, @"%@", doc.customCode);
  XCTAssertEqualObjects(doc.modifiers[0].value, @"ctrl;alt;cmd");
  XCTAssertEqual([doc.bindings count], 1u);
}

- (void)testConvertedDocumentRoundTrips {
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromLegacySource:kLegacy warnings:[NSMutableArray array]];
  NSError *error = nil;
  SlateConfigDocument *reread = [SlateConfigDocument documentFromString:[doc stringRepresentation] error:&error];
  XCTAssertNotNil(reread, @"%@", error);
  XCTAssertEqualObjects(reread.bindings, doc.bindings);
  XCTAssertEqualObjects(reread.customCode, doc.customCode);
}

#pragma mark - Merging

- (void)testMergeIntoManagedFile {
  NSString *legacy = @"config secondsBeforeRepeat 0.4\nconfig keyboardLayout dvorak\n"
                     @"alias hyper ctrl;alt;cmd\nalias full move 0;0 1;1\n"
                     @"bind r:${hyper} relaunch\n";
  NSString *js = @"var config = {\n"
                 @"  settings: { keyboardLayout: 'colemak' },\n"
                 @"  modifiers: { hyper: 'cmd;shift' },\n"
                 @"  bindings: [{ key: 'x', mods: '${hyper}', action: 'relaunch' }],\n"
                 @"};\nslate.applyConfig(config);\n";
  NSMutableArray *warnings = [NSMutableArray array];
  SlateConfigDocument *legacyDoc = [SlateLegacyMigration documentFromLegacySource:legacy warnings:warnings];
  SlateConfigDocument *merged = [SlateLegacyMigration documentByMergingLegacy:legacyDoc intoJavaScript:js warnings:warnings];

  XCTAssertEqualObjects([merged.settings valueForKey:@"name"], (@[@"secondsBeforeRepeat", @"keyboardLayout"]));
  XCTAssertEqualObjects(merged.settings[1].value, @"colemak", @"~/.slate.js wins, as it loaded last");
  XCTAssertEqualObjects(merged.modifiers[0].value, @"cmd;shift");
  XCTAssertEqual([warnings count], 1u, @"%@", warnings);
  XCTAssertEqualObjects([merged.positions valueForKey:@"name"], (@[@"full"]));
  XCTAssertEqualObjects([merged.bindings valueForKey:@"key"], (@[@"r", @"x"]), @"~/.slate bindings first, as before");
}

- (void)testMergeIntoHandWrittenFileKeepsItAsCustomCode {
  NSString *js = @"slate.bind('g:cmd', slate.op('grid'));\n";
  SlateConfigDocument *legacyDoc = [SlateLegacyMigration documentFromLegacySource:@"bind r:cmd relaunch\n" warnings:[NSMutableArray array]];
  SlateConfigDocument *merged = [SlateLegacyMigration documentByMergingLegacy:legacyDoc intoJavaScript:js warnings:[NSMutableArray array]];
  XCTAssertTrue([merged.customCode hasSuffix:js], @"%@", merged.customCode);
  XCTAssertEqual([merged.bindings count], 1u);
  XCTAssertNotNil([SlateConfigDocument documentFromString:[merged stringRepresentation] error:nil]);
}

#pragma mark - Files

- (void)testMigrateFileWritesJsAndRenamesLegacy {
  NSString *dir = [self tempDirectory];
  NSString *legacyPath = [dir stringByAppendingPathComponent:@".slate"];
  NSString *jsPath = [dir stringByAppendingPathComponent:@".slate.js"];
  [kLegacy writeToFile:legacyPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

  NSError *error = nil;
  NSString *backup = [SlateLegacyMigration migrateLegacyFile:legacyPath toFile:jsPath warnings:[NSMutableArray array] error:&error];
  XCTAssertNotNil(backup, @"%@", error);

  NSFileManager *fm = [NSFileManager defaultManager];
  XCTAssertFalse([fm fileExistsAtPath:legacyPath], @"~/.slate no longer loads");
  XCTAssertTrue([[backup lastPathComponent] hasPrefix:@".slate.migrated-"], @"%@", backup);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:backup encoding:NSUTF8StringEncoding error:nil], kLegacy);
  SlateConfigDocument *written = [SlateConfigDocument documentWithContentsOfFile:jsPath error:&error];
  XCTAssertNotNil(written, @"%@", error);
  XCTAssertEqualObjects([self resolvedBindings:written], [self legacyExpandedBindings:kLegacy]);
}

- (void)testMigrateFileMergesIntoExistingJs {
  NSString *dir = [self tempDirectory];
  NSString *legacyPath = [dir stringByAppendingPathComponent:@".slate"];
  NSString *jsPath = [dir stringByAppendingPathComponent:@".slate.js"];
  NSString *js = @"slate.log('hello');\n";
  [@"bind r:cmd relaunch\n" writeToFile:legacyPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [js writeToFile:jsPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

  NSError *error = nil;
  XCTAssertNotNil([SlateLegacyMigration migrateLegacyFile:legacyPath toFile:jsPath warnings:[NSMutableArray array] error:&error], @"%@", error);
  SlateConfigDocument *written = [SlateConfigDocument documentWithContentsOfFile:jsPath error:&error];
  XCTAssertEqual([written.bindings count], 1u, @"%@", error);
  XCTAssertTrue([written.customCode hasSuffix:js]);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[jsPath stringByAppendingString:@".bak"] encoding:NSUTF8StringEncoding error:nil], js);
}

- (void)testMigrateFileFollowsSymlinkedLegacyFile {
  NSString *dir = [self tempDirectory];
  NSString *target = [dir stringByAppendingPathComponent:@"dotfiles-slate"];
  NSString *legacyPath = [dir stringByAppendingPathComponent:@".slate"];
  [@"bind r:cmd relaunch\n" writeToFile:target atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [[NSFileManager defaultManager] createSymbolicLinkAtPath:legacyPath withDestinationPath:target error:nil];

  NSError *error = nil;
  NSString *backup = [SlateLegacyMigration migrateLegacyFile:legacyPath
                                                      toFile:[dir stringByAppendingPathComponent:@".slate.js"]
                                                    warnings:[NSMutableArray array] error:&error];
  XCTAssertNotNil(backup, @"%@", error);
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:target], @"the symlink's target is left alone");
  XCTAssertEqualObjects([[NSFileManager defaultManager] attributesOfItemAtPath:backup error:nil][NSFileType], NSFileTypeSymbolicLink);
}

- (void)testMigrateFileFailsWithoutChangingAnything {
  NSString *dir = [self tempDirectory];
  NSString *legacyPath = [dir stringByAppendingPathComponent:@".slate"];
  NSString *jsPath = [dir stringByAppendingPathComponent:@".slate.js"];
  [@"bind r:${nope} relaunch\n" writeToFile:legacyPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

  NSError *error = nil;
  XCTAssertNil([SlateLegacyMigration migrateLegacyFile:legacyPath toFile:jsPath warnings:[NSMutableArray array] error:&error]);
  XCTAssertEqual(error.code, SlateConfigDocumentErrorInvalid);
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:legacyPath]);
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:jsPath]);
}

@end
