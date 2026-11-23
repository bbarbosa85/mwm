//
//  MWMSlots.h
//  Slate
//
//  Slots: named areas of a screen, as fractions of it (x, y, width, height
//  from the top left), so one slot works on any screen. There are locked
//  presets (full, halves, thirds and quarters, each across and down) and the
//  user's own. In ~/.mwm.yml a slot is a "positions" entry holding a move
//  formula like "move screenOriginX;screenOriginY screenSizeX/2;screenSizeY".
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

@interface MWMSlot : NSObject
@property (copy) NSString *name;
@property (assign) CGRect rect;      // fractions of the screen, origin at the top left
@property (assign) BOOL preset;
+ (MWMSlot *)slotNamed:(NSString *)name rect:(CGRect)rect preset:(BOOL)preset;
// The "move ..." formula the config stores for this area.
- (NSString *)formula;
// "50% wide, full height", for the list.
- (NSString *)summary;
@end

@interface MWMSlots : NSObject

// The 19 locked presets: full, lefthalf/righthalf/tophalf/bottomhalf,
// third1-3 and thirdrow1-3, quarter1-4 and quarterrow1-4.
+ (NSArray<MWMSlot *> *)presets;
+ (nullable MWMSlot *)presetNamed:(NSString *)name;
+ (nullable MWMSlot *)presetWithRect:(CGRect)rect;

+ (NSString *)formulaForRect:(CGRect)rect;
// The pieces formulaForRect: is made of, for formulas that add margins or pixel sizes to them:
// "screenSizeX/4", "(3*screenSizeX/4)" (the variable itself for all of it), and "screenOriginX+screenSizeX/4".
+ (NSString *)scaledVariable:(NSString *)variable fraction:(CGFloat)fraction;
+ (NSString *)positionWithOrigin:(NSString *)origin size:(NSString *)size fraction:(CGFloat)fraction;
// Reads a stored formula back into an area. NO if it depends on the window or a screen size.
+ (BOOL)getRect:(CGRect *)rect fromFormula:(NSString *)formula;
// An area to draw for any formula that can be worked out (margins, pixel sizes, window names), as fractions of a sample
// screen. Names the document defines as ${alias} must be expanded first. NO for a formula with a mistake.
+ (BOOL)getPreviewRect:(CGRect *)rect fromFormula:(NSString *)formula;

+ (BOOL)rect:(CGRect)a isSameAreaAs:(CGRect)b;

// Why a slot can't be saved as it is, or nil if it can. Names must differ from
// every other name (presets, slots, other aliases) and the area must be new.
// The name part of that check alone.
+ (nullable NSString *)problemWithName:(NSString *)name takenNames:(NSSet<NSString *> *)taken;
+ (nullable NSString *)problemWithName:(NSString *)name rect:(CGRect)rect
                            otherSlots:(NSArray<MWMSlot *> *)others takenNames:(NSSet<NSString *> *)taken;

// A value on the grid of the given number of divisions (4 = quarters) when it's
// within tolerance of a line, else rounded to a whole percent. 0 or 1 means no grid.
+ (CGFloat)snapped:(CGFloat)value tolerance:(CGFloat)tolerance divisions:(NSInteger)divisions;

@end

NS_ASSUME_NONNULL_END
