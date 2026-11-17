//
//  ConfigurationShortcutEditorView.h
//  Slate
//
//  The page for adding or editing one shortcut: a list of what it can do on the
//  left, the settings for that on the right, and the keys (typed with Record or
//  chosen on a map). The file is only changed when Save is pressed.
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
#import "SlateAction.h"

@class ConfigurationShortcutEditorView, SlateConfigDocument;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationShortcutEditorViewDelegate <NSObject>
// The shortcut was saved into the document; write the file.
- (void)shortcutEditorViewDidSave:(ConfigurationShortcutEditorView *)view;
// The editor was left (saved or not); show the page again.
- (void)shortcutEditorViewDidClose:(ConfigurationShortcutEditorView *)view;
@end

@interface ConfigurationShortcutEditorView : NSView

@property (weak, nullable) id<ConfigurationShortcutEditorViewDelegate> delegate;
@property (strong, nonatomic, nullable) SlateConfigDocument *document;
// Tests turn this off so leaving with changes doesn't ask.
@property (assign) BOOL confirmsDiscard;

// Opens a shortcut of the document (by binding index), or a new one, which can start with keys.
- (void)editBindingAtIndex:(NSUInteger)index;
- (void)startNewWithGroup:(nullable NSString *)groupName keyName:(nullable NSString *)keyName;

// The draft (also for tests).
@property (strong, readonly) SlateAction *draftAction;
@property (copy, nullable) NSString *draftKeyName;
@property (copy) NSArray<NSString *> *draftModifierNames;
@property (copy, nullable) NSString *draftGroupName;
@property (readonly) BOOL isNew;
@property (readonly) BOOL hasUnsavedChanges;
@property (readonly, nullable) NSString *problem;   // why Save is off, or nil

// Changes what the shortcut does, as picking it in the list would.
- (void)selectKind:(SlateActionKind)kind;
// Sets the keys as if recorded or picked on the map.
- (void)useKeyName:(NSString *)keyName modifierNames:(NSArray<NSString *> *)modifierNames groupName:(nullable NSString *)groupName;
// Feeds a pressed key to the recorder as if typed (for tests).
- (void)beginRecording;
- (void)recordKeyCode:(UInt16)keyCode modifierFlags:(NSEventModifierFlags)flags;
@property (readonly) BOOL recording;
- (void)confirmRecording;
- (void)cancelRecording;

// Picks the slot a Move shortcut goes to, as clicking its row would.
- (void)chooseSlotNamed:(NSString *)name;

- (void)save;
- (void)close;

@end

NS_ASSUME_NONNULL_END
