//
//  TestMWMPushOptions.m
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
#import "MWMPushOptions.h"
#import "PushOperation.h"
#import "MoveOperation.h"
#import "ExpressionPoint.h"

@interface TestMWMPushOptions : XCTestCase
@end

@implementation TestMWMPushOptions

- (void)testTextItWritesComesBackAsTheSameOptions {
  for (NSArray *pair in @[@[@"left", @""], @[@"left", @"none"], @[@"up", @"center"], @[@"up", @"bar"],
                          @[@"left", @"bar-resize:screenSizeX/3"], @[@"up", @"bar-resize:screenSizeY*25/100"],
                          @[@"right", @"bar-resize:320"], @[@"down", @"bar-resize:screenSizeY*33.5/100"],
                          @[@"left", @"bar ${second}"], @[@"left", @"none ${second}"], @[@"left", @"bar-resize:screenSizeX/4 ${second}"]]) {
    MWMPushOptions *options = [MWMPushOptions optionsFromText:pair[1] direction:pair[0]];
    XCTAssertNotNil(options, @"%@ %@", pair[0], pair[1]);
    XCTAssertEqualObjects([options textForDirection:pair[0]], pair[1]);
  }
}

- (void)testTextItCouldNotHaveWrittenStaysText {
  for (NSArray *pair in @[@[@"left", @"bar-resize:screenSizeX / 3"], @[@"up", @"bar-resize:screenSizeX/3"],  // the wrong side for the direction
                          @[@"left", @"bar-resize:screenSizeX*50.0/100"], @[@"left", @"bar-resize:(screenSizeX/3)+20"],
                          @[@"left", @"wobble"], @[@"left", @"bar ${a} extra"]]) {
    XCTAssertNil([MWMPushOptions optionsFromText:pair[1] direction:pair[0]], @"%@ %@", pair[0], pair[1]);
  }
}

- (void)testTheSameThicknessFollowsTheDirectionToTheOtherSide {
  MWMPushOptions *options = [MWMPushOptions optionsFromText:@"bar-resize:screenSizeX/3" direction:@"left"];
  XCTAssertEqualObjects([options textForDirection:@"up"], @"bar-resize:screenSizeY/3");
  XCTAssertEqualObjects([options textForDirection:@"right"], @"bar-resize:screenSizeX/3");
}

- (void)testMistakesInTheThicknessAreNamed {
  MWMPushOptions *options = [MWMPushOptions defaultOptions];
  XCTAssertNil([options problem]);
  options.thickness = 0;
  XCTAssertTrue([[options problem] containsString:@"more than zero"]);
  options.unit = MWMPushUnitPercent; options.thickness = 120;
  XCTAssertTrue([[options problem] containsString:@"100"]);
  options.unit = MWMPushUnitParts; options.thickness = 0.5;
  XCTAssertTrue([[options problem] containsString:@"1 or more"]);
  options.style = MWMPushStyleBar;
  XCTAssertNil([options problem], @"only a set thickness has one");
}

- (void)testThePreviewShowsWhereTheWindowGoes {
  MWMPushOptions *third = [MWMPushOptions optionsFromText:@"bar-resize:screenSizeX/4" direction:@"right"];
  CGRect rect = [third previewRectForDirection:@"right"];
  XCTAssertEqualWithAccuracy(rect.origin.x, 0.75, 0.001);
  XCTAssertEqualWithAccuracy(rect.size.width, 0.25, 0.001);
  XCTAssertEqualWithAccuracy(rect.size.height, 1, 0.001);
  MWMPushOptions *pixels = [MWMPushOptions optionsFromText:@"bar-resize:160" direction:@"up"];
  rect = [pixels previewRectForDirection:@"up"];
  XCTAssertEqualWithAccuracy(rect.size.height, 0.16, 0.001, @"160 of the sample screen's 1000 px");
  MWMPushOptions *center = [MWMPushOptions optionsFromText:@"center" direction:@"up"];
  XCTAssertFalse(CGRectIsNull([center previewRectForDirection:@"up"]), @"a window is drawn for the sample size too");
  MWMPushOptions *bad = [MWMPushOptions defaultOptions];
  bad.thickness = 0;
  XCTAssertTrue(CGRectIsNull([bad previewRectForDirection:@"left"]));
}

- (void)testThePushOperationUsesTheSameGeometry {
  MoveOperation *op = [PushOperation pushOperationFromString:@"push left bar-resize:screenSizeX/3"];
  XCTAssertEqualObjects(op.dimensions.x, @"screenSizeX/3");
  XCTAssertEqualObjects(op.dimensions.y, @"screenSizeY");
  XCTAssertEqualObjects(op.topLeft.x, @"screenOriginX");
  op = [PushOperation pushOperationFromString:@"push down bar-resize:screenSizeY/4"];
  XCTAssertEqualObjects(op.topLeft.y, @"screenOriginY+screenSizeY-(screenSizeY/4)");
  XCTAssertThrows([PushOperation pushOperationFromString:@"push sideways"]);
  XCTAssertThrows([PushOperation pushOperationFromString:@"push left wobble"]);
  XCTAssertNil([PushOperation geometryForDirection:@"left" style:@"wobble"]);
}

@end
