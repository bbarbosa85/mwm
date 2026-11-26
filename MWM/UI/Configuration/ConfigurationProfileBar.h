//
//  ConfigurationProfileBar.h
//
//  The row across the top of the Settings window: which profile the pages below edit, a dropdown to choose
//  another and to manage them, and a "not applied" mark while the profile being edited isn't the running one.
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

@class ConfigurationProfileBar;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationProfileBarDelegate <NSObject>
// Edit this profile (it becomes the running one when Apply and Restart is pressed).
- (void)profileBar:(ConfigurationProfileBar *)bar didChooseProfileNamed:(NSString *)name;
// Open the Profiles page.
- (void)profileBarWantsManage:(ConfigurationProfileBar *)bar;
@end

@interface ConfigurationProfileBar : NSView

@property (weak, nullable) id<ConfigurationProfileBarDelegate> delegate;
// The profile being edited, and the one MWM is running; "not applied" shows when they differ.
- (void)setEditing:(NSString *)editing running:(NSString *)running;
@property (readonly) BOOL pending;
// The dropdown's menu, built from the profiles on disk (also for tests).
- (NSMenu *)profileMenu;

@end

NS_ASSUME_NONNULL_END
