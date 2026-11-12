//
//  SlateShortcut.h
//  Slate
//
//  Helpers for key shortcuts as they appear in ~/.mwm.yml: key names
//  ("pad5", "left", "r"), modifier names ("ctrl;alt;cmd"), how to show them
//  (⌃⌥⌘ R), and how to turn a pressed key into the names the file uses.
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

@class SlateConfigEntry;

NS_ASSUME_NONNULL_BEGIN

@interface SlateShortcut : NSObject

// The name the file uses for a physical key (for the current keyboard layout), or nil if unsupported.
+ (nullable NSString *)keyNameForKeyCode:(UInt16)keyCode;

// Modifier names in a fixed order (ctrl, alt, shift, cmd, fn). nil if the text has an unknown modifier.
+ (nullable NSArray<NSString *> *)modifierNamesFromString:(nullable NSString *)modifiers;
+ (NSArray<NSString *> *)modifierNamesFromFlags:(NSEventModifierFlags)flags;
+ (NSString *)stringFromModifierNames:(NSArray<NSString *> *)names;

// "${name}" of the first entry whose value is exactly this set of modifiers, or nil.
+ (nullable NSString *)aliasForModifierNames:(NSArray<NSString *> *)names inEntries:(NSArray<SlateConfigEntry *> *)entries;

// ⌃ ⌥ ⇧ ⌘ for a modifier name.
+ (NSString *)symbolForModifierName:(NSString *)name;
// "R", "←", "Num 5", "F13", "Space" for a key name.
+ (NSString *)displayForKeyName:(NSString *)keyName;

// A value that's equal for shortcuts that fire on the same keys, whatever
// order the modifiers are written in. nil if the key or modifiers aren't valid.
+ (nullable NSString *)identityForKey:(NSString *)key modifiers:(nullable NSString *)modifiers;

@end

NS_ASSUME_NONNULL_END
