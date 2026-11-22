//
//  TestMWMFormula.m
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
#import "MWMFormula.h"

@interface TestMWMFormula : XCTestCase
@end

@implementation TestMWMFormula

- (void)testFormulasThatAreFineHaveNoError {
  for (NSString *text in @[@"screenSizeX/3", @"screenOriginX+(screenSizeX/3)", @"(4*screenSizeX/5)-14", @"1200", @"(screenSizeX-1200)/2",
                          @"windowTopLeftX", @"newWindowSizeY*2", @"0.5*screenSizeY"]) {
    XCTAssertNil([MWMFormula errorForExpression:text], @"%@", text);
  }
}

- (void)testEmptyAndSpacedFormulasAreRefusedInPlainWords {
  XCTAssertEqualObjects([MWMFormula errorForExpression:@""], @"Enter a number or a formula.");
  XCTAssertEqualObjects([MWMFormula errorForExpression:@"   "], @"Enter a number or a formula.");
  XCTAssertTrue([[MWMFormula errorForExpression:@"screenSizeX / 3"] containsString:@"Leave out the spaces"]);
}

- (void)testAnUnknownNameSaysWhichOnesAreKnown {
  NSString *error = [MWMFormula errorForExpression:@"screenSizeZ/3"];
  XCTAssertTrue([error containsString:@"\"screenSizeZ\" isn't a name MWM knows"], @"%@", error);
  XCTAssertTrue([error containsString:@"screenSizeX"], @"%@", error);
}

- (void)testAnAliasThatWasNotExpandedIsReported {
  XCTAssertEqualObjects([MWMFormula errorForExpression:@"screenSizeX-${gap}"], @"${gap} isn't defined.");
}

- (void)testOnlyNumbersNamesOperatorsAndParenthesesAreAccepted {
  for (NSString *text in @[@"FUNCTION(1,'abs')", @"screenSizeX;3", @"'a'", @"screenSizeX[0]", @"3==3", @"screenSizeX$"]) {
    XCTAssertNotNil([MWMFormula errorForExpression:text], @"%@", text);
  }
}

- (void)testUnbalancedParenthesesAndDivisionByZeroAreReported {
  XCTAssertEqualObjects([MWMFormula errorForExpression:@"(screenSizeX/3"], @"The parentheses don't match.");
  XCTAssertEqualObjects([MWMFormula errorForExpression:@")screenSizeX("], @"The parentheses don't match.");
  XCTAssertEqualObjects([MWMFormula errorForExpression:@"screenSizeX/0"], @"This divides by zero.");
}

- (void)testAFormulaThatCannotBeWorkedOutIsReportedNotThrown {
  XCTAssertNotNil([MWMFormula errorForExpression:@"3+*4"]);
}

#pragma mark - Move texts

- (CGRect)rect:(NSString *)text screen:(CGSize)screen window:(CGRect)window error:(NSString **)error {
  CGRect rect = CGRectZero;
  return [MWMFormula getRect:&rect fromMoveText:text screenSize:screen window:window error:error] ? rect : CGRectNull;
}

- (void)testAMoveTextWorksOutToAreaOnAScreen {
  CGSize screen = CGSizeMake(1800, 1000);
  CGRect r = [self rect:@"move screenOriginX+(screenSizeX/3);screenOriginY screenSizeX/3;screenSizeY" screen:screen window:CGRectZero error:nil];
  XCTAssertEqualWithAccuracy(r.origin.x, 600, 1);
  XCTAssertEqualWithAccuracy(r.size.width, 600, 1);
  XCTAssertEqualWithAccuracy(r.size.height, 1000, 1);
  CGRect margin = [self rect:@"move (screenOriginX+screenSizeX/5)+14;screenOriginY (4*screenSizeX/5)-14;screenSizeY" screen:screen window:CGRectZero error:nil];
  XCTAssertEqualWithAccuracy(margin.origin.x, 374, 1);
  XCTAssertEqualWithAccuracy(margin.size.width, 1426, 1);
}

- (void)testWindowNamesUseTheWindowGiven {
  CGRect window = CGRectMake(100, 50, 800, 600);
  CGRect r = [self rect:@"move windowTopLeftX;windowTopLeftY windowSizeX/2;windowSizeY" screen:CGSizeMake(1800, 1000) window:window error:nil];
  XCTAssertEqualWithAccuracy(r.origin.x, 100, 0.5);
  XCTAssertEqualWithAccuracy(r.origin.y, 50, 0.5);
  XCTAssertEqualWithAccuracy(r.size.width, 400, 0.5);
  XCTAssertEqualWithAccuracy(r.size.height, 600, 0.5);
}

- (void)testFixedSizesAndAScreenNameAreFine {
  CGRect r = [self rect:@"move 100;100 1200;800 ${monitor-x-size}" screen:CGSizeMake(1800, 1000) window:CGRectZero error:nil];
  XCTAssertEqual(r.size.width, 1200, @"the screen token after the sizes isn't evaluated");
  r = [self rect:@"move 100;100 1200;800" screen:CGSizeMake(1800, 1000) window:CGRectZero error:nil];
  XCTAssertEqual(r.size.width, 1200);
  r = [self rect:@"move 100;100 1200;800 1" screen:CGSizeMake(1800, 1000) window:CGRectZero error:nil];
  XCTAssertEqual(r.size.height, 800, @"a screen token after it is ignored here");
}

- (void)testAMoveTextNamesTheBrokenPart {
  NSString *error = nil;
  CGRect r = [self rect:@"move 0;0 screenSizeX/3;screenSizeZ" screen:CGSizeMake(1800, 1000) window:CGRectZero error:&error];
  XCTAssertTrue(CGRectIsNull(r));
  XCTAssertTrue([error hasPrefix:@"Height: "], @"%@", error);
  error = nil;
  [self rect:@"hint" screen:CGSizeMake(1800, 1000) window:CGRectZero error:&error];
  XCTAssertTrue([error containsString:@"Write it as: move x;y width;height"], @"%@", error);
  error = nil;
  [self rect:@"move 0;0" screen:CGSizeMake(1800, 1000) window:CGRectZero error:&error];
  XCTAssertNotNil(error);
}

- (void)testErrorForMoveText {
  XCTAssertNil([MWMFormula errorForMoveText:@"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY"]);
  XCTAssertNotNil([MWMFormula errorForMoveText:@"move screenOriginX;screenOriginY screenSizeX/0;screenSizeY"]);
}

@end
