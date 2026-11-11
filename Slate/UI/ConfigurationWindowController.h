//
//  ConfigurationWindowController.h
//  Slate
//
//  The "Configure Slate…" window: edits ~/.slate.js as code, validates it
//  without applying it, and saves and relaunches to apply it.
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

NS_ASSUME_NONNULL_BEGIN

@interface ConfigurationWindowController : NSWindowController <NSWindowDelegate, NSTextViewDelegate, NSTextStorageDelegate>

+ (instancetype)sharedController;

// Brings the window to the front, reloading ~/.slate.js unless there are unsaved edits.
- (void)showConfiguration;

// Reopens the window, at the same place in the file, when Save just relaunched Slate.
+ (void)reopenAfterRelaunchIfNeeded;

// The text being edited, for tests.
@property (readonly) NSTextView *textView;

@end

NS_ASSUME_NONNULL_END
