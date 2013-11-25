#import "LXPacket.h"

@interface LXPacket() {
    LXPacketHeader _header;
    char* _data;
    int _capacity;
}
    
-(void)free;
@end

@implementation LXPacket

- (id)init {
    if(self = [super init]) {
        _data = NULL;
        _capacity = 0;
        
        _header.type = 0;
        _header.size = 0;
    }
    
    return self;
}

- (id)initWithString:(NSString *)string {
    return [self initWithCString:[string UTF8String]];
}

- (id)initWithCString:(const char*)cStr {
    return [self initWithCString:cStr size:(int)strlen(cStr)];
}

- (id)initWithCString:(const char*)cStr size:(int)size {
    if(self = [self init]) {
        [self append:cStr size:size];
    }
    
    return self;
}

- (id)initWithPacket:(LXPacket *)other {
    if(self = [self init]) {
        self.headerType = other.headerType;
        [self append:other.dataPtr size:other.size];
    }
    
    return self;
}

- (void)dealloc {
    [self free];
}

- (void)free {
    _capacity = 0;
    _header.size = 0;
    
	if(_data) {
		free(_data);
		_data = NULL;
	}
}

- (void)append:(const char*)data size:(int)size {
    if(_header.size+size >= _capacity) {
		int newCapacity = _capacity*2;
        
        if(newCapacity < _header.size+size) {
            newCapacity = _header.size+size;
        }
        
        [self reserve:newCapacity];
	}
	
    memcpy(&_data[sizeof(LXPacketHeader)+_header.size], data, size);
    
	_header.size += size;
    
    if(_data) {
        LXPacketHeader *header = (LXPacketHeader *)_data;
        header->size = htonl(_header.size);
        header->type = htonl(_header.type);
    }
}

- (void)resize:(int)newSize {
    [self reserve:newSize];
    
    _header.size = newSize;
    
    if(_data) {
        LXPacketHeader *header = (LXPacketHeader *)_data;
        header->size = htonl(_header.size);
    }
}

- (void)reserve:(int)newCapacity {
    if(sizeof(LXPacketHeader)+newCapacity >= _capacity) {
        char* newArray = malloc(sizeof(LXPacketHeader)+newCapacity);
        
        if(_data) {
            memcpy(newArray, _data, sizeof(LXPacketHeader)+_header.size);
            
            free(_data);
        }
        
        _data = newArray;
        _capacity = newCapacity;
	}
}

- (void)appendByte:(unsigned char)value {
    [self append:(const char*)&value size:sizeof(value)];
}

- (void)appendShort:(unsigned short)value {
    unsigned short networkValue = htons(value);
    
    [self append:(const char*)&networkValue size:sizeof(networkValue)];
}

- (void)appendInt:(unsigned int)value {
    unsigned int networkValue = htonl(value);
    
    [self append:(const char*)&networkValue size:sizeof(networkValue)];
}

- (void)appendString:(NSString *)value {
    const char *cStr = [value UTF8String];
    
    [self append:cStr size:(int)[value length]+1];
}

- (void)appendPacket:(LXPacket *)value {    
    [self append:value.dataPtr size:value.size];
}

- (unsigned char)readByte {
    return [self readByte:0];
}

- (unsigned short)readShort {
    return [self readShort:0];
}

- (unsigned int)readInt {
    return [self readInt:0];
}

- (unsigned char)readByte:(int)offset {
    unsigned char result = (unsigned char)(*[self dataPtr:offset]);
	
	return result;
}

- (unsigned short)readShort:(int)offset {
    unsigned short result = ntohs((unsigned short)(*[self dataPtr:offset]));
	
	return result;
}

- (unsigned int)readInt:(int)offset {
    unsigned int result = ntohl((unsigned int)(*[self dataPtr:offset]));
	
	return result;
}

- (LXPacket *)subPacket:(int)start {
    return [self subPacket:start withLength:-1];
}

- (LXPacket *)subPacket:(int)start withLength:(int)length {
    if(length == -1)
        length = _header.size - start;
    
    return [[LXPacket alloc] initWithCString:[self dataPtr:start] size:length];
}

- (int)headerType {
    return _header.type;
}

- (void)setHeaderType:(int)headerType {
    _header.type = headerType;
    
    if(_data) {
        LXPacketHeader *header = (LXPacketHeader *)_data;
        header->type = htonl(_header.type);
    }
}

- (int)size {
    return _header.size;
}

- (int)sizeWithHeader {
    return sizeof(LXPacketHeader)+_header.size;
}

- (char *)dataPtr {
    return [self dataPtr:0];
}

- (char *)dataPtr:(int)offset {
    return _data+sizeof(LXPacketHeader)+offset;
}

- (char *)headerPtr {
    return _data;
}

@end
