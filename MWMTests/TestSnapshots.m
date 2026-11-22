//
//  TestSnapshots.m
//
//  Renders the design gallery and key pages to images, in light and dark, and compares
//  them with the saved ones in MWMTests/Snapshots. A missing image is written (and the
//  test passes, with a note); set TEST_RUNNER_MWM_RECORD_SNAPSHOTS=1 to rewrite them all
//  after a design change you meant to make. A failing run leaves what it drew in
//  NSTemporaryDirectory()/MWMSnapshots as <name>.actual.png.
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

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "ConfigurationDisplaysView.h"
#import "ConfigurationKeyboardMapView.h"
#import "ConfigurationPresetsView.h"
#import "ConfigurationSettingsView.h"
#import "MWMAboutWindow.h"
#import "NSAlert+MWM.h"
#import "ConfigurationSnapshotsView.h"
#import "MWMSnapshots.h"
#import "Snapshot.h"
#import "SnapshotList.h"
#import "WindowSnapshot.h"
#import "ConfigurationShortcutListView.h"
#import "ConfigurationSlotsView.h"
#import "ConfigurationModifiersView.h"
#import "ConfigurationShortcutEditorView.h"
#import "MWMDesignGallery.h"
#import "MWMConfigDocument.h"

static NSString *const kConfig =
  @"modifiers:\n  hyper: ctrl;alt;cmd\n  shyper: shift;ctrl;alt;cmd\n"
  @"positions:\n  half: move screenOriginX;screenOriginY screenSizeX/2;screenSizeY\n"
  @"bindings:\n"
  @"  - key: pad8\n    mods: ${hyper}\n    action: ${half}\n"
  @"  - key: pad9\n    mods: ${hyper}\n    action: ${half}\n"
  @"  - key: c\n    mods: ${hyper}\n    action: focus 'Google Chrome'\n"
  @"  - key: h\n    mods: ${hyper}\n    action: hint ASDF\n"
  @"  - key: pad8\n    mods: ctrl;alt;cmd\n    action: relaunch\n";

@interface TestSnapshots : XCTestCase
@end

@implementation TestSnapshots

