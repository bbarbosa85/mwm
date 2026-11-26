//
//  ConfigurationProfilesView.h
//
//  The Profiles page. Every profile kept in ~/.mwm is a card with its name, whether it is
//  the active one, and Use, Duplicate, Rename and Delete. Under them, Add profile opens the steps to make a new one.
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

#import <Cocoa/Cocoa.h>

@class ConfigurationProfilesView;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationProfilesViewDelegate <NSObject>
// Edit this profile in the window. MWM switches to it when Apply and Restart is pressed.
- (void)profilesView:(ConfigurationProfilesView *)view useProfileNamed:(NSString *)name;
// A profile was renamed (the window follows it if it is the one open).
- (void)profilesView:(ConfigurationProfilesView *)view didRenameProfileNamed:(NSString *)name to:(NSString *)newName;
@end

typedef NS_ENUM(NSInteger, ConfigurationProfilesMode) {
  ConfigurationProfilesModeList,           // the profiles, with Add profile under them
  ConfigurationProfilesModeSource,         // where the new one comes from
  ConfigurationProfilesModePickDuplicate,  // which profile to copy
  ConfigurationProfilesModeName,           // its name, with a summary of what it holds
};

@interface ConfigurationProfilesView : NSView

@property (weak, nullable) id<ConfigurationProfilesViewDelegate> delegate;
// Tests turn this off so nothing asks first.
@property (assign) BOOL interactive;
@property (readonly) NSTextField *nameField;
// The problem the last change ran into, in words (nil when it worked).
@property (readonly, copy, nullable) NSString *problem;
// The profile the window is editing (the running one when nil). It can't be deleted, and it is marked when it isn't the running one.
@property (copy, nullable, nonatomic) NSString *editingName;

- (void)reload;
- (void)useNamed:(NSString *)name;
@property (readonly) ConfigurationProfilesMode mode;
// What the profile being added would be, and where it comes from.
@property (readonly, copy, nullable) NSString *draftFrom;
// Counts of what a profile's text holds: shortcuts, modifiers, screens, slots, settings, and the group names.
- (NSDictionary *)summaryForText:(NSString *)text;

// Adding: Add profile, then a source, then a name.
- (void)beginAdd;
- (void)beginDraftFromRunning;
- (void)beginDraftDuplicating:(NSString *)name fromCard:(BOOL)fromCard;
- (void)beginDraftFromFileAtPath:(NSString *)path;
- (void)goBack;
- (void)cancelAdd;
- (void)createDraftNamed:(NSString *)name;
- (void)duplicateNamed:(NSString *)name as:(NSString *)copyName;
- (void)renameNamed:(NSString *)name to:(NSString *)newName;
- (void)deleteNamed:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
