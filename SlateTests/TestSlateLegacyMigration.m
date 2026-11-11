//
//  TestSlateLegacyMigration.m
//  Slate
//
//  Tests for converting ~/.slate and ~/.slate.js into ~/.slate.yml.
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

// What Slate registers from a converted document, as "hotkey action" lines.
- (NSArray<NSString *> *)resolvedBindings:(SlateConfigDocument *)doc {
  NSError *error = nil;
  SlateConfigDocument *reread = [SlateConfigDocument documentFromString:[doc stringRepresentation] error:&error];
  XCTAssertNotNil(reread, @"%@", error);
  SlateResolvedConfig *resolved = [reread resolve:&error];
  XCTAssertNotNil(resolved, @"%@", error);
  NSMutableArray *result = [NSMutableArray array];
  for (SlateResolvedBinding *b in resolved.bindings) [result addObject:[NSString stringWithFormat:@"%@ %@", b.hotkey, b.action]];
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
  XCTAssertEqual([warnings count], 1u, @"only the note about the commented-out alias: %@", warnings);
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

- (void)testCommentedOutLinesAreMentioned {
  NSMutableArray *warnings = [NSMutableArray array];
  [SlateLegacyMigration documentFromLegacySource:kLegacy warnings:warnings];
  XCTAssertTrue([warnings[0] containsString:@"1 commented-out line (like \"alias tophalf"], @"%@", warnings);
  XCTAssertFalse([warnings[0] containsString:@"alias and then a keybinding"], @"prose starting with 'alias' isn't a commented-out alias");
}

- (void)testUnsupportedLinesWarnAndAreKept {
  NSString *legacy = @"alias hyper ctrl;alt;cmd\n"
                     @"layout work 'iTerm2':REPEAT move screenOriginX;screenOriginY screenSizeX;screenSizeY\n"
                     @"config windowHintsFontColor:'Finder' 255;255;255;1.0\n"
                     @"alias hyper cmd\n"
                     @"bind r:${hyper} relaunch\n";
  NSMutableArray *warnings = [NSMutableArray array];
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromLegacySource:legacy warnings:warnings];
  XCTAssertEqual([warnings count], 4u, @"%@", warnings);
  XCTAssertTrue([warnings[0] hasPrefix:@"Line 2 \"layout\" lines aren't supported"], @"%@", warnings[0]);
  XCTAssertTrue([warnings[1] hasPrefix:@"Line 3: per-app configs"], @"%@", warnings[1]);
  XCTAssertTrue([warnings[2] hasPrefix:@"Line 4: alias \"hyper\" is defined twice"], @"%@", warnings[2]);
  XCTAssertTrue([warnings[3] containsString:@"still in the backup"], @"%@", warnings[3]);
  XCTAssertEqualObjects(doc.modifiers[0].value, @"ctrl;alt;cmd");
  XCTAssertEqual([doc.bindings count], 1u);
}

- (void)testConvertedDocumentRoundTrips {
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromLegacySource:kLegacy warnings:[NSMutableArray array]];
  NSError *error = nil;
  SlateConfigDocument *reread = [SlateConfigDocument documentFromString:[doc stringRepresentation] error:&error];
  XCTAssertNotNil(reread, @"%@", error);
  XCTAssertEqualObjects(reread.bindings, doc.bindings);
  XCTAssertEqualObjects(reread.positions, doc.positions);
}

#pragma mark - ~/.slate.js

static NSString *const kManagedJS =
  @"var config = {\n"
  @"  settings: { keyboardLayout: 'colemak', windowHintsSpread: true, order: ['a', 'b'] },\n"
  @"  modifiers: { hyper: 'cmd;shift' },\n"
  @"  bindings: [\n"
  @"    { group: 'Apps', key: 'x', mods: '${hyper}', action: 'relaunch', note: 'n' },\n"
  @"    { key: 'y', action: 'undo', enabled: false, repeat: true },\n"
  @"  ],\n"
  @"};\nslate.applyConfig(config);\n";

