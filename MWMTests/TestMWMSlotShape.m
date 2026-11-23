//
//  TestMWMSlotShape.m
//
//  A slot as units and margins: the formula it writes, and reading it back.
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
#import "MWMSlotShape.h"
#import "MWMSlots.h"

@interface TestMWMSlotShape : XCTestCase
@end

@implementation TestMWMSlotShape

- (void)testAPlainPercentSlotWritesWhatItAlwaysDid {
  for (MWMSlot *preset in [MWMSlots presets]) {
    MWMSlotShape *shape = [MWMSlotShape shapeFromRect:preset.rect];
    XCTAssertTrue([shape isPlainPercent]);
    XCTAssertEqualObjects([shape formula], [MWMSlots formulaForRect:preset.rect], @"%@", preset.name);
    MWMSlotShape *back = [MWMSlotShape shapeFromFormula:preset.formula];
    XCTAssertNotNil(back, @"%@", preset.name);
    XCTAssertTrue([back isPlainPercent]);
    XCTAssertTrue([MWMSlots rect:[back fractionRectForScreenSize:CGSizeMake(1000, 1000)] isSameAreaAs:preset.rect], @"%@", preset.name);
  }
  CGRect odd = CGRectMake(0.1234, 0.25, 0.3333, 0.75);
  XCTAssertEqualObjects([[MWMSlotShape shapeFromRect:odd] formula], [MWMSlots formulaForRect:odd]);
}

- (void)testAMarginSlotIsReadAndWrittenBack {
  NSString *text = @"move (screenOriginX+screenSizeX/5)+14;screenOriginY (4*screenSizeX/5)-14;screenSizeY";
  MWMSlotShape *shape = [MWMSlotShape shapeFromFormula:text];
  XCTAssertNotNil(shape, @"the margin example from daily-driver.mwm.yml");
  XCTAssertFalse([shape isPlainPercent]);
  XCTAssertEqualWithAccuracy(shape.horizontal.position, 0.2, 1e-6);
  XCTAssertEqualWithAccuracy(shape.horizontal.sizeFraction, 0.8, 1e-6);
  XCTAssertEqual(shape.horizontal.marginStart, 14);
  XCTAssertEqual(shape.horizontal.marginEnd, 0);
  XCTAssertEqualObjects([shape formula], text);
  CGRect r = [shape rectForScreenSize:CGSizeMake(1000, 500)];
  XCTAssertEqualWithAccuracy(r.origin.x, 214, 0.01);
  XCTAssertEqualWithAccuracy(r.size.width, 786, 0.01);
}

- (void)testMarginsOnEverySide {
  MWMSlotShape *shape = [MWMSlotShape shapeFromRect:CGRectMake(0, 0, 1, 1)];
  shape.horizontal.marginStart = 10; shape.horizontal.marginEnd = 30;
  shape.vertical.marginStart = 20; shape.vertical.marginEnd = 40;
  CGRect r = [shape rectForScreenSize:CGSizeMake(1000, 800)];
  XCTAssertEqual(r.origin.x, 10); XCTAssertEqual(r.size.width, 960);
  XCTAssertEqual(r.origin.y, 20); XCTAssertEqual(r.size.height, 740);
  MWMSlotShape *back = [MWMSlotShape shapeFromFormula:[shape formula]];
  XCTAssertNotNil(back, @"%@", [shape formula]);
  XCTAssertEqual(back.horizontal.marginEnd, 30);
  XCTAssertEqual(back.vertical.marginStart, 20);
  XCTAssertTrue([back isEqualToShape:shape]);
}

