//
//  MWMPushOptions.h
//  MWM
//
//  Formulas like screenOriginX+screenSizeX/3, checked and worked out for a screen of a given size, using the same
//  evaluator MWM uses when a shortcut runs. Nothing outside numbers, MWM's variable names, + - * / and
//  parentheses is accepted, so what the window shows is what the shortcut will do.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MWMPushStyle) {
  MWMPushStyleKeepSize,   // moves to the edge, the window keeps its size ("none")
  MWMPushStyleCenter,     // moves to the edge and centers along it
  MWMPushStyleBar,        // spans the screen, the window keeps its thickness
  MWMPushStyleThickness,  // spans the screen with a thickness set here ("bar-resize:...")
};

typedef NS_ENUM(NSInteger, MWMPushUnit) {
  MWMPushUnitPercent,  // a percent of the screen's width or height
  MWMPushUnitPixels,
  MWMPushUnitParts,    // one part in N: 3 is a third of the screen
};

// What follows the direction in a push: the style, the thickness of a set-thickness bar, and the screen.
// It writes the text the push operation reads, and reads back only what it would have written, so text it
// can't show (a hand-made thickness) stays as text.
@interface MWMPushOptions : NSObject <NSCopying>
@property (assign) MWMPushStyle style;
@property (assign) double thickness;
@property (assign) MWMPushUnit unit;
@property (copy) NSString *screen;       // empty for the current screen
@property (assign) BOOL writesKeepSize;  // "none" was written out, though it is the default

+ (instancetype)defaultOptions;
+ (nullable instancetype)optionsFromText:(NSString *)text direction:(NSString *)direction;
- (NSString *)textForDirection:(NSString *)direction;
// What is wrong with the thickness, or nil.
- (nullable NSString *)problem;
// The area the push gives a window on a sample screen, as fractions of it, or CGRectNull.
- (CGRect)previewRectForDirection:(NSString *)direction;
@end

NS_ASSUME_NONNULL_END
