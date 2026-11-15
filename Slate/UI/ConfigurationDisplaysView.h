//
//  ConfigurationDisplaysView.h
//  Slate
//
//  The Displays page: the connected screens drawn where they sit, a row for
//  each one with its name and role, dimmed rows for screens that aren't
//  connected now, and the old numeric screen references.
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

@class ConfigurationDisplaysView, SlateConfigDocument;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationDisplaysViewDelegate <NSObject>
// The monitors in the document were changed; save it.
- (void)displaysViewDidChangeDocument:(ConfigurationDisplaysView *)view;
@end

@interface ConfigurationDisplaysView : NSView

@property (weak, nullable) id<ConfigurationDisplaysViewDelegate> delegate;
@property (strong, nonatomic, nullable) SlateConfigDocument *document;

// Looks at the connected screens again and adds any the config doesn't name yet.
- (void)detectAgain;
// Rebuilds the page from the document and the connected screens.
- (void)reload;

@end

NS_ASSUME_NONNULL_END