- (void)testReadsManagedJavaScript {
  NSMutableArray *warnings = [NSMutableArray array];
  NSError *error = nil;
  NSString *js = [kManagedJS stringByAppendingString:@"\n// ---- Custom code (preserved as-is by the configuration window) ----\n// just a note\n"];
  SlateConfigDocument *doc = [SlateLegacyMigration documentFromJavaScript:js warnings:warnings error:&error];
  XCTAssertNotNil(doc, @"%@", error);
  XCTAssertEqualObjects(doc.settings[0], [SlateConfigEntry entryWithName:@"keyboardLayout" value:@"colemak"]);
  XCTAssertEqualObjects(doc.settings[1], [SlateConfigEntry entryWithName:@"windowHintsSpread" value:@YES]);
  XCTAssertEqualObjects(doc.settings[2].value, @"a;b");
  XCTAssertEqualObjects(doc.modifiers[0].value, @"cmd;shift");
  XCTAssertEqual([doc.bindings count], 2u);
  XCTAssertEqualObjects(doc.bindings[0].group, @"Apps");
  XCTAssertEqualObjects(doc.bindings[0].note, @"n");
  XCTAssertFalse(doc.bindings[1].enabled);
  XCTAssertEqualObjects(doc.bindings[1].repeat, @YES);
  XCTAssertEqual([warnings count], 1u, @"%@", warnings);
  XCTAssertTrue([warnings[0] hasPrefix:@"1 comment line"], @"%@", warnings[0]);
}

- (void)testCustomJavaScriptIsNotCarriedOver {
  NSMutableArray *warnings = [NSMutableArray array];
  NSString *js = [kManagedJS stringByAppendingString:@"// ---- Custom code (preserved as-is by the configuration window) ----\nslate.bind('g:cmd', function() {});\n"];
  XCTAssertNotNil([SlateLegacyMigration documentFromJavaScript:js warnings:warnings error:nil]);
  XCTAssertTrue([warnings[0] containsString:@"no longer runs JavaScript"], @"%@", warnings);
}

- (void)testHandWrittenJavaScriptIsRefused {
  NSError *error = nil;
  XCTAssertNil([SlateLegacyMigration documentFromJavaScript:@"slate.bind('g:cmd', slate.op('grid'));\n" warnings:[NSMutableArray array] error:&error]);
  XCTAssertTrue([[error localizedDescription] containsString:@"can't be converted"], @"%@", error);
  XCTAssertNil([SlateLegacyMigration documentFromJavaScript:@"var config = {};\n" warnings:[NSMutableArray array] error:&error]);
}

#pragma mark - Merging

- (void)testMergeKeepsTheHigherFile {
  NSString *legacy = @"config secondsBeforeRepeat 0.4\nconfig keyboardLayout dvorak\n"
                     @"alias hyper ctrl;alt;cmd\nalias full move 0;0 1;1\n"
                     @"bind r:${hyper} relaunch\n";
  NSMutableArray *warnings = [NSMutableArray array];
  SlateConfigDocument *legacyDoc = [SlateLegacyMigration documentFromLegacySource:legacy warnings:warnings];
  SlateConfigDocument *js = [SlateLegacyMigration documentFromJavaScript:kManagedJS warnings:warnings error:nil];
  SlateConfigDocument *merged = [SlateLegacyMigration documentByMerging:legacyDoc into:js lowerName:@"~/.slate" higherName:@"~/.slate.js" warnings:warnings];

  XCTAssertEqualObjects([merged.settings valueForKey:@"name"], (@[@"secondsBeforeRepeat", @"keyboardLayout", @"windowHintsSpread", @"order"]));
  XCTAssertEqualObjects(merged.settings[1].value, @"colemak", @"~/.slate.js wins, as it loaded last");
  XCTAssertEqualObjects(merged.modifiers[0].value, @"cmd;shift");
  XCTAssertEqual([warnings count], 1u, @"%@", warnings);
  XCTAssertTrue([warnings[0] containsString:@"kept the ~/.slate.js value"], @"%@", warnings);
  XCTAssertEqualObjects([merged.positions valueForKey:@"name"], (@[@"full"]));
  XCTAssertEqualObjects([merged.bindings valueForKey:@"key"], (@[@"r", @"x", @"y"]), @"~/.slate bindings first, as before");
}

#pragma mark - Files

