//
//  ConfigurationSlotsView.h
//  Slate
//
//  The Slots page: a list of slots (locked presets and the user's own) next to
//  a canvas where a custom slot is dragged and resized, a name, exact values
//  under "Advanced", and Save and Revert when something has changed.
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

@class ConfigurationSlotsView, ConfigurationSlotCanvas, SlateConfigDocument;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationSlotsViewDelegate <NSObject>
// The positions in the document were changed; save it.
- (void)slotsViewDidChangeDocument:(ConfigurationSlotsView *)view;
@end

@interface ConfigurationSlotsView : NSView

@property (weak, nullable) id<ConfigurationSlotsViewDelegate> delegate;
@property (strong, nonatomic, nullable) SlateConfigDocument *document;

// Shows a slot (a preset or custom one) by name.
- (void)selectSlotNamed:(NSString *)name;
// Starts a new custom slot in the middle of the screen.
- (void)startNewSlot;

// The state of the editor (also for tests).
@property (readonly, nullable) NSString *selectedName;
@property (readonly) BOOL hasUnsavedChanges;
@property (readonly, nullable) NSString *problem;   // why Save is off, or nil
@property (readonly) ConfigurationSlotCanvas *canvas;
@property (copy, nullable) NSString *draftName;
@property (assign) CGRect draftRect;

// Removes a custom slot from the document (not while a shortcut uses it).
- (void)removeSlotNamed:(NSString *)name;

- (void)save;
- (void)revert;

@end

NS_ASSUME_NONNULL_END
