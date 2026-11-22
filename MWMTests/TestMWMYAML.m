//
//  TestMWMYAML.m
//  Slate
//
//  Tests for the strict YAML subset ~/.mwm.yml is read with.
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
#import "MWMYAML.h"

@interface TestMWMYAML : XCTestCase
@end

@implementation TestMWMYAML

- (id)parse:(NSString *)text {
  NSError *error = nil;
  id result = [MWMYAML parse:text error:&error];
  XCTAssertNotNil(result, @"%@", error);
  return result;
}

- (void)assertFails:(NSString *)text line:(NSUInteger)line mentioning:(NSString *)fragment {
  NSError *error = nil;
  XCTAssertNil([MWMYAML parse:text error:&error], @"should fail: %@", text);
  XCTAssertEqualObjects(error.userInfo[MWMYAMLErrorLineKey], @(line), @"%@", error);
  XCTAssertTrue([[error localizedDescription] containsString:fragment], @"'%@' should mention '%@'", [error localizedDescription], fragment);
}

- (void)testMappingsKeepOrderAndLines {
  MWMYAMLMapping *root = [self parse:@"# header\nb: 1\n\na:\n  z: x\n  y: \"y\"\n"];
  XCTAssertEqualObjects(root.keys, (@[@"b", @"a"]));
  XCTAssertEqual([root lineForKey:@"a"], 4u);
  MWMYAMLMapping *a = [root objectForKey:@"a"];
  XCTAssertEqualObjects(a.keys, (@[@"z", @"y"]));
  XCTAssertEqual(a.line, 5u);
}

- (void)testScalarTypes {
  MWMYAMLMapping *root = [self parse:
    @"t: true\nf: False\nn: ~\nnull2: null\ni: -12\nd: 0.4\ne: 1e3\ns: hello world\nq: \"42\"\nsq: 'it''s'\nver: 1.2.3\nempty:\n"];
  XCTAssertEqualObjects([root objectForKey:@"t"], @YES);
  XCTAssertTrue(CFGetTypeID((__bridge CFTypeRef)[root objectForKey:@"t"]) == CFBooleanGetTypeID());
  XCTAssertEqualObjects([root objectForKey:@"f"], @NO);
  XCTAssertEqualObjects([root objectForKey:@"n"], [NSNull null]);
  XCTAssertEqualObjects([root objectForKey:@"null2"], [NSNull null]);
  XCTAssertEqualObjects([root objectForKey:@"i"], @(-12));
  XCTAssertEqualObjects([root objectForKey:@"d"], @0.4);
  XCTAssertEqualObjects([root objectForKey:@"e"], @1000.0);
  XCTAssertEqualObjects([root objectForKey:@"s"], @"hello world");
  XCTAssertEqualObjects([root objectForKey:@"q"], @"42");
  XCTAssertEqualObjects([root objectForKey:@"sq"], @"it's");
  XCTAssertEqualObjects([root objectForKey:@"ver"], @"1.2.3");
  XCTAssertEqualObjects([root objectForKey:@"empty"], [NSNull null]);
}

- (void)testSequences {
  MWMYAMLMapping *root = [self parse:
    @"list:\n  - a\n  - b: 1\n    c: 2\n  -\n    d: 3\nsame-indent:\n- x\n- y\nempty: []\nnone: {}\n"];
  NSArray *list = [root objectForKey:@"list"];
  XCTAssertEqual([list count], 3u);
  XCTAssertEqualObjects(list[0], @"a");
  XCTAssertEqualObjects([list[1] keys], (@[@"b", @"c"]));
  XCTAssertEqual([(MWMYAMLMapping *)list[1] line], 3u);
  XCTAssertEqualObjects([list[2] objectForKey:@"d"], @3);
  XCTAssertEqualObjects([root objectForKey:@"same-indent"], (@[@"x", @"y"]));
  XCTAssertEqualObjects([root objectForKey:@"empty"], @[]);
  XCTAssertEqualObjects([[root objectForKey:@"none"] keys], @[]);
}

- (void)testCommentsAndQuotes {
  MWMYAMLMapping *root = [self parse:
    @"a: value # comment\nb: \"has # inside\"  # trailing\nc: 'single # too'\nd: no#comment\ne: \"esc \\\" \\\\ \\n \\u00e9\"\n\"quoted key\": 1\n"];
  XCTAssertEqualObjects([root objectForKey:@"a"], @"value");
  XCTAssertEqualObjects([root objectForKey:@"b"], @"has # inside");
  XCTAssertEqualObjects([root objectForKey:@"c"], @"single # too");
  XCTAssertEqualObjects([root objectForKey:@"d"], @"no#comment");
  XCTAssertEqualObjects([root objectForKey:@"e"], @"esc \" \\ \n \u00e9");
  XCTAssertEqualObjects([root objectForKey:@"quoted key"], @1);
}

- (void)testEmptyDocument {
  XCTAssertEqualObjects([self parse:@""], [NSNull null]);
  XCTAssertEqualObjects([self parse:@"# only a comment\n\n"], [NSNull null]);
  XCTAssertEqualObjects([[self parse:@"---\na: 1\n"] keys], @[@"a"]);
}

