#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

// Guest test for MTLFunctionConstantValues. There is no public getter, so the stored entries are
// read back through the implementation's own ivars (_byIndex, _byName: {type, data} dictionaries).
// Build with -DNEGATIVE to invert every expectation; that run must fail.

#ifdef NEGATIVE
#define EXPECT(cond, what) record(!(cond), what)
#else
#define EXPECT(cond, what) record((cond), what)
#endif

static int failures = 0, total = 0;

static void record(int ok, const char *what) {
 total++;
 if (!ok) failures++;
 printf("%s %s\n", ok ? "PASS" : "FAIL", what);
}

static NSDictionary *table(id obj, const char *ivar) {
 Ivar v = class_getInstanceVariable([obj class], ivar);
 return v ? object_getIvar(obj, v) : nil;
}

static int entryIs(NSDictionary *t, id key, MTLDataType type, const void *bytes, NSUInteger length) {
 NSDictionary *e = t[key];
 NSData *d = e[@"data"];
 return e && [e[@"type"] unsignedIntegerValue] == type && d.length == length && memcmp(d.bytes, bytes, length) == 0;
}

static int raises(void (^block)(void)) {
 @try { block(); } @catch (NSException *e) { return [e.name isEqualToString:NSInvalidArgumentException]; }
 return 0;
}

