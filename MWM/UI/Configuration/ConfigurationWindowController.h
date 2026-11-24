//
//  ConfigurationWindowController.h
//  Slate
//
//  The "Configure MWM…" window: a form for ~/.mwm.yml. Every change is
//  validated and, when it has no errors, saved right away. Apply restarts
//  MWM to load the file.
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

#import "ConfigurationFormView.h"

@class ConfigurationFormView;

NS_ASSUME_NONNULL_BEGIN

@interface ConfigurationWindowController : NSWindowController <NSWindowDelegate>

+ (instancetype)sharedController;

// Brings the window to the front, loading ~/.mwm.yml if it wasn't open.
- (void)showConfiguration;

// The same, on a page of the sidebar (the menu bar opens these).
- (void)showConfigurationSection:(ConfigurationFormSection)section;
// Put this text in the configuration file (the old file is kept as a copy) and show it. NO if it couldn't be written.
- (BOOL)restoreConfigText:(NSString *)text;
// The Keyboard page as a list, or with the editor open for a new shortcut.
- (void)showKeyboardList;
- (void)showNewShortcut;

// The form, for tests.
@property (readonly) ConfigurationFormView *formView;

@end

NS_ASSUME_NONNULL_END
