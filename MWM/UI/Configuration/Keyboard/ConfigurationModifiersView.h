//
//  ConfigurationModifiersView.h
//  MWM
//
//  The Modifiers page: your modifier groups (hyper and the like) as cards, and an editor where a group is
//  built by clicking modifier keys on a drawn Mac keyboard, then named and saved.
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

@class ConfigurationModifiersView, MWMConfigDocument;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationModifiersViewDelegate <NSObject>
// The modifier groups (or the shortcuts using them) were changed; save the document.
- (void)modifiersViewDidChangeDocument:(ConfigurationModifiersView *)view;
@optional
// A group was opened for editing (YES) or closed (NO). The window hides its header and bottom bar while one is open.
- (void)modifiersView:(ConfigurationModifiersView *)view didChangeEditing:(BOOL)editing;
@end

@interface ConfigurationModifiersView : NSView

@property (weak, nullable) id<ConfigurationModifiersViewDelegate> delegate;
// Setting it (or clearing it) closes an open editor.
@property (strong, nonatomic, nullable) MWMConfigDocument *document;

- (void)startNewGroup;
- (void)editGroupNamed:(NSString *)name;
// Removes a group, unless a shortcut uses it.
- (void)removeGroupNamed:(NSString *)name;

// Tests turn alerts off (removing a used group, discarding changes).
@property (assign) BOOL showsAlerts;

// The editor's state (also for tests).
@property (readonly) BOOL editing;
@property (copy, nullable) NSString *draftName;
@property (copy) NSArray<NSString *> *draftModifiers;    // ctrl, alt, shift, cmd (in that order)
@property (readonly) BOOL hasUnsavedChanges;
@property (readonly, nullable) NSString *problem;        // why Save is off, or nil
// What changing the keys of this group would cause: shortcuts that start firing on the same keys as another
// one, or on keys macOS keeps. Only what the change adds; it doesn't stop Save.
@property (readonly) NSArray<NSString *> *warnings;
// Adds the modifier to the combination being built, or takes it out (what a click on the key does).
- (void)toggleModifier:(NSString *)name;
- (void)save;
- (void)revert;

@end

NS_ASSUME_NONNULL_END
