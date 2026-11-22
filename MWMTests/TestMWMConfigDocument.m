//
//  TestMWMConfigDocument.m
//  Slate
//
//  Tests for the ~/.mwm.yml format: reading, resolving aliases and writing
//  used by slate.applyConfig, and MWMConfigDocument reading and writing.
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
#import "MWMConfigDocument.h"

@interface TestMWMConfigDocument : XCTestCase
@end

@implementation TestMWMConfigDocument

static NSString *const kSample =
  @"settings:\n"
  @"  defaultToCurrentScreen: true\n"
  @"  secondsBeforeRepeat: 0.4\n"
  @"  keyboardLayout: qwerty\n"
  @"modifiers:\n"
  @"  hyper: \"ctrl;alt;cmd\"\n"
  @"  shyper: 'shift;ctrl;alt;cmd'\n"
  @"monitors:\n"
  @"  monitor-samsung: \"0\"\n"
  @"  monitor-samsung-size: 5120x1440\n"
  @"positions:\n"
  @"  lefthalf: move screenOriginX;screenOriginY screenSizeX/2;screenSizeY\n"
  @"  samsung-full: \"move screenOriginX;screenOriginY screenSizeX;screenSizeY ${monitor-samsung-size}\"\n"
  @"bindings:\n"
  @"  - group: Apps\n"
  @"    key: c\n"
  @"    mods: alt;shift\n"
  @"    action: \"focus 'Google Chrome'\"\n";

// kSample with more bindings.
- (NSString *)sample {
  return [kSample stringByAppendingString:
    @"  # Layout\n"
    @"  - group: Layout\n"
    @"    key: pad4\n"
    @"    mods: ${hyper}\n"
    @"    action: ${lefthalf} ${monitor-samsung}  # comment\n"
    @"  - group: Layout\n"
    @"    key: pad7\n"
    @"    mods: ${hyper}\n"
    @"    action: ${lefthalf}\n"
    @"    enabled: false\n"
    @"    note: thirds\n"
    @"  - key: esc\n"
    @"    action: relaunch\n"
    @"    repeat: false\n"];
}

#pragma mark - Reading

- (void)testReadsSample {
  NSError *error = nil;
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:[self sample] error:&error];
  XCTAssertNotNil(doc, @"%@", error);

  XCTAssertEqual([doc.settings count], 3u);
  XCTAssertEqualObjects(doc.settings[0], [MWMConfigEntry entryWithName:@"defaultToCurrentScreen" value:@YES]);
  XCTAssertEqualObjects(doc.settings[1].value, @0.4);
  XCTAssertEqualObjects(doc.settings[2].value, @"qwerty");
  XCTAssertEqualObjects([doc.modifiers valueForKey:@"name"], (@[@"hyper", @"shyper"]), @"order is preserved");
  XCTAssertEqualObjects(doc.modifiers[1].value, @"shift;ctrl;alt;cmd");
  XCTAssertEqualObjects([doc.monitors valueForKey:@"name"], (@[@"monitor-samsung", @"monitor-samsung-size"]));
  XCTAssertEqualObjects(doc.monitors[0].value, @"0", @"a quoted number stays text");
  XCTAssertEqual([doc.positions count], 2u);
  XCTAssertEqual([doc.aliases count], 0u);

  XCTAssertEqual([doc.bindings count], 4u);
  XCTAssertEqualObjects(doc.bindings[0].action, @"focus 'Google Chrome'");
  XCTAssertEqualObjects(doc.bindings[1].action, @"${lefthalf} ${monitor-samsung}", @"trailing comment dropped");
  MWMBindingEntry *disabled = doc.bindings[2];
  XCTAssertFalse(disabled.enabled);
  XCTAssertEqualObjects(disabled.note, @"thirds");
  XCTAssertEqualObjects(disabled.modifiers, @"${hyper}", @"aliases stay unexpanded in the model");
  XCTAssertNil(doc.bindings[3].group);
  XCTAssertNil(doc.bindings[3].modifiers);
  XCTAssertEqualObjects(doc.bindings[3].repeat, @NO);
  XCTAssertEqual(doc.bindings[3].line, 30u, @"bindings remember their line");
}

- (void)testEmptyFileIsAnEmptyConfiguration {
  NSError *error = nil;
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:@"# nothing yet\n" error:&error];
  XCTAssertNotNil(doc, @"%@", error);
  XCTAssertEqual([doc.bindings count], 0u);
}