- (void)testReadsOneLineListsAndMappings {
  id root = [self parse:@"a: [ctrl, alt, \"x, y\"]\nb: {x: 0%, y: 50%, name: two words}\nc: {list: [1, true], inner: {k: v}}\nd: []\ne: {}\n"];
  XCTAssertEqualObjects([root objectForKey:@"a"], (@[@"ctrl", @"alt", @"x, y"]));
  MWMYAMLMapping *b = [root objectForKey:@"b"];
  XCTAssertEqualObjects(b.keys, (@[@"x", @"y", @"name"]));
  XCTAssertEqualObjects([b objectForKey:@"x"], @"0%");
  XCTAssertEqualObjects([b objectForKey:@"name"], @"two words");
  MWMYAMLMapping *c = [root objectForKey:@"c"];
  XCTAssertEqualObjects([c objectForKey:@"list"], (@[@1, @YES]));
  XCTAssertEqualObjects([[c objectForKey:@"inner"] objectForKey:@"k"], @"v");
  XCTAssertEqualObjects([root objectForKey:@"d"], @[]);
}

- (void)testPlainTextIsKeptOnlyWhenItReadsBackTheSame {
  for (NSString *text in @[@"ctrl", @"50%", @"5120x1440", @"two words", @"+10%", @"Samsung Odyssey 5120x1440"]) {
    XCTAssertEqualObjects([MWMYAML text:text], text);
  }
  for (NSString *text in @[@"true", @"12", @"a: b", @"x, y", @"[a]", @"yes", @" lead", @"trail ", @"", @"#c"]) {
    NSString *written = [MWMYAML text:text];
    XCTAssertTrue([written hasPrefix:@"\""], @"%@ should be quoted", text);
  }
}

- (void)testRejectsWhatItDoesNotSupport {
  [self assertFails:@"a:\n\tb: 1\n" line:2 mentioning:@"tabs"];
  [self assertFails:@"a: &x 1\n" line:1 mentioning:@"Anchors"];
  [self assertFails:@"a: !!str 1\n" line:1 mentioning:@"Tags"];
  [self assertFails:@"a: |\n  text\n" line:1 mentioning:@"Multi-line"];
  [self assertFails:@"a: [1, 2\n" line:1 mentioning:@"closing"];
  [self assertFails:@"a: {b: 1\n" line:1 mentioning:@"closing"];
  [self assertFails:@"a: [\"x\" \"y\"]\n" line:1 mentioning:@"commas"];
  [self assertFails:@"a: {b 1}\n" line:1 mentioning:@"Expected"];
  [self assertFails:@"a: {b: 1, b: 2}\n" line:1 mentioning:@"twice"];
  [self assertFails:@"a: [1] x\n" line:1 mentioning:@"Unexpected text"];
  [self assertFails:@"a: 1\na: 2\n" line:2 mentioning:@"appears twice"];
  [self assertFails:@"a: one\n  continued\n" line:2 mentioning:@"Multi-line values"];
  [self assertFails:@"a:\n  b: 1\n c: 2\n" line:3 mentioning:@"indentation"];
  [self assertFails:@"a: \"open\n" line:1 mentioning:@"closing quote"];
  [self assertFails:@"a: \"x\" y\n" line:1 mentioning:@"after the quoted value"];
  [self assertFails:@"a: b: c\n" line:1 mentioning:@"\": \""];
  [self assertFails:@"a: 1\n---\nb: 2\n" line:2 mentioning:@"one YAML document"];
  [self assertFails:@"a: \"bad \\q\"\n" line:1 mentioning:@"Unknown escape"];
}

- (void)testWriterOutputReadsBack {
  NSArray *strings = @[@"plain", @"", @"with \"quotes\" and \\ slash", @"# hash", @"a: b", @"true", @"12", @"tab\there", @"line\nbreak",
                       @"${hyper}", @"focus 'App'", @"ünïcödé", @"\x01"];
  NSMutableString *yaml = [NSMutableString string];
  for (NSUInteger i = 0; i < [strings count]; i++) {
    [yaml appendFormat:@"%@: %@\n", [MWMYAML key:strings[i]], [MWMYAML scalar:strings[i]]];
  }
  MWMYAMLMapping *root = [self parse:yaml];
  XCTAssertEqualObjects(root.keys, strings, @"%@", yaml);
  for (NSString *s in strings) XCTAssertEqualObjects([root objectForKey:s], s, @"%@", yaml);
}

- (void)testKeysAreQuotedOnlyWhenNeeded {
  XCTAssertEqualObjects([MWMYAML key:@"monitor-samsung"], @"monitor-samsung");
  XCTAssertEqualObjects([MWMYAML key:@"windowHintsShowIcons"], @"windowHintsShowIcons");
  XCTAssertEqualObjects([MWMYAML key:@"yes"], @"\"yes\"");
  XCTAssertEqualObjects([MWMYAML key:@"1"], @"\"1\"");
  XCTAssertEqualObjects([MWMYAML key:@"two words"], @"\"two words\"");
  XCTAssertEqualObjects([MWMYAML scalar:@YES], @"true");
  XCTAssertEqualObjects([MWMYAML scalar:@0.4], @"0.4");
}

@end
