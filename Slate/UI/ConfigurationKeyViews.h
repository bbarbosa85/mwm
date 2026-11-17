//
//  ConfigurationKeyViews.h
//  Slate
//
//  Small pieces shared by the Keyboard pages: key caps (⌃ ⌥ ⌘ 8), a group pill,
//  the colors for what a shortcut does, and a clickable text label.
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
#import "SlateShortcutIndex.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConfigurationKeyViews : NSObject

// One key cap with text in it ("⌘", "8").
+ (NSView *)capWithText:(NSString *)text size:(CGFloat)size;
// ⌃ ⌥ ⇧ ⌘ as small caps, for the modifiers in the list.
+ (NSView *)modifierCaps:(NSArray<NSString *> *)modifierNames size:(CGFloat)size;
// The modifiers and then the key: ⌃ ⌥ ⌘ 8.
+ (NSView *)keyCapsForModifiers:(NSArray<NSString *> *)modifierNames keyName:(NSString *)keyName size:(CGFloat)size;
// The same in a warning color (for shortcuts that share keys with another).
+ (NSView *)keyCapsForModifiers:(NSArray<NSString *> *)modifierNames keyName:(NSString *)keyName size:(CGFloat)size tint:(nullable NSColor *)tint;
// A rounded pill with a group's name.
+ (NSView *)pillWithText:(NSString *)text;
+ (NSView *)pillWithText:(NSString *)text tint:(nullable NSColor *)tint;
// The group pill (if the modifiers form a group) and the key caps, side by side.
+ (NSView *)shortcutViewForInfo:(SlateShortcutInfo *)info size:(CGFloat)size;
// The color that goes with what a shortcut does: blue for moving to a slot, green for
// windows and apps, purple for features.
+ (NSColor *)colorForKind:(SlateShortcutKind)kind;
+ (NSString *)symbolForKind:(SlateShortcutKind)kind;

@end

NS_ASSUME_NONNULL_END
