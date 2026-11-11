//
//  TestSlateConfigDocument.m
//  Slate
//
//  Tests for the managed ~/.slate.js format: the managed-config.js resolver
//  used by slate.applyConfig, and SlateConfigDocument reading and writing.
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

@interface TestSlateConfigDocument : XCTestCase
@end

@implementation TestSlateConfigDocument

static NSString *const kSample =
  @"var config = {\n"
  @"  settings: { defaultToCurrentScreen: true, secondsBeforeRepeat: 0.4, keyboardLayout: \"qwerty\" },\n"
  @"  modifiers: { hyper: \"ctrl;alt;cmd\", shyper: \"shift;ctrl;alt;cmd\" },\n"
  @"  monitors: { \"monitor-samsung\": \"0\", \"monitor-samsung-size\": \"5120x1440\" },\n"
  @"  positions: {\n"
  @"    lefthalf: \"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY\",\n"
  @"    \"samsung-full\": \"move screenOriginX;screenOriginY screenSizeX;screenSizeY ${monitor-samsung-size}\",\n"
  @"  },\n"
  @"  bindings: [\n"
  @"    { group: \"Apps\", key: \"c\", mods: \"alt;shift\", action: \"focus 'Google Chrome'\" },\n"
  @"    { group: \"Layout\", key: \"pad4\", mods: \"${hyper}\", action: \"${lefthalf} ${monitor-samsung}\" },\n"
  @"    { group: \"Layout\", key: \"pad7\", mods: \"${hyper}\", action: \"${lefthalf}\", enabled: false, note: \"thirds\" },\n"
  @"    { key: \"esc\", action: \"relaunch\", repeat: false },\n"
  @"  ],\n"
  @"};\n"
  @"slate.applyConfig(config);\n";

#pragma mark - managed-config.js

- (JSContext *)runtimeContext {
  JSContext *context = [[JSContext alloc] init];
  NSString *path = [[NSBundle bundleForClass:[SlateConfigDocument class]] pathForResource:@"managed-config" ofType:@"js"];
  XCTAssertNotNil(path, @"managed-config.js should be bundled with the app");
  [context evaluateScript:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]];
  return context;
}

- (JSValue *)resolve:(NSString *)configLiteral inContext:(JSContext *)context {
  return [context evaluateScript:[NSString stringWithFormat:@"_slateManagedConfig.resolve(%@)", configLiteral]];
}

- (void)testResolveExpandsAliasesAndSkipsDisabledBindings {
  JSContext *context = [self runtimeContext];
  NSString *literal = [[kSample stringByReplacingOccurrencesOfString:@"var config = " withString:@"("]
                       stringByReplacingOccurrencesOfString:@"};\nslate.applyConfig(config);\n" withString:@"})"];
  NSDictionary *resolved = [[self resolve:literal inContext:context] toDictionary];
  XCTAssertNil(context.exception);

  NSArray *bindings = resolved[@"bindings"];
  XCTAssertEqual([bindings count], 3u, @"the disabled binding is skipped");
  XCTAssertEqualObjects(bindings[0][@"hotkey"], @"c:alt;shift");
  XCTAssertEqualObjects(bindings[0][@"action"], @"focus 'Google Chrome'");
  XCTAssertEqualObjects(bindings[1][@"hotkey"], @"pad4:ctrl;alt;cmd");
  XCTAssertEqualObjects(bindings[1][@"action"], @"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY 0");
  XCTAssertEqualObjects(bindings[2][@"hotkey"], @"esc", @"no modifiers means a bare key");
  XCTAssertEqualObjects(bindings[2][@"repeat"], @NO);
  XCTAssertNil(bindings[1][@"repeat"], @"repeat is left to the operation default");

  NSArray *settings = resolved[@"settings"];
  XCTAssertEqual([settings count], 3u);
  XCTAssertEqualObjects(settings[1][@"name"], @"secondsBeforeRepeat");
  XCTAssertEqualObjects(settings[1][@"value"], @0.4);
}

- (void)testResolveExpandsNestedAliases {
  JSContext *context = [self runtimeContext];
  JSValue *result = [self resolve:@"({ monitors: { size: '5120x1440' }, positions: { full: 'move 0;0 1;1 ${size}' },"
                                  @"   bindings: [{ key: 'f', action: '${full}' }] })" inContext:context];
  XCTAssertNil(context.exception);
  XCTAssertEqualObjects([result[@"bindings"][0][@"action"] toString], @"move 0;0 1;1 5120x1440");
}

- (void)assertResolveOf:(NSString *)literal failsWith:(NSString *)fragment {
  JSContext *context = [self runtimeContext];
  [self resolve:literal inContext:context];
  XCTAssertNotNil(context.exception, @"%@ should fail", literal);
  NSString *message = [context.exception toString];
  XCTAssertTrue([message rangeOfString:fragment].location != NSNotFound, @"'%@' should mention '%@'", message, fragment);
}

