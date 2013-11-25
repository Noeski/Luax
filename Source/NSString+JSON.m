#import "NSString+JSON.h"

@implementation NSData(JSON)

- (NSDictionary *)JSONValue {
    NSDictionary *obj = nil;
    NSError *error = nil;
    
    obj = [NSJSONSerialization JSONObjectWithData:self
                                          options:NSJSONReadingMutableContainers
                                            error:&error];
#if DEBUG
    if (error) {
        NSString *str = [[NSString alloc] initWithData:self
                                              encoding:NSUTF8StringEncoding];
        NSLog(@"NSJSONSerialization error %@ parsing %@",
              error, str);
    }
#endif
    
    return obj;
}

@end

@implementation NSString(JSON)

- (NSDictionary *)JSONValue {
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];

    return [data JSONValue];
}

@end

@implementation NSObject(JSON)

- (NSString *)JSONRepresentation {
    NSString *st = nil;
    NSError *error = nil;

    NSData *data = [NSJSONSerialization dataWithJSONObject:self options:NSJSONWritingPrettyPrinted error:&error];
    st = [[NSString alloc]  initWithData:data encoding:NSUTF8StringEncoding];
    
#if DEBUG
    if(error) {
        NSLog(@"NSJSONSerialization error %@ parsing %@", error, self);
    }
#endif
    
    return st;
}
@end
