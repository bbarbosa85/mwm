//
//  MWMReservedShortcuts.h
//  Slate
//
//  Key combinations MWM won't let you use for a shortcut: the ones macOS and almost
//  every app use (⌘S, ⌘C, ⌘Tab, the screenshot keys, ...), and any key pressed with no
//  modifier, which would stop it typing. Shortcuts already in the file are left alone.
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

NS_ASSUME_NONNULL_BEGIN

@interface MWMReservedShortcuts : NSObject

// Why a combo can't be used, in a sentence for the user, or nil when it's allowed.
// keyName is a name from the key table ("s", "tab", "left"); modifierNames are
// "ctrl", "alt", "shift", "cmd" in any order.
+ (nullable NSString *)reasonForKeyName:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames;

// Every reserved combo for the read-only list: @{@"modifiers": [names], @"key": name, @"reason": text}.
+ (NSArray<NSDictionary *> *)all;

@end

NS_ASSUME_NONNULL_END
