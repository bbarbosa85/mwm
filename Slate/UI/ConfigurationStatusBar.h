//
//  ConfigurationStatusBar.h
//  Slate
//
//  The bottom bar shared by the configuration windows:
//  {saved?} {filename} ... {valid?} ... {Apply} {Close}
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

@interface ConfigurationStatusBar : NSView

// The target receives showIssues:, apply: and closeWindow: from the bar's controls.
- (instancetype)initWithTarget:(id)target path:(NSString *)path;

- (void)setSavedText:(NSString *)text symbol:(NSString *)symbol color:(NSColor *)color;
- (void)setStatusText:(NSString *)text symbol:(NSString *)symbol color:(NSColor *)color tip:(nullable NSString *)tip;

// The validity status, for positioning the issue list under it.
@property (readonly) NSButton *statusButton;

+ (NSImage *)symbol:(NSString *)name color:(NSColor *)color;

@end

NS_ASSUME_NONNULL_END
