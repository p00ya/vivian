// compat.h - macros for portability
// Copyright 2020 Dean Scarff
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef viv_compat_h
#define viv_compat_h

/// \file
/// libviv is written assuming a modern (C++17) compiler with some clang/GCC
/// extensions.  This header defines some fallback macros for non-standard
/// syntax.

// __has_include; see:
// https://clang.llvm.org/docs/LanguageExtensions.html#include-file-checking-macros
// https://gcc.gnu.org/onlinedocs/cpp/_005f_005fhas_005finclude.html
#ifndef __has_include
/// False fallback for clang/gcc preprocessor syntax.
#define __has_include(x) 0
#endif

// __attribute__; see:
// https://clang.llvm.org/docs/AttributeReference.html
// https://gcc.gnu.org/onlinedocs/gcc-10.1.0/gcc/Attribute-Syntax.html#Attribute-Syntax
#if !defined(__clang__) || !defined(__GNUC__)
/// Empty fallback for clang/gcc compiler syntax.
#define __attribute__(x)
#endif

// __has_attribute; see:
// https://clang.llvm.org/docs/LanguageExtensions.html#feature-checking-macros
// https://gcc.gnu.org/onlinedocs/cpp/_005f_005fhas_005fattribute.html#g_t_005f_005fhas_005fattribute
#ifndef __has_attribute
/// False fallback for clang/gcc preprocessor syntax.
#define __has_attribute(x) 0
#endif

// CF_SWIFT_NAME(); see:
// https://developer.apple.com/documentation/swift/objective-c_and_c_code_customization/customizing_your_c_code_for_swift
#if !defined(CF_SWIFT_NAME) && __has_attribute(swift_name)
#define CF_SWIFT_NAME(_sel) __attribute__((swift_name(#_sel)))
#endif

// VL_ENUM(type, tag) substitutes part of an enum specifier.
// The semantics are something like "enum tag : type" in C++.
//
// This is a similar to NS_ENUM, but does not assume that it's preceded by
// "typedef".  It causes Swift to generate actual enums.  See also:
// https://developer.apple.com/documentation/swift/objective-c_and_c_code_customization/grouping_related_objective-c_constants
#if __has_attribute(enum_extensibility)
#define VL_ENUM(_type, _name)                                                  \
  enum __attribute__((enum_extensibility(open))) _name
#elif defined(__cplusplus)
#define VL_ENUM(_type, _tag)                                                   \
  enum [[clang::enum_extensibility(open)]] _tag : _type
#else /* !__has_attribute(enum_extensibility) */
#define VL_ENUM(_type, _name) enum _name
#endif /* !__has_attribute(enum_extensibility) */

// Nullability type qualifiers; see:
// https://clang.llvm.org/docs/AttributeReference.html#nullability-attributes
// The undocumented assume_nonnull pragma is used extensively, so only
// _Nullable is explicitly specified.
#ifndef __clang__
/// Empty fallback for clang's nullable type qualifier.
#define _Nullable
#endif /* !defined(clang) */

// The C standard library's "assert()" looks for NDEBUG being defined.  For
// cleaner code, libviv also expects DEBUG to always be defined, but with
// value 0 or 1 for debug and release modes respectively.
//
// If DEBUG is not defined, set it based on the presence of NDEBUG.
#ifndef DEBUG

#ifdef NDEBUG
#define DEBUG 0
#else /* ndef NDEBUG */
#define DEBUG 1
#endif /* ndef NDEBUG */

#elif DEBUG && defined(NDEBUG)
#error "Conflicting debug definitions: DEBUG is true and NDEBUG is defined"
#endif /* DEBUG && defined(NDEBUG) */

#endif /* viv_compat_h */