- (void)testAFixedSizeCenteredOnTheScreen {
  MWMSlotShape *shape = [[MWMSlotShape alloc] init];
  shape.horizontal.sizeInPixels = YES; shape.horizontal.sizePixels = 1200; shape.horizontal.centered = YES;
  shape.vertical.sizeInPixels = YES; shape.vertical.sizePixels = 800; shape.vertical.centered = YES;
  XCTAssertEqualObjects([shape formula], @"move screenOriginX+(screenSizeX-1200)/2;screenOriginY+(screenSizeY-800)/2 1200;800");
  CGRect r = [shape rectForScreenSize:CGSizeMake(1920, 1080)];
  XCTAssertEqual(r.origin.x, 360); XCTAssertEqual(r.size.width, 1200);
  XCTAssertEqual(r.origin.y, 140); XCTAssertEqual(r.size.height, 800);
  MWMSlotShape *back = [MWMSlotShape shapeFromFormula:[shape formula]];
  XCTAssertNotNil(back);
  XCTAssertTrue(back.horizontal.centered && back.horizontal.sizeInPixels);
  XCTAssertEqual(back.vertical.sizePixels, 800);
}

- (void)testAFixedSizeAtAPercentPositionWithAMargin {
  MWMSlotShape *shape = [[MWMSlotShape alloc] init];
  shape.horizontal.position = 0.5; shape.horizontal.sizeInPixels = YES; shape.horizontal.sizePixels = 600; shape.horizontal.marginStart = 20; shape.horizontal.marginEnd = 20;
  MWMSlotShape *back = [MWMSlotShape shapeFromFormula:[shape formula]];
  XCTAssertNotNil(back, @"%@", [shape formula]);
  XCTAssertTrue([back isEqualToShape:shape]);
  XCTAssertEqual([back rectForScreenSize:CGSizeMake(2000, 1000)].size.width, 560);
}

- (void)testFormulasItWouldNotHaveWrittenAreCustom {
  // Hand-written variants of the same thing keep their text.
  XCTAssertNil([MWMSlotShape shapeFromFormula:@"move screenOriginX+(screenSizeX/3);screenOriginY screenSizeX/3;screenSizeY"], @"the extra parentheses in third2");
  XCTAssertNil([MWMSlotShape shapeFromFormula:@"move windowTopLeftX;windowTopLeftY screenSizeX/3;screenSizeY/2"]);
  XCTAssertNil([MWMSlotShape shapeFromFormula:@"move screenOriginX;screenOriginY screenSizeX;screenSizeY 1"], @"it names a screen");
  XCTAssertNil([MWMSlotShape shapeFromFormula:@"hint"]);
  XCTAssertNil([MWMSlotShape shapeFromFormula:@"move screenOriginX+screenSizeX/4;0 screenSizeX/4;screenSizeY"]);
  MWMSlotShape *endMargin = [MWMSlotShape shapeFromFormula:@"move screenOriginX;screenOriginY screenSizeX-50;screenSizeY"];
  XCTAssertNotNil(endMargin, @"a margin only at the end is something it writes");
  XCTAssertEqual(endMargin.horizontal.marginEnd, 50);
  XCTAssertEqual(endMargin.horizontal.marginStart, 0);
  XCTAssertNil([MWMSlotShape shapeFromFormula:@"move screenOriginX;screenOriginY screenSizeX-50-10;screenSizeY"]);
}

- (void)testMarginsThatEatTheSlotAreAProblem {
  MWMSlotShape *shape = [MWMSlotShape shapeFromRect:CGRectMake(0, 0, 0.1, 1)];
  XCTAssertNil([shape problem]);
  shape.horizontal.marginStart = 80; shape.horizontal.marginEnd = 80;
  XCTAssertNotNil([shape problem]);
}

- (void)testCopiesAreIndependent {
  MWMSlotShape *shape = [MWMSlotShape shapeFromRect:CGRectMake(0, 0, 0.5, 1)];
  MWMSlotShape *copy = [shape copy];
  copy.horizontal.marginStart = 5;
  XCTAssertEqual(shape.horizontal.marginStart, 0);
  XCTAssertFalse([copy isEqualToShape:shape]);
}

@end
