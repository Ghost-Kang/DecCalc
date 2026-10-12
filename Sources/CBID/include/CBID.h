// Minimal interface to the Intel Decimal Floating-Point Math Library (BID encoding).
// The library is built with call-by-value, local rounding mode and local status
// flags, so every function takes its rounding mode and a flags pointer explicitly.
// The asm labels bind these names to the library's own symbols.

#ifndef CBID_H
#define CBID_H

#include <stdint.h>

typedef struct __attribute__((aligned(16))) {
    uint64_t w[2];
} CBIDDecimal128;

typedef unsigned int CBIDFlags;

enum {
    CBIDRoundNearestEven = 0,
    CBIDRoundDown = 1,
    CBIDRoundUp = 2,
    CBIDRoundTowardZero = 3,
    CBIDRoundNearestAway = 4,
};

enum {
    CBIDFlagInvalid = 0x01,
    CBIDFlagDenormal = 0x02,
    CBIDFlagZeroDivide = 0x04,
    CBIDFlagOverflow = 0x08,
    CBIDFlagUnderflow = 0x10,
    CBIDFlagInexact = 0x20,
};

#define CBID_UNARY(name) \
    CBIDDecimal128 cbid128_##name(CBIDDecimal128 x, int round, CBIDFlags *flags) __asm__("___bid128_" #name)
#define CBID_BINARY(name) \
    CBIDDecimal128 cbid128_##name(CBIDDecimal128 x, CBIDDecimal128 y, int round, CBIDFlags *flags) __asm__("___bid128_" #name)

CBID_BINARY(add);
CBID_BINARY(sub);
CBID_BINARY(mul);
CBID_BINARY(div);
CBID_BINARY(pow);
CBID_BINARY(hypot);
CBID_UNARY(sqrt);
CBID_UNARY(cbrt);
CBID_UNARY(exp);
CBID_UNARY(exp2);
CBID_UNARY(exp10);
CBID_UNARY(log);
CBID_UNARY(log2);
CBID_UNARY(log10);
CBID_UNARY(sin);
CBID_UNARY(cos);
CBID_UNARY(tan);
CBID_UNARY(asin);
CBID_UNARY(acos);
CBID_UNARY(atan);
CBID_UNARY(sinh);
CBID_UNARY(cosh);
CBID_UNARY(tanh);
CBID_UNARY(asinh);
CBID_UNARY(acosh);
CBID_UNARY(atanh);
CBID_UNARY(lgamma);
CBID_UNARY(tgamma);
CBID_UNARY(erf);

CBIDDecimal128 cbid128_fma(CBIDDecimal128 x, CBIDDecimal128 y, CBIDDecimal128 z, int round, CBIDFlags *flags)
    __asm__("___bid128_fma");
CBIDDecimal128 cbid128_fmod(CBIDDecimal128 x, CBIDDecimal128 y, CBIDFlags *flags) __asm__("___bid128_fmod");
CBIDDecimal128 cbid128_rem(CBIDDecimal128 x, CBIDDecimal128 y, CBIDFlags *flags) __asm__("___bid128_rem");
CBIDDecimal128 cbid128_quantize(CBIDDecimal128 x, CBIDDecimal128 y, int round, CBIDFlags *flags)
    __asm__("___bid128_quantize");
CBIDDecimal128 cbid128_scalbn(CBIDDecimal128 x, int n, int round, CBIDFlags *flags) __asm__("___bid128_scalbn");

CBIDDecimal128 cbid128_abs(CBIDDecimal128 x) __asm__("___bid128_abs");
CBIDDecimal128 cbid128_negate(CBIDDecimal128 x) __asm__("___bid128_negate");
CBIDDecimal128 cbid128_round_integral_nearest_even(CBIDDecimal128 x, CBIDFlags *flags)
    __asm__("___bid128_round_integral_nearest_even");
CBIDDecimal128 cbid128_round_integral_nearest_away(CBIDDecimal128 x, CBIDFlags *flags)
    __asm__("___bid128_round_integral_nearest_away");
CBIDDecimal128 cbid128_round_integral_zero(CBIDDecimal128 x, CBIDFlags *flags) __asm__("___bid128_round_integral_zero");
CBIDDecimal128 cbid128_round_integral_negative(CBIDDecimal128 x, CBIDFlags *flags)
    __asm__("___bid128_round_integral_negative");
CBIDDecimal128 cbid128_round_integral_positive(CBIDDecimal128 x, CBIDFlags *flags)
    __asm__("___bid128_round_integral_positive");

int cbid128_isNaN(CBIDDecimal128 x) __asm__("___bid128_isNaN");
int cbid128_isInf(CBIDDecimal128 x) __asm__("___bid128_isInf");
int cbid128_isZero(CBIDDecimal128 x) __asm__("___bid128_isZero");
int cbid128_isSigned(CBIDDecimal128 x) __asm__("___bid128_isSigned");
int cbid128_isFinite(CBIDDecimal128 x) __asm__("___bid128_isFinite");
int cbid128_quiet_equal(CBIDDecimal128 x, CBIDDecimal128 y, CBIDFlags *flags) __asm__("___bid128_quiet_equal");
int cbid128_quiet_less(CBIDDecimal128 x, CBIDDecimal128 y, CBIDFlags *flags) __asm__("___bid128_quiet_less");
int cbid128_quiet_greater(CBIDDecimal128 x, CBIDDecimal128 y, CBIDFlags *flags) __asm__("___bid128_quiet_greater");

CBIDDecimal128 cbid128_from_string(const char *string, int round, CBIDFlags *flags) __asm__("___bid128_from_string");
void cbid128_to_string(char *buffer, CBIDDecimal128 x, CBIDFlags *flags) __asm__("___bid128_to_string");
CBIDDecimal128 cbid128_from_int64(int64_t x) __asm__("___bid128_from_int64");
int64_t cbid128_to_int64_int(CBIDDecimal128 x, CBIDFlags *flags) __asm__("___bid128_to_int64_int");
double cbid128_to_binary64(CBIDDecimal128 x, int round, CBIDFlags *flags) __asm__("___bid128_to_binary64");
CBIDDecimal128 cbid128_from_binary64(double x, int round, CBIDFlags *flags) __asm__("___binary64_to_bid128");

#undef CBID_UNARY
#undef CBID_BINARY

#endif
