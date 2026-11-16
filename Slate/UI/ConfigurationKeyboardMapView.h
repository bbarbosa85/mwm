//
//  ConfigurationKeyboardMapView.h
//  Slate
//
//  The Keyboard page's Map view: modifier groups in a column on the left, a keyboard
//  coloring the keys that group already uses, and under it the selected key as rows:
//  its keys, what it does (with a preview), what the same key does in other groups,
//  and Remove and Edit.
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

@class ConfigurationKeyboardMapView, SlateConfigDocument, SlateShortcutIndex;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationKeyboardMapViewDelegate <NSObject>
// A shortcut was removed; save the document.
- (void)keyboardMapViewDidChangeDocument:(ConfigurationKeyboardMapView *)view;
// Edit (a binding by index in the document), or add a shortcut on a free key.
- (void)keyboardMapView:(ConfigurationKeyboardMapView *)view wantsToEditBindingAtIndex:(NSUInteger)index;
- (void)keyboardMapView:(ConfigurationKeyboardMapView *)view wantsNewShortcutInGroup:(nullable NSString *)groupName keyName:(NSString *)keyName;
// The user wants to look at or change the groups themselves.
- (void)keyboardMapViewWantsGroups:(ConfigurationKeyboardMapView *)view;
@end

@interface ConfigurationKeyboardMapView : NSView

@property (weak, nullable) id<ConfigurationKeyboardMapViewDelegate> delegate;
@property (strong, nonatomic, nullable) SlateConfigDocument *document;
// The group whose keys are shown (nil until the document has one).
@property (copy, nonatomic, nullable) NSString *groupName;
@property (copy, nonatomic, nullable) NSString *selectedKeyName;
// Tests turn this off so removing doesn't ask.
@property (assign) BOOL confirmsRemoval;

- (void)reload;
// Selects a key as a click would.
- (void)selectKeyNamed:(NSString *)keyName;
- (void)removeSelected;

@end

NS_ASSUME_NONNULL_END