- (NSString *)snapshotDirectory {
  return [[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Snapshots"];
}

// Draws the view at its size in a window using the given appearance.
- (NSBitmapImageRep *)renderView:(NSView *)view size:(NSSize)size dark:(BOOL)dark {
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, size.width, size.height) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
  [window setAppearance:[NSAppearance appearanceNamed:dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua]];
  // The window's background, drawn by the view so it follows the appearance.
  NSBox *backdrop = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
  [backdrop setBoxType:NSBoxCustom];
  [backdrop setBorderWidth:0];
  [backdrop setContentViewMargins:NSZeroSize];
  [backdrop setFillColor:[NSColor windowBackgroundColor]];
  [view setFrame:[backdrop bounds]];
  [view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [[backdrop contentView] addSubview:view];
  [window setContentView:backdrop];
  [window layoutIfNeeded];
  [view layoutSubtreeIfNeeded];
  __block NSBitmapImageRep *rep;
  [[window effectiveAppearance] performAsCurrentDrawingAppearance:^{
    NSBitmapImageRep *bitmap = [backdrop bitmapImageRepForCachingDisplayInRect:[backdrop bounds]];
    [backdrop cacheDisplayInRect:[backdrop bounds] toBitmapImageRep:bitmap];
    rep = bitmap;
  }];
  objc_setAssociatedObject(rep, "window", window, OBJC_ASSOCIATION_RETAIN);
  return rep;
}

// How far two images are apart: the average difference per color channel, 0 to 255.
- (double)differenceBetween:(NSBitmapImageRep *)a and:(NSBitmapImageRep *)b {
  if ([a pixelsWide] != [b pixelsWide] || [a pixelsHigh] != [b pixelsHigh]) return 255;
  double total = 0;
  NSInteger count = 0;
  for (NSInteger y = 0; y < [a pixelsHigh]; y += 2) {
    for (NSInteger x = 0; x < [a pixelsWide]; x += 2) {
      NSColor *ca = [[a colorAtX:x y:y] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
      NSColor *cb = [[b colorAtX:x y:y] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
      total += fabs(ca.redComponent - cb.redComponent) + fabs(ca.greenComponent - cb.greenComponent) + fabs(ca.blueComponent - cb.blueComponent);
      count += 3;
    }
  }
  return count == 0 ? 0 : total / count * 255;
}

- (void)checkView:(NSView *)view size:(NSSize)size name:(NSString *)name dark:(BOOL)dark {
  NSString *full = [NSString stringWithFormat:@"%@-%@", name, dark ? @"dark" : @"light"];
  // script/screens with a word draws only the screens whose name has it.
  NSString *only = [[NSProcessInfo processInfo] environment][@"MWM_SCREENS_FILTER"];
  if ([only length] > 0 && [name rangeOfString:only].location == NSNotFound) return;
  NSBitmapImageRep *actual = [self renderView:view size:size dark:dark];
  NSData *png = [actual representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
  // script/screens asks for every screen as an image to look at, not to compare.
  NSString *screens = [[NSProcessInfo processInfo] environment][@"MWM_SCREENS_DIR"];
  if ([screens length] > 0) {
    [[NSFileManager defaultManager] createDirectoryAtPath:screens withIntermediateDirectories:YES attributes:nil error:nil];
    [png writeToFile:[screens stringByAppendingPathComponent:[full stringByAppendingString:@".png"]] atomically:YES];
    return;
  }
  NSString *path = [[self snapshotDirectory] stringByAppendingPathComponent:[full stringByAppendingString:@".png"]];
  BOOL record = [[[NSProcessInfo processInfo] environment][@"MWM_RECORD_SNAPSHOTS"] length] > 0;
  NSData *saved = [NSData dataWithContentsOfFile:path];
  if (saved == nil || record) {
    [[NSFileManager defaultManager] createDirectoryAtPath:[self snapshotDirectory] withIntermediateDirectories:YES attributes:nil error:nil];
    [png writeToFile:path atomically:YES];
    NSLog(@"SNAPSHOT recorded %@", path);
    return;
  }
  double difference = [self differenceBetween:actual and:[NSBitmapImageRep imageRepWithData:saved]];
  if (difference > 1.5) {
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MWMSnapshots"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *out = [folder stringByAppendingPathComponent:[full stringByAppendingString:@".actual.png"]];
    [png writeToFile:out atomically:YES];
    XCTFail(@"%@ differs from its saved image by %.2f (limit 1.5). What was drawn: %@", full, difference, out);
  }
}

- (void)testTheDesignGalleryLooksTheSameInLightAndDark {
  for (NSNumber *dark in @[@NO, @YES]) {
    NSView *gallery = [MWMDesignGallery galleryViewWithWidth:760];
    [self checkView:gallery size:gallery.frame.size name:@"gallery" dark:[dark boolValue]];
  }
}

- (void)testTheKeyboardMapLooksTheSame {
  for (NSNumber *dark in @[@NO, @YES]) {
    MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
    ConfigurationKeyboardMapView *map = [[ConfigurationKeyboardMapView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    map.document = doc;
    [map selectKeyNamed:@"pad8"];
    [self checkView:map size:NSMakeSize(1000, 640) name:@"keyboard-map" dark:[dark boolValue]];
  }
}

- (void)testTheShortcutEditorLooksTheSame {
  for (NSNumber *dark in @[@NO, @YES]) {
    MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
    ConfigurationShortcutEditorView *editor = [[ConfigurationShortcutEditorView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    editor.document = doc;
    [editor editBindingAtIndex:0];
    [self checkView:editor size:NSMakeSize(1000, 640) name:@"shortcut-editor" dark:[dark boolValue]];
  }
}


- (void)testTheShortcutListLooksTheSame {
  for (NSNumber *dark in @[@NO, @YES]) {
    MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
    ConfigurationShortcutListView *list = [[ConfigurationShortcutListView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 520)];
    list.document = doc;
    [self checkView:list size:NSMakeSize(1000, 520) name:@"shortcut-list" dark:[dark boolValue]];
  }
}

- (void)testTheModifiersPageAndEditorLookTheSame {
  for (NSNumber *dark in @[@NO, @YES]) {
    MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
    ConfigurationModifiersView *page = [[ConfigurationModifiersView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    page.document = doc;
    [self checkView:page size:NSMakeSize(1000, 640) name:@"modifiers-page" dark:[dark boolValue]];
    ConfigurationModifiersView *editor = [[ConfigurationModifiersView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    editor.document = doc;
    [editor editGroupNamed:@"hyper"];
    [editor toggleModifier:@"cmd"];
    [self checkView:editor size:NSMakeSize(1000, 640) name:@"modifiers-editor" dark:[dark boolValue]];
    // Taking ⌘ out of hyper makes Chrome's shortcut share its keys with another one.
    MWMConfigDocument *clash = [MWMConfigDocument documentFromString:[kConfig stringByAppendingString:@"  - key: c\n    mods: ctrl;alt\n    action: undo\n"] error:nil];
    ConfigurationModifiersView *warning = [[ConfigurationModifiersView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    warning.document = clash;
    [warning editGroupNamed:@"hyper"];
    [warning toggleModifier:@"cmd"];
    [self checkView:warning size:NSMakeSize(1000, 640) name:@"modifiers-editor-warning" dark:[dark boolValue]];
  }
}

- (void)testTheFormulaSlotEditorsLookTheSame {
  NSString *config = @"positions:\n  rightfourfifths: move (screenOriginX+screenSizeX/5)+14;screenOriginY (4*screenSizeX/5)-14;screenSizeY\n  floating: move windowTopLeftX;windowTopLeftY screenSizeX/3;screenSizeY/2\n";
  for (NSNumber *dark in @[@NO, @YES]) {
    MWMConfigDocument *doc = [MWMConfigDocument documentFromString:config error:nil];
    ConfigurationSlotsView *margins = [[ConfigurationSlotsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    margins.document = doc;
    [margins selectSlotNamed:@"rightfourfifths"];
    [self checkView:margins size:NSMakeSize(1000, 640) name:@"slots-editor-margins" dark:[dark boolValue]];
    ConfigurationSlotsView *custom = [[ConfigurationSlotsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    custom.document = doc;
    [custom selectSlotNamed:@"floating"];
    [self checkView:custom size:NSMakeSize(1000, 640) name:@"slots-editor-custom" dark:[dark boolValue]];
    ConfigurationSlotsView *gallery = [[ConfigurationSlotsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    gallery.document = doc;
    [self checkView:gallery size:NSMakeSize(1000, 640) name:@"slots-gallery-formulas" dark:[dark boolValue]];
  }
}

- (void)testTheSlotsEditorLooksTheSame {
  for (NSNumber *dark in @[@NO, @YES]) {
    MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
    ConfigurationSlotsView *slots = [[ConfigurationSlotsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    slots.document = doc;
    [slots selectSlotNamed:@"half"];
    [self checkView:slots size:NSMakeSize(1000, 640) name:@"slots-editor" dark:[dark boolValue]];
  }
}

- (void)testTheSettingsPagesLookTheSame {
  for (NSNumber *dark in @[@NO, @YES]) {
    MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];
    ConfigurationSettingsView *settings = [[ConfigurationSettingsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    settings.page = ConfigurationSettingsPageGeneral;
    settings.document = doc;
    [self checkView:settings size:NSMakeSize(1000, 640) name:@"settings-general" dark:[dark boolValue]];
  }
}


// More screens, drawn only for script/screens: they show this Mac's own displays or other states,
// so they are for looking at, not for comparing.
- (void)testMoreScreensForTheScreensScript {
  if ([[[NSProcessInfo processInfo] environment][@"MWM_SCREENS_DIR"] length] == 0) return;
  for (NSNumber *dark in @[@NO, @YES]) {
    BOOL d = [dark boolValue];
    MWMConfigDocument *doc = [MWMConfigDocument documentFromString:kConfig error:nil];

    ConfigurationDisplaysView *displays = [[ConfigurationDisplaysView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    displays.document = doc;
    [self checkView:displays size:NSMakeSize(1000, 640) name:@"displays" dark:d];

    ConfigurationPresetsView *presets = [[ConfigurationPresetsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    [self checkView:presets size:NSMakeSize(1000, 640) name:@"slot-presets" dark:d];

    ConfigurationSettingsView *advanced = [[ConfigurationSettingsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    advanced.page = ConfigurationSettingsPageAdvanced;
    advanced.document = doc;
    [self checkView:advanced size:NSMakeSize(1000, 640) name:@"settings-advanced" dark:d];

    ConfigurationKeyboardMapView *custom = [[ConfigurationKeyboardMapView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    custom.document = doc;
    custom.groupName = @"shyper";
    [self checkView:custom size:NSMakeSize(1000, 640) name:@"keyboard-map-empty-group" dark:d];

    NSMutableDictionary *lists = [NSMutableDictionary dictionary];
    NSArray *desk = @[@{@"name": @"Built-in", @"width": @1512, @"height": @982, @"x": @0, @"y": @0, @"builtIn": @YES},
                      @{@"name": @"Samsung Odyssey", @"width": @2560, @"height": @1440, @"x": @1512, @"y": @0, @"builtIn": @NO}];
    NSArray *laptop = @[desk[0]];
    void (^add)(NSString *, BOOL, NSArray *, NSArray *) = ^(NSString *name, BOOL keep, NSArray *screens, NSArray *windows) {
      Snapshot *snapshot = [[Snapshot alloc] init];
      for (NSArray *w in windows) [snapshot addWindow:[[WindowSnapshot alloc] initWithAppName:w[0] title:@"w" topLeft:NSMakePoint([w[1] doubleValue], [w[2] doubleValue]) size:NSMakeSize([w[3] doubleValue], [w[4] doubleValue])] app:w[0]];
      snapshot.screens = screens;
      SnapshotList *list = [[SnapshotList alloc] initWithName:name saveToDisk:keep isStack:NO];
      [list addSnapshot:snapshot];
      lists[name] = list;
    };
    add(@"work", YES, desk, @[@[@"Google Chrome", @1512, @0, @1280, @1440], @[@"Warp", @2792, @0, @1280, @720], @[@"Spotify", @2792, @720, @1280, @720], @[@"Notes", @40, @60, @900, @700]]);
    add(@"couch", NO, laptop, @[@[@"Safari", @0, @0, @1512, @982]]);
    add(@"focus", YES, laptop, @[@[@"Finder", @0, @0, @756, @982], @[@"Notes", @756, @0, @756, @982]]);
    add(@"meeting", YES, desk, @[@[@"Notes", @0, @0, @1512, @982], @[@"Safari", @1512, @0, @1536, @1440], @[@"Finder", @3048, @0, @1024, @1440]]);
    add(@"review", NO, laptop, @[@[@"Safari", @0, @0, @900, @982], @[@"Notes", @900, @0, @612, @491], @[@"Finder", @900, @491, @612, @491]]);
    [MWMSnapshots setListsOverride:lists];
    NSMutableDictionary *liveLists = [NSMutableDictionary dictionary];
    liveLists[@"live"] = lists[@"work"];
    [MWMSnapshots setCurrentWindowsOverride:[[MWMSnapshots infosForLists:liveLists connected:@[]] firstObject]];
    ConfigurationSnapshotsView *snapshots = [[ConfigurationSnapshotsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 880)];
    [self checkView:snapshots size:NSMakeSize(1000, 880) name:@"snapshots" dark:d];
    [MWMSnapshots setListsOverride:[NSMutableDictionary dictionary]];
    ConfigurationSnapshotsView *noSnapshots = [[ConfigurationSnapshotsView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 420)];
    [self checkView:noSnapshots size:NSMakeSize(1000, 420) name:@"snapshots-empty" dark:d];
    [MWMSnapshots setCurrentWindowsOverride:nil];
    [MWMSnapshots setListsOverride:nil];

    NSView *about = [MWMAboutWindow contentView];
    [self checkView:about size:about.frame.size name:@"about" dark:d];

    NSAlert *alert = [NSAlert mwm_alert];
    [alert setMessageText:@"Your configuration was updated"];
    [alert setInformativeText:@"~/.mwm.yml now uses the new format: one entry per monitor and slot, and actions written out as fields. Nothing changes in how your shortcuts work. The old file is kept as ~/.mwm.yml.v1-20261118-125904."];
    [alert addButtonWithTitle:@"OK"];
    [alert layout];
    NSWindow *alertWindow = [alert window];
    [alertWindow setAppearance:[NSAppearance appearanceNamed:d ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua]];
    NSView *alertContent = [alertWindow contentView];
    [alertContent layoutSubtreeIfNeeded];
    NSString *screens = [[NSProcessInfo processInfo] environment][@"MWM_SCREENS_DIR"];
    [[alertWindow effectiveAppearance] performAsCurrentDrawingAppearance:^{
      NSBitmapImageRep *rep = [alertContent bitmapImageRepForCachingDisplayInRect:[alertContent bounds]];
      [alertContent cacheDisplayInRect:[alertContent bounds] toBitmapImageRep:rep];
      [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[screens stringByAppendingPathComponent:[NSString stringWithFormat:@"alert-%@.png", d ? @"dark" : @"light"]] atomically:YES];
    }];

    ConfigurationShortcutEditorView *newShortcut = [[ConfigurationShortcutEditorView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    newShortcut.document = doc;
    [newShortcut startNewWithGroup:@"hyper" keyName:@"j"];
    [self checkView:newShortcut size:NSMakeSize(1000, 640) name:@"shortcut-editor-new" dark:d];

    ConfigurationShortcutEditorView *picking = [[ConfigurationShortcutEditorView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    picking.document = doc;
    [picking editBindingAtIndex:0];
    [picking performSelector:NSSelectorFromString(@"pickPressed:") withObject:nil];
    [self checkView:picking size:NSMakeSize(1000, 640) name:@"shortcut-editor-pick-keys" dark:d];
  }
}

@end
