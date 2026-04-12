package com.jsxposed.x.core.bridge.memory_tool_native

object MemoryToolJni {
    init {
        System.loadLibrary("memory_tool")
    }

    external fun getPid(packageName: String): Long
}

class MemoryTool {
    fun getPid(packageName: String): Long {
        return MemoryToolJni.getPid(packageName)
    }
}
