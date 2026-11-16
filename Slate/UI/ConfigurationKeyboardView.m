//
//  ConfigurationKeyboardView.m
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

#import "ConfigurationKeyboardView.h"
#import "ConfigurationShortcutListView.h"
#import "ConfigurationKeyboardMapView.h"
#import "SlateConfigDocument.h"
#import "SlateShortcutIndex.h"

@interface ConfigurationKeyboardView () <ConfigurationShortcutListViewDelegate, ConfigurationKeyboardMapViewDelegate>
@property (strong) ConfigurationShortcutListView *listView;
@property (strong) ConfigurationKeyboardMapView *mapView;
@end

@implementation ConfigurationKeyboardView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _mode = ConfigurationKeyboardModeMap;
    _listView = [[ConfigurationShortcutListView alloc] init];
    [_listView setDelegate:self];
    [self pinView:_listView];
    [_listView setHidden:YES];
    _mapView = [[ConfigurationKeyboardMapView alloc] init];
    [_mapView setDelegate:self];
    [self pinView:_mapView];
  }
  return self;
}

- (void)pinView:(NSView *)view {
  [view setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self addSubview:view];
  [NSLayoutConstraint activateConstraints:@[
    [view.topAnchor constraintEqualToAnchor:self.topAnchor], [view.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    [view.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [view.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
  ]];
}

- (SlateShortcutIndex *)index {
  return self.document == nil ? nil : [SlateShortcutIndex indexForDocument:self.document];
}

- (NSUInteger)conflictCount {
  return [self.index conflictCount];
}

- (void)setDocument:(SlateConfigDocument *)document {
  _document = document;
  self.listView.document = document;
  self.mapView.document = document;
  [self showMode];
}

- (void)setMode:(ConfigurationKeyboardMode)mode {
  _mode = mode;
  [self showMode];
}

- (void)showMode {
  [self.listView setHidden:self.mode != ConfigurationKeyboardModeList];
  [self.mapView setHidden:self.mode != ConfigurationKeyboardModeMap];
}

- (void)reload {
  [self.listView reload];
  [self.mapView reload];
}

- (void)showConflicts {
  self.mode = ConfigurationKeyboardModeList;
  self.listView.groupFilter = nil;
  self.listView.kindFilter = nil;
  self.listView.conflictsOnly = YES;
}

- (void)openBindingAtIndex:(NSUInteger)index {
}

- (void)startNewShortcut {
}

#pragma mark - List view

- (void)shortcutListViewDidChangeDocument:(ConfigurationShortcutListView *)view {
  [self.mapView reload];
  [self.delegate keyboardViewDidChangeDocument:self];
}

#pragma mark - Map view

- (void)keyboardMapViewDidChangeDocument:(ConfigurationKeyboardMapView *)view {
  [self.listView reload];
  [self.delegate keyboardViewDidChangeDocument:self];
}

- (void)keyboardMapView:(ConfigurationKeyboardMapView *)view wantsToEditBindingAtIndex:(NSUInteger)index {
  [self openBindingAtIndex:index];
}

- (void)keyboardMapView:(ConfigurationKeyboardMapView *)view wantsNewShortcutInGroup:(NSString *)groupName keyName:(NSString *)keyName {
  [self startNewShortcut];
}

- (void)keyboardMapViewWantsGroups:(ConfigurationKeyboardMapView *)view {
  if ([self.delegate respondsToSelector:@selector(keyboardViewWantsGroups:)]) [self.delegate keyboardViewWantsGroups:self];
}

- (void)shortcutListView:(ConfigurationShortcutListView *)view wantsToOpenBindingAtIndex:(NSUInteger)index {
  [self openBindingAtIndex:index];
}

- (void)shortcutListViewWantsNewShortcut:(ConfigurationShortcutListView *)view {
  [self startNewShortcut];
}

@end
