/*
 * This file is part of the JTObjectMapping package.
 * (c) James Tang <mystcolor@gmail.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "NSObject+JTObjectMapping.h"
#import "JTMappings.h"
#import "JTDateMappings.h"
#import <objc/runtime.h>

@implementation NSObject (JTObjectMapping)

- (void)setValueFromDictionary:(NSDictionary *)dict mapping:(NSDictionary *)mapping {
    
    __block NSMutableDictionary *notMapped = [mapping mutableCopy];

    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        id mapsToValue = [mapping objectForKey:key];
        if (mapsToValue == nil) {
            NSString *setter = [NSString stringWithFormat:@"set%@", [key capitalizedString]];
            if ([[self class] instancesRespondToSelector:NSSelectorFromString(setter)]) {
                mapsToValue = key;
            }
            if (mapsToValue == nil) {
                // We wants to auto reference the NSDictionary key corresponding NSObject property key
                // with the same name defined as in the NSObject subclass.
                if ([[self class] instancesRespondToSelector:NSSelectorFromString(key)]) {
                    mapsToValue = key;
                }
            }
        }
        if (mapsToValue != nil) {
            if ([obj isKindOfClass:[NSNull class]]) {
                if ([mapsToValue conformsToProtocol:@protocol(JTMappings)] || [mapsToValue conformsToProtocol:@protocol(JTDateMappings)]) {
                    [self setValue:nil forKey:[mapsToValue key]];
                } else if ([mapsToValue isKindOfClass:[NSString class]]) {
                    [self setValue:nil forKey:mapsToValue];
                } else {
                    NSAssert(NO, @"[mapsToValue class]: %@, for [NSNull null] objects not handled", NSStringFromClass([mapsToValue class]));
                }

            } else {

                if ([(NSObject *)mapsToValue isKindOfClass:[NSString class]]) {
                    if ([obj isKindOfClass:[NSNull class]]) {
                        [self setValue:nil forKey:mapsToValue];
                    } else {
                        [self setValue:obj forKey:mapsToValue];
                    }
                } else if ([mapsToValue conformsToProtocol:@protocol(JTMappings)] && [(NSObject *)obj isKindOfClass:[NSDictionary class]]) {
                    id <JTMappings> mappings = (id <JTMappings>)mapsToValue;
                    NSObject *targetObject = [[mappings.targetClass alloc] init];
                    [targetObject setValueFromDictionary:obj mapping:mappings.mapping];
                    [self setValue:targetObject forKey:mappings.key];
                    [targetObject release];
                } else if ([mapsToValue conformsToProtocol:@protocol(JTDateMappings)] && [(NSObject *)obj isKindOfClass:[NSString class]]) {
                    id <JTDateMappings> mappings = (id <JTDateMappings>)mapsToValue;
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    NSDate *date = nil;
                    for (NSString *dateFormatString in [mappings dateFormatStrings]) {
                        [formatter setDateFormat:dateFormatString];
                        date = [formatter dateFromString:obj];
                        if (date != nil) {
                            break;
                        }
                    }
                    [formatter release];
                    [self setValue:date forKey:mappings.key];
                } else if ([(NSObject *)obj isKindOfClass:[NSArray class]]) {
                    if ([mapsToValue conformsToProtocol:@protocol(JTMappings)]) {
                        id <JTMappings> mappings = (id <JTMappings>)mapsToValue;
                        NSObject *object = [mappings.targetClass objectFromJSONObject:obj mapping:mappings.mapping];
                        [self setValue:object forKey:mappings.key];
                    } else {
                        NSMutableArray *array = [NSMutableArray array];
                        for (NSObject *o in obj) {
                            [array addObject:o];
                        }
                        [self setValue:[NSArray arrayWithArray:array] forKey:mapsToValue];
                    }
                } else {
                    NSAssert2(NO, @"[mapsToValue class]: %@, [obj class]: %@ is not handled", NSStringFromClass([mapsToValue class]), NSStringFromClass([obj class])); 
                }

            }
            // Value is mapped, remove from notMapped dict
            [notMapped removeObjectForKey:key];
        }
    }];

    // Likely to be keyPath, enumerate and try add to our object
    // Could cause unexpected result if obj [dict valueForKeyPath:key] is not NSString
#if ! JTOBJECTMAPPING_DISABLE_KEYPATH_SUPPORT
    [notMapped enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        id value = [dict valueForKeyPath:key];
        [self setValue:value forKey:obj];
    }];
#endif

    [notMapped release];
}

+ (id <JTMappings>)mappingWithKey:(NSString *)key mapping:(NSDictionary *)mapping {
    return [JTMappings mappingWithKey:key targetClass:[self class] mapping:mapping];
}

+ (id)objectFromJSONObject:(id<JTValidJSONResponse>)object mapping:(NSDictionary *)mapping {
    id returnObject = nil;
    if ([object isKindOfClass:[NSDictionary class]]) {
        returnObject = [[[[self class] alloc] init] autorelease];
        [returnObject setValueFromDictionary:(NSDictionary *)object mapping:mapping];
    } else if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *array = [NSMutableArray array];
        for (NSObject *dict in (NSArray *)object) {
            NSParameterAssert([dict isKindOfClass:[NSDictionary class]]);
            NSObject *newObj = [[self class] objectFromJSONObject:(NSDictionary *)dict mapping:mapping];
            [array addObject:newObj];
        }
        returnObject = [NSArray arrayWithArray:array];
    }
    return returnObject;
}

@end


@implementation NSDate (JTObjectMapping)

+ (id <JTMappings>)mappingWithKey:(NSString *)key mapping:(NSDictionary *)mapping {
    [NSException raise:@"JTObjectMappingException" format:@"Please use +[NSDate mappingWithKey:dateFormatString:] instead."];
    return nil;
}

+ (id <JTDateMappings>)mappingWithKey:(NSString *)key dateFormatString:(NSString *)dateFormatString {
    return [JTDateMappings mappingWithKey:key dateFormatString:dateFormatString];
}

+ (id<JTDateMappings>)mappingWithKey:(NSString *)key dateFormatStrings:(NSArray *)dateFormatStrings {
    return [JTDateMappings mappingWithKey:key dateFormatStrings:dateFormatStrings];
}

@end


@implementation NSDictionary (JTObjectMapping)

+ (NSDictionary *)dictionaryWithPropertiesOfObject:(id)object mapping:(NSDictionary *)mapping {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    [mapping enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([obj conformsToProtocol:@protocol(JTDateMappings)]) {
            id<JTDateMappings> dateMapping = (id<JTDateMappings>)obj;
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:dateMapping.dateFormatString];
            [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
            id rawValue = [object valueForKey:[dateMapping key]];
            if (rawValue) {
                NSDate *date = (NSDate *)[object valueForKey:[dateMapping key]];
                [dictionary setValue:[formatter stringFromDate:date] forKey:key];
            }
            [formatter release];
        } else if ([obj conformsToProtocol:@protocol(JTMappings)]) {
            id<JTMappings> childMapping = (id<JTMappings>)obj;
            id mapFromObjValue = [object valueForKeyPath:[obj key]];
            if ([mapFromObjValue isKindOfClass:[NSArray class]]) {
                NSMutableArray *array = [NSMutableArray array];
                [(NSArray *)mapFromObjValue enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    NSDictionary *childDict = [NSDictionary dictionaryWithPropertiesOfObject:obj mapping:[childMapping mapping]];                    
                    [array addObject:childDict];
                }];
                [dictionary setValue:array forKey:key];
            } else {
                NSDictionary *childDict = [NSDictionary dictionaryWithPropertiesOfObject:mapFromObjValue mapping:[childMapping mapping]];
                [dictionary setValue:childDict forKey:key];
            }
        } else if ([obj isKindOfClass:[NSString class]]) {
            id value = [object valueForKey:(NSString *)obj];
            if (value) {
                [dictionary setValue:value forKey:key];
            }
        } else {
            id value = [object valueForKey:(NSString *)obj];
            NSAssert2(NO, @"[value class]: %@, [obj class]: %@ is not handled", NSStringFromClass([value class]), NSStringFromClass([obj class]));
        }
        
    }];
    
    return dictionary;
}

@end
