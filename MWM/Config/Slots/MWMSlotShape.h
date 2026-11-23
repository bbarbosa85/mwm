//
//  MWMSlotShape.h
//  MWM
//
//  A slot as the window edits it: where it starts and how big it is on each axis (a percent of the screen, or
//  pixels; centered or not), with a margin in pixels on each side. It writes the move formula for that, and
//  reads back only the formulas it would have written itself: anything else is a custom formula and keeps its
//  exact text.
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

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// One direction of a slot (across, or down).
@interface MWMSlotAxis : NSObject <NSCopying>
// Where it starts, as a fraction of the screen. Ignored when centered.
@property (assign) CGFloat position;
@property (assign) BOOL centered;
// How big it is: a fraction of the screen, or a number of pixels.
@property (assign) BOOL sizeInPixels;
@property (assign) CGFloat sizeFraction;
@property (assign) NSInteger sizePixels;
// Space left around it, in pixels.
@property (assign) NSInteger marginStart;
@property (assign) NSInteger marginEnd;
@end

@interface MWMSlotShape : NSObject <NSCopying>

@property (strong) MWMSlotAxis *horizontal;
@property (strong) MWMSlotAxis *vertical;

// A plain percent slot with no margins.
+ (instancetype)shapeFromRect:(CGRect)fractions;
// nil when the formula isn't one this shape would have written (a custom formula, or one that names a screen).
+ (nullable instancetype)shapeFromFormula:(NSString *)formula;

// "move x;y width;height". A plain percent shape gives exactly what MWMSlots formulaForRect: gives.
- (NSString *)formula;
- (BOOL)isPlainPercent;
// The area in points on a screen of that size.
- (CGRect)rectForScreenSize:(CGSize)screen;
// The same as fractions of the screen, for drawing.
- (CGRect)fractionRectForScreenSize:(CGSize)screen;
// Why the shape can't be a slot (the margins eat all of it), or nil.
- (nullable NSString *)problem;
- (BOOL)isEqualToShape:(MWMSlotShape *)other;

@end

NS_ASSUME_NONNULL_END
