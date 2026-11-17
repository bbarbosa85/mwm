//
//  TestSnapshots.m
//
//  Renders the design gallery and key pages to images, in light and dark, and compares
//  them with the saved ones in SlateTests/Snapshots. A missing image is written (and the
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
#import "ConfigurationKeyboardMapView.h"
#import "ConfigurationShortcutEditorView.h"
#import "MWMDesignGallery.h"
#import "SlateConfigDocument.h"

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
  NSBitmapImageRep *actual = [self renderView:view size:size dark:dark];
  NSData *png = [actual representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
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
    SlateConfigDocument *doc = [SlateConfigDocument documentFromString:kConfig error:nil];
    ConfigurationKeyboardMapView *map = [[ConfigurationKeyboardMapView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    map.document = doc;
    [map selectKeyNamed:@"pad8"];
    [self checkView:map size:NSMakeSize(1000, 640) name:@"keyboard-map" dark:[dark boolValue]];
  }
}

- (void)testTheShortcutEditorLooksTheSame {
  for (NSNumber *dark in @[@NO, @YES]) {
    SlateConfigDocument *doc = [SlateConfigDocument documentFromString:kConfig error:nil];
    ConfigurationShortcutEditorView *editor = [[ConfigurationShortcutEditorView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 640)];
    editor.document = doc;
    [editor editBindingAtIndex:0];
    [self checkView:editor size:NSMakeSize(1000, 640) name:@"shortcut-editor" dark:[dark boolValue]];
  }
}

@end