- (void)testResolveRejectsBadConfigs {
  [self assertResolveOf:@"({ bindings: [{ key: 'a', action: '${nope}' }] })" failsWith:@"Unrecognized alias ${nope}"];
  [self assertResolveOf:@"({ aliases: { a: '${b}', b: '${a}' }, bindings: [{ key: 'x', action: '${a}' }] })" failsWith:@"loop"];
  [self assertResolveOf:@"({ modifiers: { hyper: 'cmd' }, aliases: { hyper: 'ctrl' } })" failsWith:@"defined more than once"];
  [self assertResolveOf:@"({ layouts: {} })" failsWith:@"Unknown config section \"layouts\""];
  [self assertResolveOf:@"({ bindings: [{ key: 'a' }] })" failsWith:@"needs an action"];
  [self assertResolveOf:@"({ bindings: [{ action: 'relaunch' }] })" failsWith:@"needs a key"];
  [self assertResolveOf:@"({ settings: { x: {} } })" failsWith:@"must be a string, number, boolean, or array"];
}

// Loads the real runtime scripts (in the order JSController uses) against a
// recording stand-in controller, then runs slate.applyConfig.
- (void)testApplyConfigCallsController {
  JSContext *context = [[JSContext alloc] init];
  NSBundle *bundle = [NSBundle bundleForClass:[SlateConfigDocument class]];
  [context evaluateScript:
    @"var window = this;\n"
    @"var calls = [];\n"
    @"var _controller = {\n"
    @"  log: function() {},\n"
    @"  configNative: function(k, v) { calls.push(['config', k, String(v)]); },\n"
    @"  bindString: function(h, a, r) { calls.push(['bind', h, a, r === undefined ? 'default' : String(r)]); }\n"
    @"};\n"
    @"var _info = { jsMethods: function() { return []; } };\n"];
  for (NSString *script in @[@"underscore", @"utils", @"managed-config", @"initialize"]) {
    NSString *path = [bundle pathForResource:script ofType:@"js"];
    [context evaluateScript:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]];
    XCTAssertNil(context.exception, @"%@.js: %@", script, context.exception);
  }

  [context evaluateScript:kSample];
  XCTAssertNil(context.exception, @"%@", context.exception);
  NSArray *calls = [context[@"calls"] toArray];
  NSArray *expected = @[
    @[@"config", @"defaultToCurrentScreen", @"true"],
    @[@"config", @"secondsBeforeRepeat", @"0.4"],
    @[@"config", @"keyboardLayout", @"qwerty"],
    @[@"bind", @"c:alt;shift", @"focus 'Google Chrome'", @"default"],
    @[@"bind", @"pad4:ctrl;alt;cmd", @"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY 0", @"default"],
    @[@"bind", @"esc", @"relaunch", @"false"],
  ];
  XCTAssertEqualObjects(calls, expected);
}

#pragma mark - Reading

- (void)testReadsSample {
  NSError *error = nil;
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:kSample error:&error];
  XCTAssertNotNil(doc, @"%@", error);

  XCTAssertEqual([doc.settings count], 3u);
  XCTAssertEqualObjects(doc.settings[0], [SlateConfigEntry entryWithName:@"defaultToCurrentScreen" value:@YES]);
  XCTAssertEqualObjects(doc.settings[1].value, @0.4);
  XCTAssertEqualObjects([doc.modifiers valueForKey:@"name"], (@[@"hyper", @"shyper"]), @"order is preserved");
  XCTAssertEqualObjects([doc.monitors valueForKey:@"name"], (@[@"monitor-samsung", @"monitor-samsung-size"]));
  XCTAssertEqual([doc.positions count], 2u);
  XCTAssertEqual([doc.aliases count], 0u);

  XCTAssertEqual([doc.bindings count], 4u);
  SlateBindingEntry *disabled = doc.bindings[2];
  XCTAssertFalse(disabled.enabled);
  XCTAssertEqualObjects(disabled.note, @"thirds");
  XCTAssertEqualObjects(disabled.modifiers, @"${hyper}", @"aliases stay unexpanded in the model");
  XCTAssertNil(doc.bindings[3].group);
  XCTAssertNil(doc.bindings[3].modifiers);
  XCTAssertEqualObjects(doc.bindings[3].repeat, @NO);
  XCTAssertEqualObjects(doc.customCode, @"");
}

- (void)testReadsCustomCodeAfterMarker {
  NSString *custom = @"slate.bind('g:cmd', slate.op('grid'));\n\n// trailing\n";
  NSString *source = [NSString stringWithFormat:@"%@\n%@\n%@", kSample, SlateConfigDocumentCustomCodeMarker, custom];
  NSError *error = nil;
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:source error:&error];
  XCTAssertNotNil(doc, @"%@", error);
  XCTAssertEqualObjects(doc.customCode, custom, @"custom code is not evaluated and is kept exactly");
}

