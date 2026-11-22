//
//  TestAppIcon.m
//
//  The app icon alerts and the About panel show must be MWM's, not the old Slate one.
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

static CGFloat LargestWidth(NSImage *image) {
  CGFloat widest = 0;
  for (NSImageRep *rep in [image representations]) widest = MAX(widest, (CGFloat)[rep pixelsWide]);
  return widest;
}

@interface TestAppIcon : XCTestCase
@end

@implementation TestAppIcon

// The old Slate icon stopped at 512 points; MWM's goes to 1024.
- (void)testTheBundleHoldsTheNewIcon {
  NSImage *icon = [[NSBundle mainBundle] imageForResource:@"icon"];
  XCTAssertNotNil(icon);
  XCTAssertGreaterThanOrEqual(LargestWidth(icon), 1024);
}

// Launching puts the bundle's icon in place of whatever macOS remembered (a blank one stands in here).
- (void)testLaunchSetsTheApplicationIconFromTheBundle {
  NSImage *stand_in = [[NSImage alloc] initWithSize:NSMakeSize(64, 64)];
  [NSApp setApplicationIconImage:stand_in];
  NSData *before = [[NSApp applicationIconImage] TIFFRepresentation];
  id delegate = [NSApp delegate];
  XCTAssertTrue([delegate respondsToSelector:NSSelectorFromString(@"useBundleIcon")]);
  [delegate performSelector:NSSelectorFromString(@"useBundleIcon")];
  NSImage *now = [NSApp applicationIconImage];
  XCTAssertNotEqualObjects([now TIFFRepresentation], before);
  XCTAssertGreaterThanOrEqual(LargestWidth(now), 256);
}

@end
