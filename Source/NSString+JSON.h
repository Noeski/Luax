@interface NSData(JSON)
- (NSDictionary *)JSONValue;
@end

@interface NSString(JSON)
- (NSDictionary *)JSONValue;
@end

@interface NSObject(JSON)
- (NSString *)JSONRepresentation;
@end