- (void)testMigrateFileWritesYAMLAndRenamesLegacy {
  NSString *dir = [self tempDirectory];
  NSString *legacyPath = [dir stringByAppendingPathComponent:@".slate"];
  NSString *ymlPath = [dir stringByAppendingPathComponent:@".slate.yml"];
  [kLegacy writeToFile:legacyPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

  NSError *error = nil;
  NSArray *backups = [SlateLegacyMigration migrateLegacyFile:legacyPath javaScriptFile:nil toFile:ymlPath warnings:[NSMutableArray array] error:&error];
  XCTAssertEqual([backups count], 1u, @"%@", error);

  NSFileManager *fm = [NSFileManager defaultManager];
  XCTAssertFalse([fm fileExistsAtPath:legacyPath], @"~/.slate no longer loads");
  XCTAssertTrue([[backups[0] lastPathComponent] hasPrefix:@".slate.migrated-"], @"%@", backups);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:backups[0] encoding:NSUTF8StringEncoding error:nil], kLegacy);
  SlateConfigDocument *written = [SlateConfigDocument documentWithContentsOfFile:ymlPath error:&error];
  XCTAssertNotNil(written, @"%@", error);
  XCTAssertEqualObjects([self resolvedBindings:written], [self legacyExpandedBindings:kLegacy]);
}

- (void)testMigrateBothFilesIntoExistingYAML {
  NSString *dir = [self tempDirectory];
  NSString *legacyPath = [dir stringByAppendingPathComponent:@".slate"];
  NSString *jsPath = [dir stringByAppendingPathComponent:@".slate.js"];
  NSString *ymlPath = [dir stringByAppendingPathComponent:@".slate.yml"];
  NSString *yml = @"settings:\n  keyboardLayout: qwerty\nbindings:\n  - key: z\n    action: relaunch\n";
  [@"bind r:cmd relaunch\n" writeToFile:legacyPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [kManagedJS writeToFile:jsPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [yml writeToFile:ymlPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

  NSError *error = nil;
  NSArray *backups = [SlateLegacyMigration migrateLegacyFile:legacyPath javaScriptFile:jsPath toFile:ymlPath warnings:[NSMutableArray array] error:&error];
  XCTAssertEqual([backups count], 2u, @"%@", error);
  SlateConfigDocument *written = [SlateConfigDocument documentWithContentsOfFile:ymlPath error:&error];
  XCTAssertEqualObjects([written.bindings valueForKey:@"key"], (@[@"r", @"x", @"y", @"z"]), @"%@", error);
  NSUInteger layout = [[written.settings valueForKey:@"name"] indexOfObject:@"keyboardLayout"];
  XCTAssertEqualObjects(written.settings[layout].value, @"qwerty", @"~/.slate.yml wins");
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[ymlPath stringByAppendingString:@".bak"] encoding:NSUTF8StringEncoding error:nil], yml);
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:jsPath]);
}

- (void)testMigrateFileFollowsSymlinkedLegacyFile {
  NSString *dir = [self tempDirectory];
  NSString *target = [dir stringByAppendingPathComponent:@"dotfiles-slate"];
  NSString *legacyPath = [dir stringByAppendingPathComponent:@".slate"];
  [@"bind r:cmd relaunch\n" writeToFile:target atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [[NSFileManager defaultManager] createSymbolicLinkAtPath:legacyPath withDestinationPath:target error:nil];

  NSError *error = nil;
  NSArray *backups = [SlateLegacyMigration migrateLegacyFile:legacyPath javaScriptFile:nil
                                                      toFile:[dir stringByAppendingPathComponent:@".slate.yml"]
                                                    warnings:[NSMutableArray array] error:&error];
  XCTAssertEqual([backups count], 1u, @"%@", error);
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:target], @"the symlink's target is left alone");
  XCTAssertEqualObjects([[NSFileManager defaultManager] attributesOfItemAtPath:backups[0] error:nil][NSFileType], NSFileTypeSymbolicLink);
}

- (void)testMigrateFileFailsWithoutChangingAnything {
  NSString *dir = [self tempDirectory];
  NSString *legacyPath = [dir stringByAppendingPathComponent:@".slate"];
  NSString *ymlPath = [dir stringByAppendingPathComponent:@".slate.yml"];
  [@"bind r:${nope} relaunch\n" writeToFile:legacyPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

  NSError *error = nil;
  XCTAssertNil([SlateLegacyMigration migrateLegacyFile:legacyPath javaScriptFile:nil toFile:ymlPath warnings:[NSMutableArray array] error:&error]);
  XCTAssertEqual(error.code, SlateConfigDocumentErrorInvalid);
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:legacyPath]);
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:ymlPath]);
}

@end
