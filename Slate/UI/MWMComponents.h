//
//  MWMComponents.h
//  Slate
//
//  The reusable pieces of the configuration window, built from MWMTheme: labels,
//  cards, chips, icon tiles, separators and buttons. Pages ask for these instead
//  of assembling them again.
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

// A small rounded label with a tinted background, like "● Unsaved changes" or a conflict note.
// With no color it shows quiet text and no background.
@interface MWMChipView : NSView
@property (copy, nonatomic) NSString *text;
@property (strong, nonatomic, nullable) NSColor *color;
+ (instancetype)chipWithText:(NSString *)text color:(nullable NSColor *)color;
@end

@interface MWMComponents : NSObject

// Text.
+ (NSTextField *)labelWithText:(NSString *)text font:(NSFont *)font color:(NSColor *)color;
+ (NSTextField *)bodyLabel:(NSString *)text;          // primary text
+ (NSTextField *)secondaryLabel:(NSString *)text;     // small, secondary
+ (NSTextField *)captionLabel:(NSString *)text;       // small, tertiary
+ (NSTextField *)titleLabel:(NSString *)text;         // page and editor titles

// A rounded, softly tinted container; add content with constraints.
+ (NSView *)card;
// A thin line, as between the rows of a card.
+ (NSView *)separator;
// A rounded square with a symbol in a color: what a shortcut does, a feature, a group.
+ (NSView *)iconTileWithSymbol:(NSString *)symbolName color:(NSColor *)color size:(CGFloat)size;

// Buttons: the primary one answers Return.
+ (NSButton *)secondaryButtonWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action;
+ (NSButton *)primaryButtonWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action;

// A flexible space for stack views.
+ (NSView *)spacer;

@end

NS_ASSUME_NONNULL_END