- (void)testResolveExpandsAliasesAndSkipsDisabledBindings {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:[self sample] error:nil];
  NSError *error = nil;
  MWMResolvedConfig *resolved = [doc resolve:&error];
  XCTAssertNotNil(resolved, @"%@", error);

  NSArray<MWMResolvedBinding *> *bindings = resolved.bindings;
  XCTAssertEqual([bindings count], 3u, @"the disabled binding is skipped");
  XCTAssertEqualObjects(bindings[0].hotkey, @"c:alt;shift");
  XCTAssertEqualObjects(bindings[0].action, @"focus 'Google Chrome'");
  XCTAssertEqualObjects(bindings[1].hotkey, @"pad4:ctrl;alt;cmd");
  XCTAssertEqualObjects(bindings[1].action, @"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY 0");
  XCTAssertNil(bindings[1].repeat, @"repeat is left to the operation default");
  XCTAssertEqualObjects(bindings[2].hotkey, @"esc", @"no modifiers means a bare key");
  XCTAssertEqualObjects(bindings[2].repeat, @NO);
  XCTAssertEqual(bindings[2].index, 3u);
  XCTAssertEqualObjects(resolved.settings[1].value, @0.4);
}

- (void)testResolveExpandsNestedAliases {
  NSString *yaml = @"monitors:\n  size: 5120x1440\npositions:\n  full: move 0;0 1;1 ${size}\nbindings:\n  - key: f\n    action: ${full}\n";
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:yaml error:nil];
  XCTAssertEqualObjects([doc resolve:nil].bindings[0].action, @"move 0;0 1;1 5120x1440");
}

- (void)assertYAML:(NSString *)yaml failsWith:(NSString *)fragment {
  NSError *error = nil;
  XCTAssertNil([MWMConfigDocument documentFromString:yaml error:&error], @"%@ should fail", yaml);
  NSString *message = [error localizedDescription];
  XCTAssertTrue([message rangeOfString:fragment].location != NSNotFound, @"'%@' should mention '%@'", message, fragment);
}

- (void)testRejectsBadConfigs {
  [self assertYAML:@"bindings:\n  - key: a\n    action: ${nope}\n" failsWith:@"Unknown alias ${nope}"];
  [self assertYAML:@"aliases:\n  a: ${b}\n  b: ${a}\nbindings:\n  - key: x\n    action: ${a}\n" failsWith:@"loop"];
  [self assertYAML:@"modifiers:\n  hyper: cmd\naliases:\n  hyper: ctrl\n" failsWith:@"defined more than once"];
  [self assertYAML:@"layouts: {}\n" failsWith:@"Unknown section \"layouts\""];
  [self assertYAML:@"bindings:\n  - key: a\n" failsWith:@"needs an action"];
  [self assertYAML:@"bindings:\n  - action: relaunch\n" failsWith:@"needs a key"];
  [self assertYAML:@"bindings:\n  - key: a\n    action: relaunch\n    acton: x\n" failsWith:@"unknown field \"acton\""];
  [self assertYAML:@"bindings:\n  - key: a\n    action: relaunch\n    repeat: yes\n" failsWith:@"repeat should be true or false"];
  [self assertYAML:@"settings:\n  x:\n    y: 1\n" failsWith:@"should be text, a number, or true/false"];
  [self assertYAML:@"bindings:\n  key: a\n" failsWith:@"bindings should be a list"];
  [self assertYAML:@"- a\n- b\n" failsWith:@"mapping of sections"];
}

- (void)testErrorsPointAtTheLineAndBinding {
  NSError *error = nil;
  NSString *yaml = @"bindings:\n  - key: a\n    action: relaunch\n  - key: b\n    action: ${missing}\n";
  XCTAssertNil([MWMConfigDocument documentFromString:yaml error:&error]);
  XCTAssertEqual(error.code, MWMConfigDocumentErrorInvalid);
  XCTAssertEqualObjects(error.userInfo[MWMConfigDocumentErrorLineKey], @4);
  XCTAssertEqualObjects(error.userInfo[MWMConfigDocumentErrorBindingIndexKey], @1);
}

- (void)testSyntaxErrorReportsLine {
  NSError *error = nil;
  XCTAssertNil([MWMConfigDocument documentFromString:@"settings:\n  a: \"open\n" error:&error]);
  XCTAssertEqual(error.code, MWMConfigDocumentErrorSyntax);
  XCTAssertEqualObjects(error.userInfo[MWMConfigDocumentErrorLineKey], @2);
}

