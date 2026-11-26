//
//  TestMWMGist.m
//
//  The gist API behind the backup: finding the private gist, reading and changing its files, and saying
//  problems in plain words (against a small fake of GitHub).
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

#import <XCTest/XCTest.h>
#import "MWMGist.h"
#import "TestFakeGitHub.h"

@interface TestMWMGist : XCTestCase
@property (strong) TestFakeGitHub *github;
@end

@implementation TestMWMGist

- (void)setUp {
  [MWMGist useMemoryStorage:YES];
  self.github = [[TestFakeGitHub alloc] init];
  [self.github install];
  [MWMGist setToken:@"ghp_test"];
}

- (void)tearDown {
  [MWMGist setTransport:nil];
  [MWMGist useMemoryStorage:NO];
}

- (void)wait:(void (^)(XCTestExpectation *))body {
  XCTestExpectation *expectation = [self expectationWithDescription:@"gist"];
  body(expectation);
  [self waitForExpectations:@[expectation] timeout:30];
}

- (NSDictionary *)fetched:(BOOL *)exists {
  __block NSDictionary *result;
  [self wait:^(XCTestExpectation *e) {
    [MWMGist fetchFiles:^(NSDictionary *files, BOOL gistExists, NSString *problem) { XCTAssertNil(problem); result = files; if (exists) *exists = gistExists; [e fulfill]; }];
  }];
  return result;
}

- (void)update:(NSDictionary *)files {
  [self wait:^(XCTestExpectation *e) { [MWMGist updateFiles:files completion:^(NSString *problem) { XCTAssertNil(problem); [e fulfill]; }]; }];
}

- (void)testThereIsNothingBeforeTheFirstUpdate {
  BOOL exists = YES;
  XCTAssertEqual([[self fetched:&exists] count], 0u);
  XCTAssertFalse(exists);
  XCTAssertEqual(self.github.gists.count, 0u);
}

- (void)testTheFirstUpdateMakesAPrivateGist {
  [self update:@{@"desk.mwm.yaml": @"v1\n"}];
  XCTAssertEqual(self.github.gists.count, 1u);
  NSDictionary *gist = [self.github.gists allValues][0];
  XCTAssertEqualObjects(gist[@"public"], @NO);
  XCTAssertEqualObjects(gist[@"description"], @"MWM backup");
  BOOL exists = NO;
  XCTAssertEqualObjects([self fetched:&exists], @{@"desk.mwm.yaml": @"v1\n"});
  XCTAssertTrue(exists);
}

- (void)testUpdatesAddReplaceAndRemoveInOneRequest {
  [self update:@{@"a.mwm.yaml": @"1", @"b.mwm.yaml": @"2"}];
  [self update:@{@"a.mwm.yaml": @"changed", @"b.mwm.yaml": [NSNull null], @"c.mwm.yaml": @"3"}];
  XCTAssertEqualObjects([self fetched:nil], (@{@"a.mwm.yaml": @"changed", @"c.mwm.yaml": @"3"}));
  XCTAssertEqual(self.github.gists.count, 1u, @"one gist holds everything");
}

- (void)testRemovingFromANonexistentGistMakesNothing {
  [self update:@{@"a.mwm.yaml": [NSNull null]}];
  XCTAssertEqual(self.github.gists.count, 0u);
}

- (void)testAForgottenGistIsFoundAgainByItsDescription {
  [self update:@{@"a.mwm.yaml": @"1"}];
  [MWMGist useMemoryStorage:YES];   // forgets the remembered gist (and the token)
  [MWMGist setToken:@"ghp_test"];
  XCTAssertEqualObjects([self fetched:nil], @{@"a.mwm.yaml": @"1"});
  [self update:@{@"b.mwm.yaml": @"2"}];
  XCTAssertEqual(self.github.gists.count, 1u, @"no second gist");
}

- (void)testAPublicGistWithTheSameNameIsNeverUsed {
  [self.github addPublicGistNamed:@"MWM backup"];
  BOOL exists = YES;
  XCTAssertEqual([[self fetched:&exists] count], 0u);
  XCTAssertFalse(exists);
  [self update:@{@"a.mwm.yaml": @"1"}];
  XCTAssertEqual(self.github.gists.count, 2u);
}

- (void)testProblemsAreSaidInPlainWords {
  self.github.status = 401;
  [self wait:^(XCTestExpectation *e) {
    [MWMGist checkToken:@"bad" completion:^(NSString *problem) { XCTAssertTrue([problem containsString:@"didn't accept the token"]); [e fulfill]; }];
  }];
  self.github.status = 500;
  [self wait:^(XCTestExpectation *e) {
    [MWMGist fetchFiles:^(NSDictionary *files, BOOL exists, NSString *problem) { XCTAssertTrue([problem containsString:@"500"]); [e fulfill]; }];
  }];
  [MWMGist setToken:nil];
  [self wait:^(XCTestExpectation *e) {
    [MWMGist fetchFiles:^(NSDictionary *files, BOOL exists, NSString *problem) { XCTAssertEqualObjects(problem, @"Add a GitHub token first."); [e fulfill]; }];
  }];
}

- (void)testTheTokenIsSentAndNothingElseIdentifiesThePerson {
  [self update:@{@"a.mwm.yaml": @"1"}];
  for (NSURLRequest *request in self.github.requests) {
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Authorization"], @"Bearer ghp_test");
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"User-Agent"], @"MWM");
  }
}

@end
