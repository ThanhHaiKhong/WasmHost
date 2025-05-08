//
//  MusicWasmObjCTests.m
//  WasmHost
//
//  Created by L7Studio on 12/2/25.
//

#import "MusicWasmObjCTests.h"
@import AsyncWasmObjC;
@import WasmObjCProtobuf;
@import MusicWasm;
@implementation MusicWasmObjCTests {
    AsyncWasmEngine *_sut;
}
- (void)setUp {
    [super setUp];
    NSURL *file = [SWIFTPM_MODULE_BUNDLE URLForResource:@"music_tube" withExtension:@"wasm"];
    NSError * error = nil;
    self->_sut = [[MusicWasmEngine alloc] initWithFile:file error:&error];

}

-(void)waitForEngineStarted {
    XCTestExpectation *exp = [self expectationWithDescription:@"success start"];
    [self->_sut startWithCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:60];
}

-(void)testSearch {
    [self waitForEngineStarted];
    XCTestExpectation *exp = [self expectationWithDescription:@"search with keyword"];
  
    NSArray *args = [NSArray arrayWithObjects:@"i known", @"all", @"", nil];
    [self->_sut performSelector:@selector(searchWithKeyword:scope:continuation:completionHandler:)
                           args:args
                          clazz:WAMusicListTracks.class
              completionHandler:^(WAMusicListTracks* _Nullable ret, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(ret);
        XCTAssertNotEqual(ret.itemsArray.count, 0);
        NSLog(@"found %lu results", (unsigned long)ret.itemsArray_Count);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:60 handler:^(NSError *error) {
        
    }];
}

-(void)testSuggestion {
    [self waitForEngineStarted];
    XCTestExpectation *exp = [self expectationWithDescription:@"suggestion with query"];
    NSArray *args = [NSArray arrayWithObjects:@"i known", nil];
    [self->_sut performSelector:@selector(suggestionWithKeyword:completionHandler:)
                           args:args
                          clazz:WAMusicListSuggestions.class
              completionHandler:^(WAMusicListSuggestions* _Nullable ret, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(ret);
        XCTAssertNotEqual(ret.suggestionsArray.count, 0);
        NSLog(@"found %lu suggestions", (unsigned long)ret.suggestionsArray_Count);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        
    }];
}
-(void)testGetTrending {
    [self waitForEngineStarted];
    XCTestExpectation *exp = [self expectationWithDescription:@"get discover"];
    NSArray *args = [NSArray arrayWithObjects:@"a63edea2-0dea-4ff6-a473-aaaa40532d08", @"", nil];
    [self->_sut performSelector:@selector(getDiscoverWithCategory:continuation:completionHandler:)
                           args:args
                          clazz:WAMusicListTracks.class
              completionHandler:^(WAMusicListTracks* _Nullable ret, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(ret);
        XCTAssertNotEqual(ret.itemsArray.count, 0);
        NSLog(@"found %lu tracks", (unsigned long)ret.itemsArray_Count);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:60 handler:^(NSError *error) {
        
    }];
}

-(void)testGetDetails {
    [self waitForEngineStarted];
    XCTestExpectation *exp = [self expectationWithDescription:@"get details track"];
    NSArray *args = [NSArray arrayWithObjects:@"kPa7bsKwL-c", nil];
    [self->_sut performSelector:@selector(detailsWithVideoId:completionHandler:)
                           args:args
                          clazz:WAMusicTrackDetails.class
              completionHandler:^(WAMusicTrackDetails* _Nullable ret, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(ret);
        XCTAssert([ret.id_p isEqualToString:@"kPa7bsKwL-c"]);
        XCTAssertNotEqual(ret.formatsArray.count, 0);
        NSLog(@"found %lu formats", (unsigned long)ret.formatsArray_Count);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:200 handler:^(NSError *error) {
        
    }];
}
-(void)testGetMixPlaylistDetails {
    [self waitForEngineStarted];
    XCTestExpectation *exp = [self expectationWithDescription:@"get mixed playlist"];
    NSArray *args = [NSArray arrayWithObjects:@"RDEMp7_432lokhimq4eaoILwZA", @"", nil];
    [self->_sut performSelector:@selector(trackWithPlaylistId:continuation:completionHandler:)
                           args:args
                          clazz:WAMusicListTracks.class
              completionHandler:^(WAMusicListTracks* _Nullable ret, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(ret);
        XCTAssertNotEqual(ret.itemsArray.count, 0);
        NSLog(@"found %lu tracks", (unsigned long)ret.itemsArray_Count);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:200 handler:^(NSError *error) {
        
    }];
}
@end
