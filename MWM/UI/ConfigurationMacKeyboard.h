//
//  ConfigurationMacKeyboard.h
//  MWM
//
//  A Mac keyboard drawn in key units, shared by the Keyboard map (keys colored by what their shortcut does)
//  and the modifier group editor (its modifier keys are clickable, to build a combination).
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

extern const CGFloat kMacKeyboardUnitsWide;
extern const CGFloat kMacKeyboardUnitsTall;
// Without the number pad on the right.
extern const CGFloat kMacKeyboardCompactUnitsWide;

typedef NS_ENUM(NSInteger, MapKeyState) {
  MapKeyStateFree,
  MapKeyStateTaken,      // has a shortcut in this group (colored by what it does)
  MapKeyStateConflict,
  MapKeyStateReserved,   // macOS uses it with this group's modifiers
  MapKeyStateOn,         // a modifier that is part of the combination being built
};

// One key. A modifier key is drawn dashed and can't hold a shortcut; in the group editor it is clickable.
@interface ConfigurationMapKey : NSView
@property (copy) NSString *keyName;
@property (copy) NSString *label;
@property (assign) MapKeyState state;
@property (strong, nullable) NSColor *tint;
@property (assign) BOOL selected;
@property (assign) BOOL modifier;
// ctrl, alt, shift or cmd for the left-side keys that build a group. The right-side keys and fn are nil: they
// would only repeat what the left ones say.
@property (copy, nullable) NSString *modifierName;
// Drawn faint, as a key that isn't part of what is being done.
@property (assign) BOOL dimmed;
// Lets a modifier key take clicks (it can't hold a shortcut, but the group editor builds combinations with it).
@property (assign) BOOL clickable;
@property (assign) NSRect units;    // x, y, width, height in key units
@property (copy, nullable) void (^onClick)(void);
@end

// The whole keyboard: the keys follow the width they're given.
@interface ConfigurationMacKeyboard : NSView
@property (copy) NSArray<ConfigurationMapKey *> *keys;
// How many key units wide the keys are laid out (kMacKeyboardUnitsWide, or the compact width without the number pad).
@property (assign) CGFloat unitsWide;
// The Mac layout. A key named "modifier-<name>" is a modifier.
+ (NSArray<ConfigurationMapKey *> *)buildKeys;
// The same without the number pad (lay it out with kMacKeyboardCompactUnitsWide).
+ (NSArray<ConfigurationMapKey *> *)buildCompactKeys;

// Makes the left ctrl, opt, shift and ⌘ take clicks and show whether they are in `names`. `toggle` is called
// with ctrl, alt, shift or cmd. With `dimOthers` the other keys are faint and inert (the group editor); without,
// they keep what they do (choosing keys for a shortcut).
- (void)showModifierPickerWithSelected:(NSArray<NSString *> *)names dimOthers:(BOOL)dim toggle:(void (^)(NSString *name))toggle;
// Updates which modifiers are shown as on.
- (void)setSelectedModifiers:(NSArray<NSString *> *)names;
@end

NS_ASSUME_NONNULL_END