int main(void) {
 @autoreleasepool {
  MTLFunctionConstantValues *v = [[MTLFunctionConstantValues alloc] init];
  EXPECT(v != nil, "init");
  EXPECT(class_getInstanceVariable([MTLFunctionConstantValues class], "_byIndex") && class_getInstanceVariable([MTLFunctionConstantValues class], "_byName"), "ivars _byIndex/_byName exist (test reads them; update if storage changes)");
  EXPECT([v conformsToProtocol:@protocol(NSCopying)] && [v respondsToSelector:@selector(setConstantValue:type:atIndex:)] && [v respondsToSelector:@selector(setConstantValue:type:withName:)] && [v respondsToSelector:@selector(setConstantValues:type:withRange:)] && [v respondsToSelector:@selector(reset)], "public selectors and NSCopying present");

  int i = 7;
  [v setConstantValue:&i type:MTLDataTypeInt atIndex:3];
  EXPECT(entryIs(table(v, "_byIndex"), @3, MTLDataTypeInt, &i, 4), "int at index 3 stored");
  i = 99;
  EXPECT(!entryIs(table(v, "_byIndex"), @3, MTLDataTypeInt, &i, 4), "bytes copied at set time, later caller change not seen");

  float f4[4] = {1, 2, 3, 4};
  [v setConstantValue:f4 type:MTLDataTypeFloat4 withName:@"color"];
  EXPECT(entryIs(table(v, "_byName"), @"color", MTLDataTypeFloat4, f4, 16), "float4 by name stored, 16 bytes");

  float f3[4] = {1, 2, 3, 0};
  [v setConstantValue:f3 type:MTLDataTypeFloat3 atIndex:5];
  EXPECT([table(v, "_byIndex")[@5][@"data"] length] == 16, "float3 occupies 16 bytes");

  unsigned char b = 1; short s = -2; long long l = 1LL << 40;
  [v setConstantValue:&b type:MTLDataTypeBool atIndex:10];
  [v setConstantValue:&s type:MTLDataTypeShort atIndex:11];
  [v setConstantValue:&l type:MTLDataTypeLong atIndex:12];
  EXPECT([table(v, "_byIndex")[@10][@"data"] length] == 1 && [table(v, "_byIndex")[@11][@"data"] length] == 2 && [table(v, "_byIndex")[@12][@"data"] length] == 8, "bool/short/long sizes 1/2/8");

  i = 8;
  [v setConstantValue:&i type:MTLDataTypeUInt atIndex:3];
  EXPECT(entryIs(table(v, "_byIndex"), @3, MTLDataTypeUInt, &i, 4) && [table(v, "_byIndex") count] == 5, "overwrite replaces type and bytes, no extra entry");

  int range[3] = {10, 20, 30};
  [v setConstantValues:range type:MTLDataTypeInt withRange:NSMakeRange(20, 3)];
  EXPECT(entryIs(table(v, "_byIndex"), @20, MTLDataTypeInt, &range[0], 4) && entryIs(table(v, "_byIndex"), @21, MTLDataTypeInt, &range[1], 4) && entryIs(table(v, "_byIndex"), @22, MTLDataTypeInt, &range[2], 4) && table(v, "_byIndex")[@23] == nil, "range stores consecutive indices, stride is the type size");

  float f2[4] = {1, 2, 3, 4};
  [v setConstantValues:f2 type:MTLDataTypeFloat2 withRange:NSMakeRange(40, 2)];
  EXPECT(entryIs(table(v, "_byIndex"), @41, MTLDataTypeFloat2, &f2[2], 8), "range of vectors strides by vector size");

  int n1 = 1, n2 = 2;
  NSMutableString *mname = [NSMutableString stringWithString:@"k"];
  [v setConstantValue:&n1 type:MTLDataTypeInt withName:mname];
  [mname appendString:@"2"];
  [v setConstantValue:&n2 type:MTLDataTypeInt withName:@"k"];
  EXPECT(entryIs(table(v, "_byName"), @"k", MTLDataTypeInt, &n2, 4) && table(v, "_byName")[@"k2"] == nil, "overwrite by name; later mutation of the name string not seen");
  unsigned short h[2] = {0x3c00, 0x4000};
  [v setConstantValue:h type:MTLDataTypeHalf2 withName:@"h2"];
  [v setConstantValue:h type:MTLDataTypeBFloat atIndex:60];
  [v setConstantValue:h type:MTLDataTypeBool4 atIndex:61];
  EXPECT([table(v, "_byName")[@"h2"][@"data"] length] == 4 && [table(v, "_byIndex")[@60][@"data"] length] == 2 && [table(v, "_byIndex")[@61][@"data"] length] == 4, "half2/bfloat/bool4 sizes 4/2/4");
  float f3r[8] = {1, 2, 3, 0, 5, 6, 7, 0};
  [v setConstantValues:f3r type:MTLDataTypeFloat3 withRange:NSMakeRange(70, 2)];
  EXPECT(entryIs(table(v, "_byIndex"), @71, MTLDataTypeFloat3, &f3r[4], 16), "float3 range strides by 16 bytes (assumed size)");

  MTLFunctionConstantValues *copy = [v copy];
  EXPECT(copy != v && [copy class] == [v class], "copy is a distinct object of the same class");
  EXPECT(table(copy, "_byIndex") != table(v, "_byIndex") && [table(copy, "_byIndex") isEqual:table(v, "_byIndex")] && [table(copy, "_byName") isEqual:table(v, "_byName")], "copy has equal, distinct tables");
  [v reset];
  EXPECT([table(v, "_byIndex") count] == 0 && [table(v, "_byName") count] == 0, "reset clears index and name tables");
  EXPECT([table(copy, "_byIndex") count] == 14 && [table(copy, "_byName") count] == 3, "reset of original leaves the copy intact");
  int one = 1;
  [copy setConstantValue:&one type:MTLDataTypeInt atIndex:0];
  EXPECT(table(v, "_byIndex")[@0] == nil, "writing to the copy does not reach the original");

  // malformed input fails loud
  EXPECT(raises(^{ [v setConstantValue:NULL type:MTLDataTypeInt atIndex:0]; }), "NULL value raises (index)");
  EXPECT(raises(^{ [v setConstantValue:NULL type:MTLDataTypeInt withName:@"x"]; }), "NULL value raises (name)");
  EXPECT(raises(^{ [v setConstantValues:NULL type:MTLDataTypeInt withRange:NSMakeRange(0, 2)]; }), "NULL values raises (range)");
  EXPECT(raises(^{ [v setConstantValue:&one type:MTLDataTypeNone atIndex:0]; }), "MTLDataTypeNone raises");
  EXPECT(raises(^{ [v setConstantValue:&one type:MTLDataTypeFloat4x4 atIndex:0]; }), "matrix type raises");
  EXPECT(raises(^{ [v setConstantValue:&one type:MTLDataTypeTexture atIndex:0]; }), "texture type raises");
  EXPECT(raises(^{ [v setConstantValue:&one type:(MTLDataType)9999 atIndex:0]; }), "unknown type raises");
  EXPECT(raises(^{ [v setConstantValue:&one type:MTLDataTypeInt withName:nil]; }), "nil name raises");
  EXPECT(raises(^{ [v setConstantValues:&one type:MTLDataTypeInt withRange:NSMakeRange(NSUIntegerMax, 2)]; }), "overflowing range raises");
  EXPECT(table(v, "_byIndex")[@0] == nil && [table(v, "_byName") count] == 0, "rejected calls stored nothing");

  printf("%d/%d checks %s\n", total - failures, total, failures ? "with failures" : "ok");
  puts(failures ? "FAIL" : "PASS");
  return failures != 0;
 }
}
