//
//  I18NextLoader.m
//  i18next
//
//  Created by Jean Regisser on 07/11/13.
//  Copyright (c) 2013 PrePlay, Inc. All rights reserved.
//

#import "I18NextLoader.h"
#import "I18NextConnection.h"
#import "NSString+I18Next.h"

@interface I18NextLoader ()

@property (nonatomic, strong) I18NextOptions* optionsObject;

@property (nonatomic, strong) NSOperationQueue* backgroundQueue;

@property (nonatomic, copy) void (^completionBlock)(NSDictionary* store, NSError* error);

@property (nonatomic, strong) NSMutableArray* activeConnections;
@property (nonatomic, strong) NSMutableArray* errors;

@property (nonatomic, strong) NSMutableDictionary* store;

@end

@implementation I18NextLoader

- (instancetype)initWithOptions:(I18NextOptions*)options {
    self = [super init];
    if (self) {
        self.optionsObject = options;
        
        self.backgroundQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

- (void)loadLangs:(NSArray*)langs namespaces:(NSArray*)namespaces completion:(void (^)(NSDictionary* store, NSError* error))completionBlock {
    self.completionBlock = completionBlock;
    
    NSMutableArray* connections = [NSMutableArray array];
    
    if (self.optionsObject.dynamicLoad) {
        NSString* getPath = [self.optionsObject.resourcesGetPathTemplate i18n_stringByReplacingVariables:@{ @"lng": [langs componentsJoinedByString:@"+"],
                                                                                                            @"ns": [namespaces componentsJoinedByString:@"+"] }
                                                                                     interpolationPrefix:self.optionsObject.interpolationPrefix
                                                                                     interpolationSuffix:self.optionsObject.interpolationSuffix];
        
        I18NextConnection* connection = [self connectionForURLPath:getPath storeJSONBlock:^(NSDictionary *json) {
            self.store = json.mutableCopy;
        }];
        [connections addObject:connection];
    }
    else {
        for (NSString* lang in langs) {
            for (NSString* ns in namespaces) {
                NSString* getPath = [self.optionsObject.resourcesGetPathTemplate i18n_stringByReplacingVariables:@{ @"lng": lang,
                                                                                                                    @"ns": ns }
                                                                                             interpolationPrefix:self.optionsObject.interpolationPrefix
                                                                                             interpolationSuffix:self.optionsObject.interpolationSuffix];
                
                I18NextConnection* connection = [self connectionForURLPath:getPath storeJSONBlock:^(NSDictionary *json) {
                    if (!self.store) {
                        self.store = [NSMutableDictionary dictionary];
                    }
                    if (!self.store[lang]) {
                        self.store[lang] = [NSMutableDictionary dictionary];
                    }
                    self.store[lang][ns] = json;
                }];
                [connections addObject:connection];
            }
            
        }
    }
    
    self.activeConnections = connections;
    [connections makeObjectsPerformSelector:@selector(start)];
}

- (void)cancel {
    [self.activeConnections makeObjectsPerformSelector:@selector(cancel)];
    self.completionBlock = nil;
}

#pragma mark Private Methods

- (I18NextConnection*)connectionForURLPath:(NSString*)urlPath storeJSONBlock:(void (^)(NSDictionary* json))storeJSONBlock {
    NSString* urlString = [self.optionsObject.resourcesBaseURL.absoluteString
                               stringByAppendingPathComponent:urlPath];
    NSURL* url = [NSURL URLWithString:urlString];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    
    __block I18NextConnection* connection =
    [I18NextConnection asynchronousRequest:request queue:self.backgroundQueue
                         completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                             NSDictionary* json = nil;
                             NSError* returnError = error;
                             if (!error) {
                                 NSUInteger statusCode = ([response isKindOfClass:[NSHTTPURLResponse class]]) ?
                                 (NSUInteger)[(NSHTTPURLResponse*)response statusCode] : 200;
                                 
                                 if (statusCode != 200) {
                                     // status code error
                                     // TODO: localize with I18Next ;)
                                     NSString* localizedDescription = [NSString stringWithFormat:
                                                                       NSLocalizedString(@"Expected status code 200, got %d", nil), statusCode];
                                     returnError = [NSError errorWithDomain:I18NextErrorDomain code:NSURLErrorBadServerResponse
                                                                   userInfo:@{ NSURLErrorFailingURLErrorKey: url,
                                                                               NSLocalizedDescriptionKey: localizedDescription }];
                                 }
                                 else if (data) {
                                     NSError* jsonParseError = nil;
                                     id jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                                            options:kNilOptions
                                                                              error:&jsonParseError];
                                     
                                     if (jsonParseError) {
                                         // invalid json
                                         returnError = [NSError errorWithDomain:I18NextErrorDomain
                                                                           code:I18NextErrorInvalidLangData
                                                                       userInfo:@{ NSURLErrorFailingURLErrorKey: url,
                                                                                   NSUnderlyingErrorKey: jsonParseError }];
                                     }
                                     
                                     if (![jsonObject isKindOfClass:[NSDictionary class]]) {
                                         // object must be a dictionary
                                         returnError = [NSError errorWithDomain:I18NextErrorDomain code:I18NextErrorInvalidLangData
                                                                       userInfo:@{ NSURLErrorFailingURLErrorKey: url }];
                                     }
                                     else {
                                         json = jsonObject;
                                     }
                                        
                                 }
                                 else {
                                     // no data error
                                     returnError = [NSError errorWithDomain:I18NextErrorDomain code:I18NextErrorInvalidLangData
                                                                   userInfo:@{ NSURLErrorFailingURLErrorKey: url }];
                                 }
                             }
                             
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 if (json && storeJSONBlock) {
                                     storeJSONBlock(json);
                                 }
                                 
                                 if (returnError) {
                                     if (!self.errors) {
                                         self.errors = [NSMutableArray array];
                                     }
                                     [self.errors addObject:returnError];
                                 }
                                 
                                 [self.activeConnections removeObject:connection];
                                 if (self.activeConnections.count == 0 && self.completionBlock) {
                                     NSError* aggregateError = nil;
                                     if (self.errors.count > 0) {
                                         aggregateError = [NSError errorWithDomain:I18NextErrorDomain code:I18NextErrorLoadFailed
                                                                          userInfo:@{ I18NextDetailedErrorsKey: self.errors.copy }];
                                     }
                                     
                                     self.completionBlock(self.store, aggregateError);
                                 }
                             });
                         }];
    
    return connection;
}

@end
