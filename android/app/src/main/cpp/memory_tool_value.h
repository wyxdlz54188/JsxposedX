#ifndef JSXPOSEDX_MEMORY_TOOL_VALUE_H
#define JSXPOSEDX_MEMORY_TOOL_VALUE_H

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "memory_tool_session.h"

namespace memory_tool {

size_t ResolveValueByteLength(SearchValueType type, size_t requested_length);

bool BuildSearchPattern(const SearchValue& value,
                        std::vector<uint8_t>* bytes,
                        std::string* error);

BytesDisplayEncoding ResolveBytesDisplayEncoding(const SearchValue& value);

std::string FormatDisplayValue(SearchValueType type,
                               const std::vector<uint8_t>& raw_bytes,
                               bool little_endian,
                               BytesDisplayEncoding bytes_display_encoding =
                                   BytesDisplayEncoding::kHex);

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_VALUE_H
