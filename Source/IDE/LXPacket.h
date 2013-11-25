typedef struct {
    int type;
    int size;
} LXPacketHeader ;

@interface LXPacket : NSObject 
@property (nonatomic) int headerType;
@property (nonatomic, readonly) int size;
@property (nonatomic, readonly) int sizeWithHeader;
@property (nonatomic, readonly) char *dataPtr;
@property (nonatomic, readonly) char *headerPtr;

- (id)init;
- (id)initWithString:(NSString *)string;
- (id)initWithCString:(const char*)cStr;
- (id)initWithCString:(const char*)cStr size:(int)size;
- (id)initWithPacket:(LXPacket *)other;

- (void)append:(const char*)data size:(int)size;
- (void)resize:(int)newSize;
- (void)reserve:(int)newCapacity;

- (void)appendByte:(unsigned char)value;
- (void)appendShort:(unsigned short)value;
- (void)appendInt:(unsigned int)value;
- (void)appendString:(NSString *)value;
- (void)appendPacket:(LXPacket *)value;

- (unsigned char)readByte;
- (unsigned short)readShort;
- (unsigned int)readInt;

- (unsigned char)readByte:(int)offset;
- (unsigned short)readShort:(int)offset;
- (unsigned int)readInt:(int)offset;

- (LXPacket *)subPacket:(int)start;
- (LXPacket *)subPacket:(int)start withLength:(int)length;

@end