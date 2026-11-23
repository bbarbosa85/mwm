//
//  MWMFormula.h
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
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see http://www.gnu.org/licenses

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface MWMFormula : NSObject

// screenOriginX, screenSizeX, windowSizeX and the rest.
+ (NSArray<NSString *> *)variableNames;

// nil when the expression is fine; otherwise a plain sentence saying what is wrong. Names the document defines as
// ${alias} must be expanded first.
+ (nullable NSString *)errorForExpression:(NSString *)expression;

// YES when the text uses something outside what the window checks (functions, brackets, other characters). MWM's
// runtime accepts more than the window does, so such a formula is left alone rather than reported.
+ (BOOL)moveTextUsesUnsupportedSyntax:(NSString *)text;

// The same for a whole "move x;y width;height [screen]" text.
+ (nullable NSString *)errorForMoveText:(NSString *)text;

// The area, in points, that a move text gives on a screen of that size with a window at that place; NO and an
// explanation when it can't be worked out.
+ (BOOL)getRect:(CGRect *)rect fromMoveText:(NSString *)text screenSize:(CGSize)screen window:(CGRect)window error:(NSString * _Nullable * _Nullable)error;

// Half the screen, centered: the window used for names like windowSizeX when there is no real window.
+ (CGRect)sampleWindowForScreenSize:(CGSize)screen;

@end

NS_ASSUME_NONNULL_END
