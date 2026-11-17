//
//  ConfigurationShortcutListView.h
//  Slate
//
//  The Keyboard page's List view: a filter column (search, what the shortcut
//  does, which modifier group, conflicts) and the shortcuts as rows, grouped by
//  what they do, each with an on/off switch. Clicking a row opens it.
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

@class ConfigurationShortcutListView, SlateConfigDocument, SlateShortcutIndex;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationShortcutListViewDelegate <NSObject>
// A shortcut was switched on or off; save the document.
- (void)shortcutListViewDidChangeDocument:(ConfigurationShortcutListView *)view;
// The user clicked a row (a binding by index in the document).
- (void)shortcutListView:(ConfigurationShortcutListView *)view wantsToOpenBindingAtIndex:(NSUInteger)index;
- (void)shortcutListViewWantsNewShortcut:(ConfigurationShortcutListView *)view;
@end

@interface ConfigurationShortcutListView : NSView

@property (weak, nullable) id<ConfigurationShortcutListViewDelegate> delegate;
@property (strong, nonatomic, nullable) SlateConfigDocument *document;
@property (readonly, nullable) SlateShortcutIndex *index;

// Filters (nil / NO shows everything). Setting one rebuilds the list.
@property (copy, nonatomic, nullable) NSString *groupFilter;
@property (strong, nonatomic, nullable) NSNumber *kindFilter;   // a SlateShortcutKind
@property (assign, nonatomic) BOOL conflictsOnly;
@property (copy, nonatomic) NSString *query;

- (void)reload;

@end

NS_ASSUME_NONNULL_END
