//
//  ConfigurationProfileBar.m
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

#import "ConfigurationProfileBar.h"
#import "MWMComponents.h"
#import "MWMProfiles.h"
#import "MWMTheme.h"

static NSString *const kProfileSymbol = @"square.stack.3d.up";

@interface ConfigurationProfileBar ()
@property (copy) NSString *editing;
@property (copy) NSString *running;
@property (strong) NSButton *button;
@property (strong) MWMChipView *pendingChip;
@property (strong) NSView *content;
@end

@implementation ConfigurationProfileBar

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self setIdentifier:@"profile-bar"];
    self.button = [NSButton buttonWithTitle:@"" target:self action:@selector(openMenu:)];
    [self.button setBezelStyle:NSBezelStyleRounded];
    [self.button setImage:[NSImage imageWithSystemSymbolName:kProfileSymbol accessibilityDescription:nil]];
    [self.button setImagePosition:NSImageLeading];
    [self.button setFont:[MWMTheme fontBodyStrong]];
    [self.button setIdentifier:@"profile-bar-button"];
    [self.button setToolTip:@"Choose the profile to edit, or manage them"];
    self.pendingChip = [MWMChipView chipWithText:@"not applied" color:[MWMTheme warning]];
    [self.pendingChip setIdentifier:@"profile-bar-pending"];
    [self.pendingChip setToolTip:@"MWM switches to this profile when you press Apply and Restart"];
    NSStackView *row = [NSStackView stackViewWithViews:@[self.button, self.pendingChip]];
    [row setSpacing:MWMSpacingM];
    [row setAlignment:NSLayoutAttributeCenterY];
    [row setTranslatesAutoresizingMaskIntoConstraints:NO];
    self.content = row;
    [self addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
      [row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [row.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [self.heightAnchor constraintEqualToConstant:28],
    ]];
  }
  return self;
}

- (BOOL)pending { return self.editing != nil && self.running != nil && [self.editing caseInsensitiveCompare:self.running] != NSOrderedSame; }

- (void)setEditing:(NSString *)editing running:(NSString *)running {
  self.editing = editing;
  self.running = running;
  [self.button setTitle:editing ?: @""];
  [self.pendingChip setHidden:!self.pending];
}

#pragma mark - The dropdown

- (NSMenu *)profileMenu {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Profiles"];
  for (NSString *name in [MWMProfiles names]) {
    NSMenuItem *item = [menu addItemWithTitle:name action:@selector(profileChosen:) keyEquivalent:@""];
    [item setTarget:self];
    [item setRepresentedObject:name];
    BOOL isEditing = [name caseInsensitiveCompare:self.editing ?: @""] == NSOrderedSame;
    BOOL isRunning = [name caseInsensitiveCompare:self.running ?: @""] == NSOrderedSame;
    [item setState:isEditing ? NSControlStateValueOn : NSControlStateValueOff];
    if (isRunning) {
      NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:name attributes:@{NSFontAttributeName: [NSFont menuFontOfSize:0]}];
      [title appendAttributedString:[[NSAttributedString alloc] initWithString:@"   running" attributes:@{NSFontAttributeName: [NSFont menuFontOfSize:11], NSForegroundColorAttributeName: [NSColor secondaryLabelColor]}]];
      [item setAttributedTitle:title];
    }
  }
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem *manage = [menu addItemWithTitle:@"Manage profiles…" action:@selector(manageChosen:) keyEquivalent:@""];
  [manage setTarget:self];
  [manage setImage:[NSImage imageWithSystemSymbolName:kProfileSymbol accessibilityDescription:nil]];
  return menu;
}

- (void)openMenu:(NSButton *)sender {
  [[self profileMenu] popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, -4) inView:sender];   // opens upward when there is no room below
}

- (void)profileChosen:(NSMenuItem *)item { [self.delegate profileBar:self didChooseProfileNamed:item.representedObject]; }
- (void)manageChosen:(id)sender { [self.delegate profileBarWantsManage:self]; }

@end
