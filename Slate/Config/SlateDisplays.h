//
//  SlateDisplays.h
//  Slate
//
//  The connected displays, and screen "roles": a way to name a screen that
//  doesn't change when you dock or undock. A role is written in a monitors
//  entry as "display: built-in" or "display: Samsung Odyssey 2560x1440 #2" and
//  is turned into a screen reference MWM understands when the config loads.
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SlateDisplay : NSObject
@property (copy) NSString *name;       // the model, like "Samsung Odyssey G9"
@property (assign) NSInteger width;
@property (assign) NSInteger height;
@property (assign) BOOL builtIn;
@property (assign) CGFloat originX;    // where it sits, relative to the main display
@property (assign) CGFloat originY;    // y grows downward
+ (SlateDisplay *)displayNamed:(NSString *)name width:(NSInteger)width height:(NSInteger)height builtIn:(BOOL)builtIn x:(CGFloat)x y:(CGFloat)y;
- (NSString *)sizeText;                // "2560x1440"
@end

@interface SlateDisplays : NSObject

// The connected displays, left to right (then top to bottom).
+ (NSArray<SlateDisplay *> *)connected;
// Tests pretend these displays are connected.
+ (void)setConnectedOverride:(nullable NSArray<SlateDisplay *> *)displays;

+ (BOOL)isRole:(nullable NSString *)value;

// The display a role stands for, or nil when it isn't connected. Identical
// displays are numbered left to right: "#1" is the leftmost.
+ (nullable SlateDisplay *)displayForRole:(NSString *)role in:(NSArray<SlateDisplay *> *)displays;
// The role that names this display. "#n" is added only when others look the same.
+ (NSString *)roleForDisplay:(SlateDisplay *)display in:(NSArray<SlateDisplay *> *)displays;
// What a monitors value turns into: a role becomes a screen reference (a screen
// that isn't connected becomes one that doesn't exist, so MWM uses the current
// screen); anything else is returned as it is.
+ (NSString *)referenceForValue:(NSString *)value;
+ (NSString *)referenceForValue:(NSString *)value displays:(NSArray<SlateDisplay *> *)displays;

// "monitor-built-in", "monitor-samsung", "monitor-samsung-1".
+ (NSString *)suggestedNameForDisplay:(SlateDisplay *)display in:(NSArray<SlateDisplay *> *)displays;
// How many displays share this one's model and size.
+ (NSUInteger)identicalCountForDisplay:(SlateDisplay *)display in:(NSArray<SlateDisplay *> *)displays;

// The display an old numeric screen reference ("0", "1") points at.
+ (nullable SlateDisplay *)displayForNumber:(NSInteger)number leftToRight:(BOOL)leftToRight in:(NSArray<SlateDisplay *> *)displays;

@end

NS_ASSUME_NONNULL_END
