//
//  AsyncWasmEngine+Additions.h
//  WasmHost
//
//  Created by L7Studio on 12/2/25.
//

#import <Foundation/Foundation.h>
@import AsyncWasm;
NS_ASSUME_NONNULL_BEGIN

@interface AsyncWasmEngine (Protobuf)
-(void)performSelector:(SEL)selector
                  args:(NSArray*)args
                 clazz:(Class)clazz
     completionHandler:(void(^)(id _Nullable, NSError *_Nullable)) completionHandler;

@end

NS_ASSUME_NONNULL_END
