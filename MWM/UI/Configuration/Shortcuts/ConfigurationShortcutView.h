//
//  ConfigurationShortcutView.h
//  Slate
//
//  A table cell that shows a shortcut as key caps (⌃ ⌥ ⌘ R) and records a new
//  one when clicked: press the keys, Esc cancels. Like VS Code's keybindings.
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

@class ConfigurationShortcutView;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationShortcutViewDelegate <NSObject>
// A shortcut was recorded. modifierNames are in the file's order (ctrl, alt, shift, cmd).
- (void)shortcutView:(ConfigurationShortcutView *)view didRecordKey:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames;
@optional
// Recording is about to start, so the row can be selected.
- (void)shortcutViewWillBeginRecording:(ConfigurationShortcutView *)view;
@end

@interface ConfigurationShortcutView : NSView

@property (weak, nullable) id<ConfigurationShortcutViewDelegate> delegate;
@property (readonly) BOOL recording;

// Shows a shortcut. aliasName labels a named modifier group (like "hyper"),
// conflict is the reason to flag it (nil for none).
- (void)setKeyName:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames
         aliasName:(nullable NSString *)aliasName conflict:(nullable NSString *)conflict;

// Shows text as written, for a shortcut that can't be shown as key caps.
- (void)showRawText:(NSString *)text;

- (void)beginRecording;
- (void)cancelRecording;

// For tests: feeds a recorded key as if it was pressed.
- (void)finishRecordingWithKeyCode:(UInt16)keyCode modifierFlags:(NSEventModifierFlags)flags;

@end

NS_ASSUME_NONNULL_END
