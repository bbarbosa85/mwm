//
//  ConfigurationKeyboardView.h
//  Slate
//
//  The Keyboard page: the user's shortcuts as a map of a keyboard or as a list,
//  and the editor for one shortcut, which replaces the page while it's open.
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

@class ConfigurationShortcutEditorView, ConfigurationKeyboardView, SlateConfigDocument, SlateShortcutIndex;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ConfigurationKeyboardMode) {
  ConfigurationKeyboardModeMap,
  ConfigurationKeyboardModeList,
};

@protocol ConfigurationKeyboardViewDelegate <NSObject>
// A shortcut was added, changed, removed or switched; save the document.
- (void)keyboardViewDidChangeDocument:(ConfigurationKeyboardView *)view;
@optional
// The user wants to look at or change the modifier groups (they live on the Modifiers page).
- (void)keyboardViewWantsGroups:(ConfigurationKeyboardView *)view;
// A shortcut was opened for editing (YES) or closed (NO). The window hides its header and bottom bar while one is open.
- (void)keyboardView:(ConfigurationKeyboardView *)view didChangeEditing:(BOOL)editing;
@end

@interface ConfigurationKeyboardView : NSView

@property (weak, nullable) id<ConfigurationKeyboardViewDelegate> delegate;
@property (strong, nonatomic, nullable) SlateConfigDocument *document;
@property (assign, nonatomic) ConfigurationKeyboardMode mode;
@property (readonly, nullable) SlateShortcutIndex *index;
@property (readonly) NSUInteger conflictCount;

// Shows the list with only the shortcuts that share keys with another.
- (void)showConflicts;
// Opens a shortcut for editing (by index in the document's bindings), or a new one.
- (void)openBindingAtIndex:(NSUInteger)index;
- (void)startNewShortcut;
- (void)startNewShortcutInGroup:(nullable NSString *)groupName keyName:(nullable NSString *)keyName;
// The shortcut editor page, shown while a shortcut is open.
@property (readonly) ConfigurationShortcutEditorView *editor;
@property (readonly) BOOL isEditing;

// Rebuilds from the document, after something outside changed it.
- (void)reload;

@end

NS_ASSUME_NONNULL_END
