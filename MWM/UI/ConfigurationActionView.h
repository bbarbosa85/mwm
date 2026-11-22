//
//  ConfigurationActionView.h
//  Slate
//
//  A table cell that edits an action with dropdowns instead of typing:
//  "Move to [left half ▾] on [Samsung ▾]", "Focus app [Finder ▾]", and so on.
//  "Advanced…" falls back to the plain text.
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

@class ConfigurationActionView, MWMConfigEntry;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationActionViewDelegate <NSObject>
- (void)actionView:(ConfigurationActionView *)view didChangeAction:(NSString *)action;
@end

@interface ConfigurationActionView : NSView

@property (weak, nullable) id<ConfigurationActionViewDelegate> delegate;
@property (readonly) NSString *action;

// positions and monitors are the named entries of those sections.
- (void)setAction:(NSString *)action positions:(NSArray<MWMConfigEntry *> *)positions monitors:(NSArray<MWMConfigEntry *> *)monitors;

// For tests: changes the kind (index into MWMAction allKinds) as if picked from the dropdown.
- (void)selectKindAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