- (void)testLenientReadKeepsUnknownAliases {
  NSString *yaml = @"bindings:\n  - key: a\n    action: ${typo}\n";
  NSError *error = nil;
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:yaml lenient:YES error:&error];
  XCTAssertNotNil(doc, @"%@", error);
  NSMutableArray *errors = [NSMutableArray array];
  MWMResolvedConfig *resolved = [doc resolveCollectingErrors:errors];
  XCTAssertEqual([errors count], 1u);
  XCTAssertEqual([resolved.bindings count], 0u, @"the broken binding is left out");
}

#pragma mark - Writing

- (void)testRoundTrip {
  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:[self sample] error:nil];
  [doc.aliases addObject:[MWMConfigEntry entryWithName:@"needs: quoting" value:@"say \"hi\"\\ # not a comment"]];
  [doc.aliases addObject:[MWMConfigEntry entryWithName:@"yes" value:@"true"]];
  [doc.aliases addObject:[MWMConfigEntry entryWithName:@"n" value:@12]];
  NSString *written = [doc stringRepresentation];

  NSError *error = nil;
  MWMConfigDocument *reread = [MWMConfigDocument documentFromString:written error:&error];
  XCTAssertNotNil(reread, @"%@\n%@", error, written);
  XCTAssertEqualObjects(reread.settings, doc.settings);
  XCTAssertEqualObjects(reread.modifiers, doc.modifiers);
  XCTAssertEqualObjects(reread.monitors, doc.monitors);
  XCTAssertEqualObjects(reread.positions, doc.positions);
  XCTAssertEqualObjects(reread.aliases, doc.aliases);
  XCTAssertEqualObjects(reread.bindings, doc.bindings);
  XCTAssertEqualObjects([reread stringRepresentation], written, @"writing is stable");
}

- (void)testWritesReadableFormat {
  MWMConfigDocument *doc = [[MWMConfigDocument alloc] init];
  [doc.settings addObject:[MWMConfigEntry entryWithName:@"defaultToCurrentScreen" value:@YES]];
  [doc.monitors addObject:[MWMConfigEntry entryWithName:@"monitor-macbook" value:@"1"]];
  MWMBindingEntry *binding = [MWMBindingEntry bindingWithKey:@"r" modifiers:@"${hyper}" action:@"relaunch"];
  binding.group = @"Features";
  binding.enabled = NO;
  [doc.bindings addObject:binding];

  NSString *written = [doc stringRepresentation];
  XCTAssertTrue([written hasPrefix:@"# MWM configuration"], @"%@", written);
  XCTAssertTrue([written containsString:@"\nsettings:\n  defaultToCurrentScreen: true\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"\nmonitors:\n  monitor-macbook: {screen: \"1\"}\n"], @"%@", written);
  XCTAssertTrue([written containsString:@"\nmodifiers: {}\n"], @"%@", written);
  XCTAssertTrue([written hasSuffix:
    @"\nbindings:\n"
    @"  - group: Features\n"
    @"    key: r\n"
    @"    mods: \"${hyper}\"\n"
    @"    action: {type: relaunch}\n"
    @"    enabled: false\n"], @"%@", written);
}

- (void)testWriteKeepsBackupAndFollowsSymlink {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  NSString *real = [dir stringByAppendingPathComponent:@"dotfiles-mwm.yml"];
  NSString *link = [dir stringByAppendingPathComponent:@".mwm.yml"];
  [@"# old\n" writeToFile:real atomically:YES encoding:NSUTF8StringEncoding error:nil];
  XCTAssertTrue([fm createSymbolicLinkAtPath:link withDestinationPath:real error:nil]);

  MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kSample error:nil];
  NSError *error = nil;
  XCTAssertTrue([doc writeToFile:link error:&error], @"%@", error);

  NSDictionary *attrs = [fm attributesOfItemAtPath:link error:nil];
  XCTAssertEqualObjects(attrs[NSFileType], NSFileTypeSymbolicLink, @"the symlink is not replaced");
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:real encoding:NSUTF8StringEncoding error:nil], [doc stringRepresentation]);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[real stringByAppendingString:@".bak"] encoding:NSUTF8StringEncoding error:nil], @"# old\n");

  MWMConfigDocument *reread = [MWMConfigDocument documentWithContentsOfFile:link error:&error];
  XCTAssertEqualObjects(reread.bindings, doc.bindings, @"%@", error);
  [fm removeItemAtPath:dir error:nil];
}

@end
