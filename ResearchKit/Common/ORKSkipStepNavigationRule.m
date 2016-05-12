/*
 Copyright (c) 2015, Ricardo Sánchez-Sáez.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3.  Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "ORKSkipStepNavigationRule.h"

#import "ORKHelpers.h"
#import "ORKResult.h"
#import "ORKResultPredicate.h"


@implementation ORKSkipStepNavigationRule

- (instancetype)init_ork {
    return [super init];
}

- (instancetype)init {
    ORKThrowMethodUnavailableException();
}

- (BOOL)stepShouldSkipWithTaskResult:(ORKTaskResult *)taskResult{
    @throw [NSException exceptionWithName:NSGenericException reason:@"You should override this method in a subclass" userInfo:nil];
}

- (NSString *)identifierForDestinationStepWithTaskResult:(ORKTaskResult *)taskResult {
    @throw [NSException exceptionWithName:NSGenericException reason:@"You should override this method in a subclass" userInfo:nil];
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [super init];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
}

- (BOOL)isEqual:(id)object {
    if ([self class] != [object class]) {
        return NO;
    }
    return YES;
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    typeof(self) rule = [[[self class] allocWithZone:zone] init_ork];
    return rule;
}

@end


@interface ORKPredicateSkipStepNavigationRule ()

@property (nonatomic, copy) NSArray<NSPredicate *> *resultPredicates;
@property (nonatomic, copy) NSString *defaultStepIdentifier;

@end


@implementation ORKPredicateSkipStepNavigationRule

// Internal init without array validation, for serialization support
- (instancetype)initWithResultPredicates:(NSArray<NSPredicate *> *)resultPredicates
                   defaultStepIdentifier:(NSString *)defaultStepIdentifier
                          validateArrays:(BOOL)validateArrays {
    if (validateArrays) {
        ORKThrowInvalidArgumentExceptionIfNil(resultPredicates);
        
        NSUInteger resultPredicatesCount = resultPredicates.count;
        if (resultPredicatesCount == 0) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"resultPredicates cannot be an empty array" userInfo:nil];
        }
        ORKValidateArrayForObjectsOfClass(resultPredicates, [NSPredicate class], @"resultPredicates objects must be of a NSPredicate class kind");
        if (defaultStepIdentifier != nil && ![defaultStepIdentifier isKindOfClass:[NSString class]]) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"defaultStepIdentifier must be of a NSString class kind or nil" userInfo:nil];
        }
    }
    self = [super init_ork];
    if (self) {
        self.resultPredicates = resultPredicates;
        self.defaultStepIdentifier = defaultStepIdentifier;
    }
    
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)initWithResultPredicates:(NSArray<NSPredicate *> *)resultPredicates
                   defaultStepIdentifier:(NSString *)defaultStepIdentifier {
    return [self initWithResultPredicates:resultPredicates
                    defaultStepIdentifier:defaultStepIdentifier
                           validateArrays:YES];
}
#pragma clang diagnostic pop

- (instancetype)initWithResultPredicates:(NSArray<NSPredicate *> *)resultPredicates
              destinationStepIdentifiers:(NSArray<NSString *> *)destinationStepIdentifiers {
    return [self initWithResultPredicates:resultPredicates
                    defaultStepIdentifier:nil];
}

- (BOOL)stepShouldSkipWithTaskResult:(ORKTaskResult *)taskResult{
    BOOL shouldSkip = NO;
    NSMutableArray *allTaskResults = [[NSMutableArray alloc] initWithObjects:taskResult, nil];
    for (NSInteger i = 0; i < _resultPredicates.count; i++) {
        NSPredicate *predicate = _resultPredicates[i];
        if (![predicate evaluateWithObject:allTaskResults]) {
            shouldSkip = YES;
            break;
        }
    }
    return shouldSkip;
}

- (NSString *)identifierForNextStepWithTaskResult:(ORKTaskResult *)taskResult {
    return self.defaultStepIdentifier;
}

static NSArray *ORKLeafQuestionResultsFromTaskResult(ORKTaskResult *ORKTaskResult) {
    NSMutableArray *leafResults = [NSMutableArray new];
    for (ORKResult *result in ORKTaskResult.results) {
        if ([result isKindOfClass:[ORKCollectionResult class]]) {
            [leafResults addObjectsFromArray:[(ORKCollectionResult *)result results]];
        }
    }
    return leafResults;
}

// the results array should only contain objects that respond to the 'identifier' method (e.g., ORKResult objects).
// Usually you want all result objects to be of the same type.
static void ORKValidateIdentifiersUnique(NSArray *results, NSString *exceptionReason) {
    NSCParameterAssert(results);
    NSCParameterAssert(exceptionReason);
    
    NSArray *uniqueIdentifiers = [results valueForKeyPath:@"@distinctUnionOfObjects.identifier"];
    BOOL itemsHaveNonUniqueIdentifiers = (results.count != uniqueIdentifiers.count);
    if (itemsHaveNonUniqueIdentifiers) {
        @throw [NSException exceptionWithName:NSGenericException reason:exceptionReason userInfo:nil];
    }
}


#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        ORK_DECODE_OBJ_ARRAY(aDecoder, resultPredicates, NSPredicate);
        ORK_DECODE_OBJ_CLASS(aDecoder, defaultStepIdentifier, NSString);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    ORK_ENCODE_OBJ(aCoder, resultPredicates);
    ORK_ENCODE_OBJ(aCoder, defaultStepIdentifier);
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    typeof(self) rule = [[[self class] allocWithZone:zone] initWithResultPredicates:ORKArrayCopyObjects(_resultPredicates)
                                                              defaultStepIdentifier:[_defaultStepIdentifier copy]
                                                                     validateArrays:YES];
    return rule;
}

- (BOOL)isEqual:(id)object {
    BOOL isParentSame = [super isEqual:object];
    __typeof(self) castObject = object;
    return (isParentSame
            && ORKEqualObjects(self.resultPredicates, castObject.resultPredicates)
            && ORKEqualObjects(self.defaultStepIdentifier, castObject.defaultStepIdentifier));
}

- (NSUInteger)hash {
    return [_resultPredicates hash] ^ [_defaultStepIdentifier hash];
}

@end