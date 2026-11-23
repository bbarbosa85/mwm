//
//  ConfigurationPushRows.h
//  Slate
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
#import "MWMPushOptions.h"

NS_ASSUME_NONNULL_BEGIN

// The rows that set up a push in the shortcut editor, after its direction: the style, the thickness of a bar with
// a set thickness (a number and a unit), the screen, and a small picture of where the window goes with the
// text it writes. Each row is {label, views, identifier}.
@interface ConfigurationPushRows : NSObject
@property (readonly) NSArray<NSDictionary *> *rows;
// onChange gets the options as they are after the user changed something.
+ (instancetype)rowsForOptions:(MWMPushOptions *)options direction:(NSString *)direction screens:(NSArray<NSString *> *)screens onChange:(void (^)(MWMPushOptions *options))onChange;
@end

NS_ASSUME_NONNULL_END
