#include "memory_tool_session.h"

namespace memory_tool {

void SearchSession::Clear() {
    has_active_session = false;
    pid = 0;
    type = SearchValueType::kI32;
    exact_mode = true;
    little_endian = true;
    value_size = 0;
    regions.clear();
    results.clear();
}

}  // namespace memory_tool
