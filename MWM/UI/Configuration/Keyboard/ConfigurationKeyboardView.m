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
#import "ConfigurationShortcutEditorView.h"
#import "MWMConfigDocument.h"
#import "MWMShortcutIndex.h"

@interface ConfigurationKeyboardView () <ConfigurationShortcutListViewDelegate, ConfigurationKeyboardMapViewDelegate, ConfigurationShortcutEditorViewDelegate>
@property (strong) ConfigurationShortcutListView *listView;
@property (strong) ConfigurationKeyboardMapView *mapView;
@property (strong, readwrite) ConfigurationShortcutEditorView *editor;
@property (assign, readwrite) BOOL isEditing;
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
    _editor = [[ConfigurationShortcutEditorView alloc] init];
    [_editor setDelegate:self];
    [self pinView:_editor];
    [_editor setHidden:YES];
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

- (MWMShortcutIndex *)index {
  return self.document == nil ? nil : [MWMShortcutIndex indexForDocument:self.document];
}

- (NSUInteger)conflictCount {
  return [self.index conflictCount];
}

- (void)setDocument:(MWMConfigDocument *)document {
  _document = document;
  self.listView.document = document;
  self.mapView.document = document;
  self.editor.document = document;
  [self closeEditor];
  [self showMode];
}

- (void)setMode:(ConfigurationKeyboardMode)mode {
  _mode = mode;
  [self showMode];
}

- (void)showMode {
  [self.listView setHidden:self.isEditing || self.mode != ConfigurationKeyboardModeList];
  [self.mapView setHidden:self.isEditing || self.mode != ConfigurationKeyboardModeMap];
  [self.editor setHidden:!self.isEditing];
}

- (void)setEditing:(BOOL)editing {
  if (self.isEditing == editing) return;
  self.isEditing = editing;
  [self showMode];
  if ([self.delegate respondsToSelector:@selector(keyboardView:didChangeEditing:)]) [self.delegate keyboardView:self didChangeEditing:editing];
}

- (void)closeEditor { [self setEditing:NO]; }

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
  [self.editor editBindingAtIndex:index];
  [self setEditing:YES];
}

- (void)startNewShortcut {
  [self startNewShortcutInGroup:nil keyName:nil];
}

- (void)startNewShortcutInGroup:(NSString *)groupName keyName:(NSString *)keyName {
  [self.editor startNewWithGroup:groupName keyName:keyName];
  [self setEditing:YES];
}

#pragma mark - Editor

- (void)shortcutEditorViewDidSave:(ConfigurationShortcutEditorView *)view {
  [self.listView reload];
  [self.mapView reload];
  [self.delegate keyboardViewDidChangeDocument:self];
}

- (void)shortcutEditorViewDidClose:(ConfigurationShortcutEditorView *)view {
  [self setEditing:NO];
}

- (void)shortcutEditorViewWantsSlots:(ConfigurationShortcutEditorView *)view {
  if ([self.delegate respondsToSelector:@selector(keyboardViewWantsSlots:)]) [self.delegate keyboardViewWantsSlots:self];
}

- (void)shortcutEditorViewWantsDisplays:(ConfigurationShortcutEditorView *)view {
  if ([self.delegate respondsToSelector:@selector(keyboardViewWantsDisplays:)]) [self.delegate keyboardViewWantsDisplays:self];
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
  [self startNewShortcutInGroup:groupName keyName:keyName];
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
