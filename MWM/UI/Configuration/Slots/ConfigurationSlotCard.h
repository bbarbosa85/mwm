//
//  ConfigurationSlotCard.h
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
#import "ConfigurationBlockView.h"

NS_ASSUME_NONNULL_BEGIN

// A card in the gallery, picture first: a screen with the slot drawn on it, a size badge,
// a quiet ✕ to remove it, and under it the name and how many shortcuts use it. Clicking
// opens it. The New Slot card has a dashed edge.
@interface ConfigurationSlotCard : ConfigurationBlockView
@property (copy, nullable) void (^onOpen)(void);
@property (copy, nullable) void (^onRemove)(void);
@property (assign) BOOL isNewCard;
- (instancetype)initWithName:(NSString *)name badge:(NSString *)badge usage:(NSString *)usage rect:(CGRect)rect valid:(BOOL)valid;
- (instancetype)initNewCard;
@end

NS_ASSUME_NONNULL_END
