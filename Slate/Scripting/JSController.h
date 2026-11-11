//
//  JSController.h
//  Slate
//
//  Created by Alex Morega on 2013-01-16.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "Operation.h"

@class JSWindowWrapper;
@class JSApplicationWrapper;
@class JSScreenWrapper;
@class JSOperationWrapper;

@protocol JSControllerExport <JSExport>
- (void)log:(id)msg;
JSExportAs(bindFunction,
- (void)bindFunction:(NSString *)hotkey callback:(JSValue *)callback repeat:(id)_repeat
);
JSExportAs(bindNative,
- (void)bindNative:(NSString *)hotkey callback:(JSOperationWrapper *)opWrapper repeat:(id)_repeat
);
JSExportAs(bindString,
- (void)bindString:(NSString *)hotkey operation:(NSString *)opString repeat:(id)_repeat
);
JSExportAs(configFunction,
- (void)configFunction:(NSString *)key callback:(JSValue *)callback
);
JSExportAs(configNative,
- (void)configNative:(NSString *)key callback:(id)callback
);
JSExportAs(doOperation,
- (BOOL)doOperation:(NSString *)op options:(id)opts
);
JSExportAs(operation,
- (JSOperationWrapper *)operation:(NSString *)name options:(id)opts
);
- (JSOperationWrapper *)operationFromString:(NSString *)opString;
- (BOOL)source:(NSString *)path;
JSExportAs(layout,
- (NSString *)layout:(NSString *)name hash:(id)hash
);
JSExportAs(default,
- (void)defaultAction:(id)config toAction:(id)_action
);
JSExportAs(shell,
- (NSString *)shell:(NSString *)commandAndArgs wait:(id)wait path:(id)path
);
JSExportAs(on,
- (void)on:(NSString *)what do:(JSValue *)callback
);
@end

@interface JSController : NSObject <JSControllerExport> {
  JSContext *context;
  NSMutableDictionary *functions;
  BOOL inited;
  NSMutableDictionary *eventCallbacks;
}
@property (strong) JSContext *context;
@property (strong) NSMutableDictionary *functions;
@property (strong) NSMutableDictionary *eventCallbacks;

- (id)run:(NSString*)code;
- (BOOL)loadConfigFileWithPath:(NSString *)path;
- (void)runCallbacks:(NSString *)what payload:(id)payload;
- (NSString *)addCallableFunction:(JSValue *)function;
- (id)runCallableFunction:(NSString *)key;
- (id)runFunction:(JSValue *)function;
- (id)runFunction:(JSValue *)function withArg:(id)arg;
- (id)runFunction:(JSValue *)function withArg:(id)arg secondArg:(id)arg2;
- (id)unmarshall:(id)obj;
- (id)marshall:(id)obj;
- (NSString *)jsTypeof:(id)obj;
+ (JSController *)getInstance;

@end
