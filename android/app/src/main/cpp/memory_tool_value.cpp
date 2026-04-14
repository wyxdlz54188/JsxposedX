#include "memory_tool_value.h"

#include <algorithm>
#include <codecvt>
#include <cstring>
#include <iomanip>
#include <locale>
#include <sstream>
#include <stdexcept>

namespace memory_tool {

namespace {

template <typename T>
std::vector<uint8_t> EncodeBytes(T value, bool little_endian) {
    std::vector<uint8_t> bytes(sizeof(T));
    std::memcpy(bytes.data(), &value, sizeof(T));
    const bool host_little_endian = [] {
        uint16_t sample = 0x1;
        return *reinterpret_cast<uint8_t*>(&sample) == 0x1;
    }();
    if (host_little_endian != little_endian) {
        std::reverse(bytes.begin(), bytes.end());
    }
    return bytes;
}

template <typename T>
T DecodeBytes(const std::vector<uint8_t>& raw_bytes, bool little_endian) {
    std::vector<uint8_t> copy = raw_bytes;
    const bool host_little_endian = [] {
        uint16_t sample = 0x1;
        return *reinterpret_cast<uint8_t*>(&sample) == 0x1;
    }();
    if (host_little_endian != little_endian) {
        std::reverse(copy.begin(), copy.end());
    }

    T value{};
    std::memcpy(&value, copy.data(), sizeof(T));
    return value;
}

std::string FormatHex(const std::vector<uint8_t>& bytes) {
    std::ostringstream stream;
    for (size_t index = 0; index < bytes.size(); ++index) {
        if (index > 0) {
            stream << ' ';
        }
        stream << std::uppercase << std::hex << std::setw(2) << std::setfill('0')
               << static_cast<int>(bytes[index]);
    }
    return stream.str();
}

std::string FormatUtf8Text(const std::vector<uint8_t>& bytes) {
    return std::string(bytes.begin(), bytes.end());
}

std::string FormatUtf16LeText(const std::vector<uint8_t>& bytes) {
    if (bytes.empty()) {
        return {};
    }
    if (bytes.size() % 2 != 0) {
        return FormatHex(bytes);
    }

    std::u16string text;
    text.reserve(bytes.size() / 2);
    for (size_t index = 0; index < bytes.size(); index += 2) {
        const uint16_t code_unit = static_cast<uint16_t>(bytes[index]) |
                                   (static_cast<uint16_t>(bytes[index + 1]) << 8);
        text.push_back(static_cast<char16_t>(code_unit));
    }

    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> converter;
    return converter.to_bytes(text);
}

}  // namespace

size_t ResolveValueByteLength(SearchValueType type, size_t requested_length) {
    switch (type) {
        case SearchValueType::kI8:
            return 1;
        case SearchValueType::kI16:
            return 2;
        case SearchValueType::kI32:
            return 4;
        case SearchValueType::kI64:
            return 8;
        case SearchValueType::kF32:
            return 4;
        case SearchValueType::kF64:
            return 8;
        case SearchValueType::kBytes:
            return requested_length;
    }
    return requested_length;
}

bool BuildSearchPattern(const SearchValue& value,
                        std::vector<uint8_t>* bytes,
                        std::string* error) {
    if (bytes == nullptr) {
        return false;
    }

    bytes->clear();
    try {
        switch (value.type) {
            case SearchValueType::kI8:
                *bytes = EncodeBytes(static_cast<int8_t>(std::stoi(value.text_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kI16:
                *bytes = EncodeBytes(static_cast<int16_t>(std::stoi(value.text_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kI32:
                *bytes = EncodeBytes(static_cast<int32_t>(std::stol(value.text_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kI64:
                *bytes = EncodeBytes(static_cast<int64_t>(std::stoll(value.text_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kF32:
                *bytes = EncodeBytes(static_cast<float>(std::stof(value.text_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kF64:
                *bytes = EncodeBytes(static_cast<double>(std::stod(value.text_value)),
                                     value.little_endian);
                return true;
            case SearchValueType::kBytes:
                if (value.bytes_value.empty()) {
                    if (error != nullptr) {
                        *error = "Byte pattern is empty.";
                    }
                    return false;
                }
                *bytes = value.bytes_value;
                return true;
        }
    } catch (const std::exception& exception) {
        if (error != nullptr) {
            *error = exception.what();
        }
        return false;
    }

    if (error != nullptr) {
        *error = "Unsupported search value type.";
    }
    return false;
}

BytesDisplayEncoding ResolveBytesDisplayEncoding(const SearchValue& value) {
    if (value.type != SearchValueType::kBytes || value.bytes_value.empty()) {
        return BytesDisplayEncoding::kHex;
    }
    if (value.text_value.rfind("__jsx_text_utf16le__:", 0) == 0) {
        return BytesDisplayEncoding::kUtf16Le;
    }
    if (value.text_value.rfind("__jsx_text_utf8__:", 0) == 0) {
        return BytesDisplayEncoding::kUtf8;
    }
    return BytesDisplayEncoding::kHex;
}

std::string FormatDisplayValue(SearchValueType type,
                               const std::vector<uint8_t>& raw_bytes,
                               bool little_endian,
                               BytesDisplayEncoding bytes_display_encoding) {
    std::ostringstream stream;
    switch (type) {
        case SearchValueType::kI8:
            stream << static_cast<int>(DecodeBytes<int8_t>(raw_bytes, little_endian));
            return stream.str();
        case SearchValueType::kI16:
            stream << DecodeBytes<int16_t>(raw_bytes, little_endian);
            return stream.str();
        case SearchValueType::kI32:
            stream << DecodeBytes<int32_t>(raw_bytes, little_endian);
            return stream.str();
        case SearchValueType::kI64:
            stream << DecodeBytes<int64_t>(raw_bytes, little_endian);
            return stream.str();
        case SearchValueType::kF32:
            stream << DecodeBytes<float>(raw_bytes, little_endian);
            return stream.str();
        case SearchValueType::kF64:
            stream << DecodeBytes<double>(raw_bytes, little_endian);
            return stream.str();
        case SearchValueType::kBytes:
            switch (bytes_display_encoding) {
                case BytesDisplayEncoding::kUtf8:
                    return FormatUtf8Text(raw_bytes);
                case BytesDisplayEncoding::kUtf16Le:
                    return FormatUtf16LeText(raw_bytes);
                case BytesDisplayEncoding::kHex:
                    break;
            }
            return FormatHex(raw_bytes);
    }
    return {};
}

}  // namespace memory_tool
