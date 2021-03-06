//
//  I18NextTranslationMissingKeySpec.m
//  i18next
//
//  Created by Jean Regisser on 30/10/13.
//  Copyright (c) 2013 PrePlay, Inc. All rights reserved.
//

#import "Specta.h"
#define EXP_SHORTHAND
#import "Expecta.h"

#import "I18Next.h"

#import "I18NextSpecHelper.h"

SpecBegin(I18NextTranslationMissingKey)

describe(@"I18Next translation", ^{
    __block I18Next* i18n = nil;
    __block I18NextOptions* options = nil;
    
    beforeEach(^{
        i18n = createDefaultI18NextTestInstance();
        options = [I18NextOptions optionsFromDict:i18n.options];
    });
    
    describe(@"resource is missing", ^{
        
        beforeEach(^{
            options.resourcesStore =
            @{
              @"dev": @{ @"translation": @{ } },
              @"en": @{ @"translation": @{ } },
              @"en-US": @{ @"translation": @{ } },
              };
            [i18n loadWithOptions:options.asDictionary completion:nil];
        });
        
        it(@"should return key", ^{
            expect([i18n t:@"missing"]).to.equal(@"missing");
        });
        
        it(@"should return default value if set", ^{
            expect([i18n t:@"missing" defaultValue:@"defaultOfMissing"]).to.equal(@"defaultOfMissing");
        });
        
        describe(@"with namespaces", ^{
            
            it(@"should return key", ^{
                expect([i18n t:@"translate:missing"]).to.equal(@"translate:missing");
            });
            
            it(@"should return default value if set", ^{
                expect([i18n t:@"translate:missing" defaultValue:@"defaultOfMissing"]).to.equal(@"defaultOfMissing");
            });
            
            xdescribe(@"and function parseMissingKey set", ^{
                // See parseMissingKey from i18next javascript
            });
            
        });
    
    });
    
});

SpecEnd
