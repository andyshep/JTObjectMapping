/*
 * This file is part of the JTObjectMapping package.
 * (c) James Tang <mystcolor@gmail.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "JTDateMappings.h"

@implementation JTDateMappings
@synthesize dateFormatStrings, key;

+ (id <JTDateMappings>)mappingWithKey:(NSString *)key dateFormatString:(NSString *)dateFormatString {
    return [self mappingWithKey:key dateFormatStrings:[NSArray arrayWithObject:dateFormatString]];
}

+ (id<JTDateMappings>)mappingWithKey:(NSString *)key dateFormatStrings:(NSArray *)dateFormatStrings {
    JTDateMappings *dateMappings = [[JTDateMappings alloc] init];
    dateMappings.dateFormatStrings = dateFormatStrings;
    dateMappings.key = key;
    return [dateMappings autorelease];
}

- (void)dealloc {
    self.dateFormatStrings = nil;
    self.key = nil;
    [super dealloc];
}

@end



@implementation JTDateEpochMappings
@synthesize key, divisorForSeconds;

+ (id <JTDateEpochMappings>)mappingWithKey:(NSString *)key divisorForSeconds:(CGFloat)divisorForSeconds {
    JTDateEpochMappings *epochMapping = [[JTDateEpochMappings alloc] init];
    epochMapping.key = key;
    epochMapping.divisorForSeconds = divisorForSeconds;
    return [epochMapping autorelease];
}

- (void)dealloc {
    self.key = nil;
    [super dealloc];
}

@end
