//
//  TestSlateSlots.m
//  Slate
//
//  Tests for the locked presets, turning areas into formulas and back, and the
//  rules a custom slot has to follow.
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
#import "SlateSlots.h"
#import "SlateConfigDocument.h"

@interface TestSlateSlots : XCTestCase
@end

@implementation TestSlateSlots

- (void)testThereAreNineteenPresets {
  XCTAssertEqual([[SlateSlots presets] count], 19u);
  NSArray *names = [[SlateSlots presets] valueForKey:@"name"];
  XCTAssertEqual([[NSSet setWithArray:names] count], 19u, @"every name is different");
  for (SlateSlot *preset in [SlateSlots presets]) XCTAssertTrue(preset.preset);
  CGRect third2 = [SlateSlots presetNamed:@"third2"].rect;
  XCTAssertTrue([SlateSlots rect:third2 isSameAreaAs:CGRectMake(1 / 3.0, 0, 1 / 3.0, 1)]);
  XCTAssertTrue([SlateSlots rect:[SlateSlots presetNamed:@"quarterrow4"].rect isSameAreaAs:CGRectMake(0, 0.75, 1, 0.25)]);
}

- (void)testFormulasAreTheOnesAlreadyInConfigs {
  XCTAssertEqualObjects([SlateSlots presetNamed:@"full"].formula, @"move screenOriginX;screenOriginY screenSizeX;screenSizeY");
  XCTAssertEqualObjects([SlateSlots presetNamed:@"righthalf"].formula, @"move screenOriginX+screenSizeX/2;screenOriginY screenSizeX/2;screenSizeY");
  XCTAssertEqualObjects([SlateSlots presetNamed:@"third3"].formula, @"move screenOriginX+(2*screenSizeX/3);screenOriginY screenSizeX/3;screenSizeY");
  XCTAssertEqualObjects([SlateSlots presetNamed:@"quarter4"].formula, @"move screenOriginX+(3*screenSizeX/4);screenOriginY screenSizeX/4;screenSizeY");
}

- (void)testFormulasReadBackToTheSameArea {
  for (SlateSlot *preset in [SlateSlots presets]) {
    CGRect read;
    XCTAssertTrue([SlateSlots getRect:&read fromFormula:preset.formula], @"%@", preset.name);
    XCTAssertTrue([SlateSlots rect:read isSameAreaAs:preset.rect], @"%@", preset.name);
  }
  CGRect corner = CGRectMake(0.5, 0.5, 0.5, 0.5);
  CGRect read;
  XCTAssertTrue([SlateSlots getRect:&read fromFormula:[SlateSlots formulaForRect:corner]]);
  XCTAssertTrue([SlateSlots rect:read isSameAreaAs:corner]);
  CGRect odd = CGRectMake(0.1234, 0.05, 0.3333, 0.9);
  XCTAssertTrue([SlateSlots getRect:&read fromFormula:[SlateSlots formulaForRect:odd]]);
  XCTAssertTrue([SlateSlots rect:read isSameAreaAs:odd], @"any size round trips");
  XCTAssertFalse([SlateSlots getRect:&read fromFormula:@"move windowTopLeftX;0 100;100"]);
}

- (void)testSummaryReadsInPlainWords {
  XCTAssertEqualObjects([SlateSlots presetNamed:@"lefthalf"].summary, @"50% wide, full height");
  XCTAssertEqualObjects([SlateSlot slotNamed:@"c" rect:CGRectMake(0.5, 0.5, 0.5, 0.5) preset:NO].summary, @"50% wide, 50% tall");
  XCTAssertEqualObjects([SlateSlots presetNamed:@"quarterrow2"].summary, @"full width, 25% tall");
}

- (void)testCustomSlotsNeedANewNameAndANewArea {
  CGRect centre = CGRectMake(0.25, 0, 0.5, 1);
  SlateSlot *existing = [SlateSlot slotNamed:@"centre" rect:centre preset:NO];
  NSSet *taken = [NSSet setWithObjects:@"centre", @"hyper", nil];
  XCTAssertNil([SlateSlots problemWithName:@"focus" rect:CGRectMake(0.25, 0.25, 0.5, 0.5) otherSlots:@[existing] takenNames:taken]);
  XCTAssertNotNil([SlateSlots problemWithName:@"" rect:centre otherSlots:@[] takenNames:taken], @"a name is needed");
  XCTAssertTrue([[SlateSlots problemWithName:@"third1" rect:CGRectMake(0.1, 0.1, 0.2, 0.2) otherSlots:@[] takenNames:taken] containsString:@"preset"]);
  XCTAssertTrue([[SlateSlots problemWithName:@"hyper" rect:CGRectMake(0.1, 0.1, 0.2, 0.2) otherSlots:@[] takenNames:taken] containsString:@"already used"]);
  XCTAssertTrue([[SlateSlots problemWithName:@"again" rect:centre otherSlots:@[existing] takenNames:taken] containsString:@"Same area as \"centre\""]);
  XCTAssertTrue([[SlateSlots problemWithName:@"half" rect:CGRectMake(0, 0, 0.5, 1) otherSlots:@[] takenNames:taken] containsString:@"preset \"lefthalf\""]);
  XCTAssertNotNil([SlateSlots problemWithName:@"out" rect:CGRectMake(0.8, 0, 0.5, 1) otherSlots:@[] takenNames:taken], @"has to fit on the screen");
  XCTAssertNotNil([SlateSlots problemWithName:@"flat" rect:CGRectMake(0.1, 0.1, 0, 0.5) otherSlots:@[] takenNames:taken]);
}

- (void)testSnappingFollowsTheGrid {
  XCTAssertEqualWithAccuracy([SlateSlots snapped:0.26 tolerance:0.02 divisions:4], 0.25, 1e-9);
  XCTAssertEqualWithAccuracy([SlateSlots snapped:0.34 tolerance:0.02 divisions:3], 1 / 3.0, 1e-9);
  XCTAssertEqualWithAccuracy([SlateSlots snapped:0.26 tolerance:0.02 divisions:3], 0.26, 1e-9, @"not near a third");
  XCTAssertEqualWithAccuracy([SlateSlots snapped:0.413 tolerance:0.02 divisions:0], 0.41, 1e-9, @"no grid: whole percents");
  XCTAssertEqualWithAccuracy([SlateSlots snapped:0.99 tolerance:0.02 divisions:12], 1.0, 1e-9);
}

- (void)testPresetsWorkAsAliasesWithoutBeingInTheFile {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:
      @"bindings:\n  - key: a\n    mods: ctrl\n    action: ${lefthalf}\n" error:nil];
  XCTAssertNotNil(doc, @"the name is known, so the file is valid");
  XCTAssertEqualObjects([doc resolve:nil].bindings[0].action, @"move screenOriginX;screenOriginY screenSizeX/2;screenSizeY");
  XCTAssertNil([SlateConfigDocument documentFromString:@"bindings:\n  - key: a\n    mods: ctrl\n    action: ${nothere}\n" error:nil], @"made-up names are still errors");
}

- (void)testAFileEntryWinsOverAPresetOfTheSameName {
  SlateConfigDocument *doc = [SlateConfigDocument documentFromString:
      @"positions:\n  lefthalf: move 0;0 100;100\nbindings:\n  - key: a\n    mods: ctrl\n    action: ${lefthalf}\n" error:nil];
  XCTAssertEqualObjects([doc resolve:nil].bindings[0].action, @"move 0;0 100;100", @"old configs keep working");
}

@end