- (void)testHandWrittenFileIsNotManaged {
  NSError *error = nil;
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:@"slate.bind('a:cmd', slate.op('relaunch'));" error:&error];
  XCTAssertNil(doc);
  XCTAssertEqualObjects(error.domain, SlateConfigDocumentErrorDomain);
  XCTAssertEqual(error.code, SlateConfigDocumentErrorNotManaged);

  doc = [SlateConfigDocument documentFromString:@"var config = {};" error:&error];
  XCTAssertNil(doc);
  XCTAssertEqual(error.code, SlateConfigDocumentErrorNotManaged, @"no applyConfig call");
}

- (void)testSyntaxErrorReportsLine {
  NSError *error = nil;
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:@"var config = {\n  settings: {,\n};\nslate.applyConfig(config);" error:&error];
  XCTAssertNil(doc);
  XCTAssertEqual(error.code, SlateConfigDocumentErrorScript);
  XCTAssertEqualObjects(error.userInfo[SlateConfigDocumentErrorLineKey], @2);
}

- (void)testInvalidConfigIsReported {
  NSError *error = nil;
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:@"slate.applyConfig({ bindings: [{ key: 'a', action: '${x}' }] });" error:&error];
  XCTAssertNil(doc);
  XCTAssertEqual(error.code, SlateConfigDocumentErrorInvalid);
}

#pragma mark - Writing

- (void)testRoundTrip {
  NSString *source = [NSString stringWithFormat:@"%@\n%@\nslate.log('hi');\n", kSample, SlateConfigDocumentCustomCodeMarker];
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:source error:nil];
  NSString *written = [doc stringRepresentation];

  NSError *error = nil;
  SlateConfigDocument *reread = [SlateConfigDocument documentFromString:written error:&error];
  XCTAssertNotNil(reread, @"%@\n%@", error, written);
  XCTAssertEqualObjects(reread.settings, doc.settings);
  XCTAssertEqualObjects(reread.modifiers, doc.modifiers);
  XCTAssertEqualObjects(reread.monitors, doc.monitors);
  XCTAssertEqualObjects(reread.positions, doc.positions);
  XCTAssertEqualObjects(reread.aliases, doc.aliases);
  XCTAssertEqualObjects(reread.bindings, doc.bindings);
  XCTAssertEqualObjects(reread.customCode, @"slate.log('hi');\n");
  XCTAssertEqualObjects([reread stringRepresentation], written, @"writing is stable");
}

- (void)testWritesReadableFormat {
  SlateConfigDocument *doc = [[SlateConfigDocument alloc] init];
  [doc.settings addObject:[SlateConfigEntry entryWithName:@"defaultToCurrentScreen" value:@YES]];
  [doc.monitors addObject:[SlateConfigEntry entryWithName:@"monitor-macbook" value:@"1"]];
  SlateBindingEntry *binding = [SlateBindingEntry bindingWithKey:@"r" modifiers:@"${hyper}" action:@"relaunch"];
  binding.group = @"Features";
  [doc.bindings addObject:binding];

  NSString *written = [doc stringRepresentation];
  XCTAssertTrue([written rangeOfString:@"    defaultToCurrentScreen: true,\n"].location != NSNotFound, @"%@", written);
  XCTAssertTrue([written rangeOfString:@"    \"monitor-macbook\": \"1\",\n"].location != NSNotFound, @"%@", written);
  XCTAssertTrue([written rangeOfString:@"  modifiers: {},\n"].location != NSNotFound, @"%@", written);
  XCTAssertTrue([written rangeOfString:@"    { group: \"Features\", key: \"r\", mods: \"${hyper}\", action: \"relaunch\" },\n"].location != NSNotFound, @"%@", written);
  XCTAssertTrue([written hasSuffix:[SlateConfigDocumentCustomCodeMarker stringByAppendingString:@"\n"]], @"%@", written);
}

- (void)testWriteKeepsBackupAndFollowsSymlink {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  NSString *real = [dir stringByAppendingPathComponent:@"dotfiles-slate.js"];
  NSString *link = [dir stringByAppendingPathComponent:@".slate.js"];
  [@"// old\n" writeToFile:real atomically:YES encoding:NSUTF8StringEncoding error:nil];
  XCTAssertTrue([fm createSymbolicLinkAtPath:link withDestinationPath:real error:nil]);

  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:kSample error:nil];
  NSError *error = nil;
  XCTAssertTrue([doc writeToFile:link error:&error], @"%@", error);

  NSDictionary *attrs = [fm attributesOfItemAtPath:link error:nil];
  XCTAssertEqualObjects(attrs[NSFileType], NSFileTypeSymbolicLink, @"the symlink is not replaced");
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:real encoding:NSUTF8StringEncoding error:nil], [doc stringRepresentation]);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[real stringByAppendingString:@".bak"] encoding:NSUTF8StringEncoding error:nil], @"// old\n");

  SlateConfigDocument *reread = [SlateConfigDocument documentWithContentsOfFile:link error:&error];
  XCTAssertEqualObjects(reread.bindings, doc.bindings, @"%@", error);
  [fm removeItemAtPath:dir error:nil];
}

@end
