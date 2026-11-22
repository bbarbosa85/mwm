//
//  TestUpdateChecker.m
//
//  The update check: comparing versions, reading GitHub's answer, and when it speaks up.
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
#import "MWMUpdateChecker.h"
#import "MWMConfig.h"
#import "Constants.h"

@interface TestUpdateChecker : XCTestCase
@property (strong) MWMUpdateChecker *checker;
@property (strong) NSMutableArray *shown;
@property (strong) NSUserDefaults *defaults;
@property (copy) NSString *suite;
@end

@implementation TestUpdateChecker

- (void)setUp {
  self.suite = [NSString stringWithFormat:@"mwm.tests.%@", [[NSUUID UUID] UUIDString]];
  self.defaults = [[NSUserDefaults alloc] initWithSuiteName:self.suite];
  self.checker = [[MWMUpdateChecker alloc] init];
  self.checker.defaults = self.defaults;
  self.checker.currentVersion = @"1.0";
  self.shown = [NSMutableArray array];
  __weak TestUpdateChecker *weakSelf = self;
  self.checker.presenter = ^(NSDictionary *result) { [weakSelf.shown addObject:result]; };
}

- (void)tearDown {
  [self.defaults removePersistentDomainForName:self.suite];
}

- (NSURL *)releaseFile:(NSString *)json {
  NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"release-%@.json", [[NSUUID UUID] UUIDString]]];
  [json writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
  return [NSURL fileURLWithPath:path];
}

- (NSDictionary *)checkNowAgainst:(NSURL *)url {
  self.checker.releasesURL = url;
  [self.checker checkNow];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
  while ([self.shown count] == 0 && [deadline timeIntervalSinceNow] > 0) [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
  return [self.shown firstObject];
}

#pragma mark - Versions

- (void)testNewerVersionsAreRecognized {
  XCTAssertTrue([MWMUpdateChecker version:@"1.1" isNewerThan:@"1.0"]);
  XCTAssertTrue([MWMUpdateChecker version:@"1.0.1" isNewerThan:@"1.0"]);
  XCTAssertTrue([MWMUpdateChecker version:@"2" isNewerThan:@"1.9.9"]);
  XCTAssertTrue([MWMUpdateChecker version:@"1.10" isNewerThan:@"1.9"], @"numbers, not text");
  XCTAssertTrue([MWMUpdateChecker version:@"v1.2" isNewerThan:@"1.1"], @"a leading v is ignored");
}

- (void)testSameOrOlderVersionsAreNotNewer {
  XCTAssertFalse([MWMUpdateChecker version:@"1.0" isNewerThan:@"1.0"]);
  XCTAssertFalse([MWMUpdateChecker version:@"1.0.0" isNewerThan:@"1.0"]);
  XCTAssertFalse([MWMUpdateChecker version:@"0.9" isNewerThan:@"1.0"]);
  XCTAssertFalse([MWMUpdateChecker version:@"nightly" isNewerThan:@"1.0"]);
  XCTAssertFalse([MWMUpdateChecker version:@"1.1" isNewerThan:@"unknown"]);
}

#pragma mark - GitHub's answer

- (void)testReadsTheLatestRelease {
  NSData *json = [@"{\"tag_name\": \"v1.2\", \"html_url\": \"https://github.com/o/r/releases/tag/v1.2\", \"name\": \"MWM 1.2\"}" dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *latest = [MWMUpdateChecker latestFromReleaseJSON:json];
  XCTAssertEqualObjects(latest[@"version"], @"1.2");
  XCTAssertEqualObjects(latest[@"notesURL"], @"https://github.com/o/r/releases/tag/v1.2");
}

- (void)testRefusesAnswersThatAreNotReleases {
  XCTAssertNil([MWMUpdateChecker latestFromReleaseJSON:[@"{\"message\": \"Not Found\"}" dataUsingEncoding:NSUTF8StringEncoding]]);
  XCTAssertNil([MWMUpdateChecker latestFromReleaseJSON:[@"not json" dataUsingEncoding:NSUTF8StringEncoding]]);
  XCTAssertNil([MWMUpdateChecker latestFromReleaseJSON:[@"{\"tag_name\": \"nightly\"}" dataUsingEncoding:NSUTF8StringEncoding]]);
}

#pragma mark - Checking

- (void)testCheckNowReportsANewerVersion {
  NSDictionary *result = [self checkNowAgainst:[self releaseFile:@"{\"tag_name\": \"v1.5\", \"html_url\": \"https://example.com/notes\"}"]];
  XCTAssertEqualObjects(result[@"kind"], MWMUpdateKindNewer);
  XCTAssertEqualObjects(result[@"version"], @"1.5");
  XCTAssertEqualObjects(result[@"notesURL"], @"https://example.com/notes");
}

- (void)testCheckNowSaysWhenUpToDate {
  NSDictionary *result = [self checkNowAgainst:[self releaseFile:@"{\"tag_name\": \"v1.0\", \"html_url\": \"https://example.com/notes\"}"]];
  XCTAssertEqualObjects(result[@"kind"], MWMUpdateKindCurrent);
}

- (void)testCheckNowSaysWhenItFailed {
  NSDictionary *result = [self checkNowAgainst:[NSURL fileURLWithPath:@"/nonexistent/release.json"]];
  XCTAssertEqualObjects(result[@"kind"], MWMUpdateKindError);
  XCTAssertTrue([result[@"message"] length] > 0);
}

#pragma mark - Automatic checks

- (void)testAnAutomaticCheckFollowsTheSetting {
  XCTAssertTrue([self.checker automaticCheckIsEnabled], @"on by default");
}

- (void)testCheckingForUpdatesIsOnByDefault {
  XCTAssertEqualObjects([[MWMConfig getInstance] getConfigDefault:CHECK_FOR_UPDATES], @"true");
}

- (void)testAnAutomaticCheckOnlyAnnouncesNewVersionsAndOnlyOnce {
  [self.checker handleResult:@{@"kind": MWMUpdateKindCurrent, @"version": @"1.0"} manual:NO];
  [self.checker handleResult:@{@"kind": MWMUpdateKindError, @"message": @"offline"} manual:NO];
  XCTAssertEqual([self.shown count], 0u, @"nothing to say, so it stays quiet");
  NSDictionary *newer = @{@"kind": MWMUpdateKindNewer, @"version": @"1.5", @"notesURL": @""};
  [self.checker handleResult:newer manual:NO];
  XCTAssertEqual([self.shown count], 1u);
  [self.checker handleResult:newer manual:NO];
  XCTAssertEqual([self.shown count], 1u, @"the same version isn't announced twice");
  [self.checker handleResult:@{@"kind": MWMUpdateKindNewer, @"version": @"1.6", @"notesURL": @""} manual:NO];
  XCTAssertEqual([self.shown count], 2u, @"a still newer one is");
}

- (void)testAManualCheckAlwaysSpeaksUp {
  [self.checker handleResult:@{@"kind": MWMUpdateKindCurrent, @"version": @"1.0"} manual:YES];
  [self.checker handleResult:@{@"kind": MWMUpdateKindError, @"message": @"offline"} manual:YES];
  NSDictionary *newer = @{@"kind": MWMUpdateKindNewer, @"version": @"1.5", @"notesURL": @""};
  [self.checker handleResult:newer manual:YES];
  [self.checker handleResult:newer manual:YES];
  XCTAssertEqual([self.shown count], 4u);
}

@end
