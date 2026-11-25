//
//  ConfigurationConfigurationsView.h
//
//  The Configurations page. Every configuration kept in ~/.mwm is a card with its name, whether it is
//  the active one, and Activate, Duplicate, Rename and Delete. Under them, a card makes a new one.
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

@class ConfigurationConfigurationsView;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationConfigurationsViewDelegate <NSObject>
// Save what is open, make this the active configuration and restart MWM.
- (void)configurationsView:(ConfigurationConfigurationsView *)view switchToConfigurationNamed:(NSString *)name;
// The active configuration's file was renamed: show it again.
- (void)configurationsViewDidRenameActive:(ConfigurationConfigurationsView *)view;
@end

@interface ConfigurationConfigurationsView : NSView

@property (weak, nullable) id<ConfigurationConfigurationsViewDelegate> delegate;
// Tests turn this off so nothing asks first.
@property (assign) BOOL interactive;
@property (readonly) NSTextField *nameField;
// The problem the last change ran into, in words (nil when it worked).
@property (readonly, copy, nullable) NSString *problem;

- (void)reload;
- (void)activateNamed:(NSString *)name;
- (void)createNamed:(NSString *)name copyingActive:(BOOL)copyingActive;
- (void)duplicateNamed:(NSString *)name as:(NSString *)copyName;
- (void)renameNamed:(NSString *)name to:(NSString *)newName;
- (void)deleteNamed:(NSString *)name;
- (void)addFromFileAtPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
