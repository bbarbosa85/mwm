//
//  TestMWMUpdateInstaller.m
//
//  Formulas: what is rejected in plain words, and what an accepted one works out to.
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
#import "MWMUpdateInstaller.h"

@interface TestMWMUpdateInstaller : XCTestCase
@property (copy) NSString *root;
@end

@implementation TestMWMUpdateInstaller

- (void)setUp {
  self.root = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"installer-test-%@", [[NSUUID UUID] UUIDString]]];
  [[NSFileManager defaultManager] createDirectoryAtPath:self.root withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeItemAtPath:self.root error:nil];
}

// A folder that looks like an app: Info.plist with an identifier and a version, and a marker file.
- (NSString *)appNamed:(NSString *)folder identifier:(NSString *)identifier version:(NSString *)version marker:(NSString *)marker {
  NSString *app = [[self.root stringByAppendingPathComponent:folder] stringByAppendingPathComponent:@"MWM.app"];
  NSString *contents = [app stringByAppendingPathComponent:@"Contents"];
  [[NSFileManager defaultManager] createDirectoryAtPath:contents withIntermediateDirectories:YES attributes:nil error:nil];
  [@{@"CFBundleIdentifier": identifier, @"CFBundleShortVersionString": version} writeToFile:[contents stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
  [marker writeToFile:[app stringByAppendingPathComponent:@"marker.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  return app;
}

// A release folder with MWM-<version>.zip and SHA256SUMS.txt, as the site serves them.
- (NSURL *)releaseWithApp:(NSString *)app version:(NSString *)version checksum:(NSString *)forcedChecksum {
  NSString *release = [self.root stringByAppendingPathComponent:@"release"];
  [[NSFileManager defaultManager] createDirectoryAtPath:release withIntermediateDirectories:YES attributes:nil error:nil];
  NSString *zip = [release stringByAppendingPathComponent:[NSString stringWithFormat:@"MWM-%@.zip", version]];
  NSTask *ditto = [[NSTask alloc] init];
  [ditto setLaunchPath:@"/usr/bin/ditto"];
  [ditto setArguments:@[@"-c", @"-k", @"--keepParent", app, zip]];
  [ditto launch];
  [ditto waitUntilExit];
  NSString *sum = forcedChecksum ?: [MWMUpdateInstaller sha256OfFileAtPath:zip];
  [[NSString stringWithFormat:@"%@  MWM-%@.zip\n", sum, version] writeToFile:[release stringByAppendingPathComponent:@"SHA256SUMS.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  return [NSURL fileURLWithPath:release isDirectory:YES];
}

- (NSError *)prepare:(MWMUpdateInstaller *)installer {
  XCTestExpectation *done = [self expectationWithDescription:@"prepared"];
  __block NSError *result = nil;
  [installer prepareWithProgress:nil completion:^(NSError *error) { result = error; [done fulfill]; }];
  [self waitForExpectations:@[done] timeout:20];
  return result;
}

- (void)testTheChecksumIsReadFromTheSumsFile {
  NSString *sums = @"AABB  MWM-1.2.dmg\nccdd11  MWM-1.2.zip\n";
  XCTAssertEqualObjects([MWMUpdateInstaller checksumForFileNamed:@"MWM-1.2.zip" inSums:sums], @"ccdd11");
  XCTAssertEqualObjects([MWMUpdateInstaller checksumForFileNamed:@"MWM-1.2.dmg" inSums:sums], @"aabb");
  XCTAssertNil([MWMUpdateInstaller checksumForFileNamed:@"MWM-1.3.zip" inSums:sums]);
}

- (void)testTheSha256IsTheFilesOwn {
  NSString *file = [self.root stringByAppendingPathComponent:@"abc.txt"];
  [@"abc" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
  XCTAssertEqualObjects([MWMUpdateInstaller sha256OfFileAtPath:file], @"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  XCTAssertNil([MWMUpdateInstaller sha256OfFileAtPath:[self.root stringByAppendingPathComponent:@"missing"]]);
}

- (void)testTheZipIsNamedAfterTheVersion {
  NSURL *base = [NSURL URLWithString:@"https://example.com/downloads/"];
  XCTAssertEqualObjects([MWMUpdateInstaller zipURLForVersion:@"1.2" baseURL:base].absoluteString, @"https://example.com/downloads/MWM-1.2.zip");
}

- (void)testAnAppInAFolderYouOwnCanBeReplacedAndOneInTheSystemCanNot {
  NSString *mine = [self appNamed:@"mine" identifier:@"x" version:@"1" marker:@"a"];
  XCTAssertTrue([MWMUpdateInstaller canReplaceAppAtPath:mine]);
  XCTAssertFalse([MWMUpdateInstaller canReplaceAppAtPath:@"/System/Applications/Calculator.app"]);
}

- (void)testAGoodUpdateIsDownloadedCheckedAndUnpacked {
  NSString *current = [self appNamed:@"installed" identifier:@"com.test.mwm" version:@"1.0" marker:@"old"];
  NSString *update = [self appNamed:@"update" identifier:@"com.test.mwm" version:@"9.9" marker:@"new"];
  MWMUpdateInstaller *installer = [[MWMUpdateInstaller alloc] initWithVersion:@"9.9"];
  installer.baseURL = [self releaseWithApp:update version:@"9.9" checksum:nil];
  installer.appPath = current;
  installer.requiresSignature = NO;
  XCTAssertNil([self prepare:installer]);
  XCTAssertNotNil(installer.stagedAppPath);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[installer.stagedAppPath stringByAppendingPathComponent:@"marker.txt"] encoding:NSUTF8StringEncoding error:nil], @"new");
  [installer discard];
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:installer.stagedAppPath ?: @"/nonexistent"]);
}

- (void)testADownloadThatDoesNotMatchItsChecksumIsRefused {
  NSString *current = [self appNamed:@"installed" identifier:@"com.test.mwm" version:@"1.0" marker:@"old"];
  NSString *update = [self appNamed:@"update" identifier:@"com.test.mwm" version:@"9.9" marker:@"new"];
  MWMUpdateInstaller *installer = [[MWMUpdateInstaller alloc] initWithVersion:@"9.9"];
  installer.baseURL = [self releaseWithApp:update version:@"9.9" checksum:@"0000000000000000000000000000000000000000000000000000000000000000"];
  installer.appPath = current;
  installer.requiresSignature = NO;
  NSError *error = [self prepare:installer];
  XCTAssertTrue([error.localizedDescription containsString:@"checksum"], @"%@", error);
  XCTAssertNil(installer.stagedAppPath);
}

- (void)testAnAppThatIsNotMWMOrNotTheVersionAskedForIsRefused {
  NSString *current = [self appNamed:@"installed" identifier:@"com.test.mwm" version:@"1.0" marker:@"old"];
  NSString *other = [self appNamed:@"other" identifier:@"com.someone.else" version:@"9.9" marker:@"new"];
  MWMUpdateInstaller *installer = [[MWMUpdateInstaller alloc] initWithVersion:@"9.9"];
  installer.baseURL = [self releaseWithApp:other version:@"9.9" checksum:nil];
  installer.appPath = current;
  installer.requiresSignature = NO;
  XCTAssertTrue([[self prepare:installer].localizedDescription containsString:@"isn't MWM"]);
  [[NSFileManager defaultManager] removeItemAtPath:[self.root stringByAppendingPathComponent:@"release"] error:nil];
  NSString *wrongVersion = [self appNamed:@"wrong" identifier:@"com.test.mwm" version:@"9.8" marker:@"new"];
  MWMUpdateInstaller *second = [[MWMUpdateInstaller alloc] initWithVersion:@"9.9"];
  second.baseURL = [self releaseWithApp:wrongVersion version:@"9.9" checksum:nil];
  second.appPath = current;
  second.requiresSignature = NO;
  XCTAssertTrue([[self prepare:second].localizedDescription containsString:@"version 9.8"]);
}

- (void)testAnUnsignedAppIsRefusedWhenASignatureIsRequired {
  NSString *current = [self appNamed:@"installed" identifier:@"com.test.mwm" version:@"1.0" marker:@"old"];
  NSString *update = [self appNamed:@"update" identifier:@"com.test.mwm" version:@"9.9" marker:@"new"];
  MWMUpdateInstaller *installer = [[MWMUpdateInstaller alloc] initWithVersion:@"9.9"];
  installer.baseURL = [self releaseWithApp:update version:@"9.9" checksum:nil];
  installer.appPath = current;
  XCTAssertTrue([[self prepare:installer].localizedDescription containsString:@"signature"]);
}

- (void)testAMissingDownloadSaysSo {
  MWMUpdateInstaller *installer = [[MWMUpdateInstaller alloc] initWithVersion:@"9.9"];
  installer.baseURL = [NSURL fileURLWithPath:[self.root stringByAppendingPathComponent:@"nothing"] isDirectory:YES];
  installer.requiresSignature = NO;
  XCTAssertNotNil([self prepare:installer]);
}

#pragma mark - The swap

- (NSString *)runInstallScriptWithApp:(NSString *)app new:(NSString *)new work:(NSString *)work {
  NSString *script = [self.root stringByAppendingPathComponent:@"install.sh"];
  [[MWMUpdateInstaller installScript] writeToFile:script atomically:YES encoding:NSUTF8StringEncoding error:nil];
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:@"/bin/sh"];
  [task setArguments:@[script, @"99999999", app, new, work]];   // no such process, so it doesn't wait
  [task setEnvironment:@{@"OPEN_COMMAND": @"true", @"PATH": @"/usr/bin:/bin"}];
  NSPipe *pipe = [NSPipe pipe];
  [task setStandardOutput:pipe];
  [task launch];
  [task waitUntilExit];
  return [[NSString alloc] initWithData:[[pipe fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
}

- (void)testTheScriptPutsTheNewAppWhereTheOldOneWasAndRemovesTheOld {
  NSString *old = [self appNamed:@"installed" identifier:@"x" version:@"1" marker:@"old"];
  NSString *new = [self appNamed:@"staged" identifier:@"x" version:@"2" marker:@"new"];
  NSString *work = [self.root stringByAppendingPathComponent:@"work"];
  [[NSFileManager defaultManager] createDirectoryAtPath:work withIntermediateDirectories:YES attributes:nil error:nil];
  NSString *out = [self runInstallScriptWithApp:old new:new work:work];
  XCTAssertTrue([out containsString:@"installed"], @"%@", out);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[old stringByAppendingPathComponent:@"marker.txt"] encoding:NSUTF8StringEncoding error:nil], @"new");
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[work stringByAppendingPathComponent:@"previous.app"]]);
}

- (void)testTheScriptPutsTheOldAppBackWhenTheNewOneCanNotBeMoved {
  NSString *old = [self appNamed:@"installed" identifier:@"x" version:@"1" marker:@"old"];
  NSString *work = [self.root stringByAppendingPathComponent:@"work"];
  [[NSFileManager defaultManager] createDirectoryAtPath:work withIntermediateDirectories:YES attributes:nil error:nil];
  NSString *out = [self runInstallScriptWithApp:old new:[self.root stringByAppendingPathComponent:@"missing.app"] work:work];
  XCTAssertTrue([out containsString:@"restored"], @"%@", out);
  XCTAssertEqualObjects([NSString stringWithContentsOfFile:[old stringByAppendingPathComponent:@"marker.txt"] encoding:NSUTF8StringEncoding error:nil], @"old", @"the app that was there is still there");
}

@end
