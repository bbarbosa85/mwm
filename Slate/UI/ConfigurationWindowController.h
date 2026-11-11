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

@class ConfigurationFormView;

NS_ASSUME_NONNULL_BEGIN

@interface ConfigurationWindowController : NSWindowController <NSWindowDelegate>

+ (instancetype)sharedController;

// Brings the window to the front, loading ~/.mwm.yml if it wasn't open.
- (void)showConfiguration;

// The form, for tests.
@property (readonly) ConfigurationFormView *formView;

@end

NS_ASSUME_NONNULL_END
