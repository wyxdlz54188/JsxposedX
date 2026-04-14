package com.jsxposed.x.core.bridge.memory_tool_native

import android.content.Context
import android.os.Process
import com.jsxposed.x.core.utils.log.LogX
import com.jsxposed.x.core.utils.shell.Shell

class MemoryToolHelperManager(private val context: Context) {
    companion object {
        private const val TAG = "MemoryToolHelperManager"
        private const val STARTUP_RETRY_COUNT = 30
        private const val STARTUP_RETRY_DELAY_MS = 150L
    }

    private val socketName = "jsxposed_memory_tool_${Process.myPid()}"

    fun socketName(): String = socketName

    fun ensureDaemon() {
        synchronized(this) {
            if (isDaemonAlive()) {
                return
            }

            if (!hasRootAccess()) {
                throw IllegalStateException("Root access is required for memory search.")
            }

            startDaemon()
            waitForDaemonReady()
        }
    }

    fun isDaemonAlive(): Boolean {
        return MemoryToolDaemonClient.ping(socketName)
    }

    private fun startDaemon() {
        val sourceDir = context.applicationInfo.sourceDir
        val nativeLibraryDir = context.applicationInfo.nativeLibraryDir
        val memoryToolLibPath = "$nativeLibraryDir/libmemory_tool.so"
        val mainClass = "com.jsxposed.x.core.bridge.memory_tool_native.MemoryToolHelperMain"
        val command =
            "CLASSPATH=${shellEscape(sourceDir)} " +
                "/system/bin/app_process /system/bin $mainClass " +
                "${shellEscape(memoryToolLibPath)} ${shellEscape(socketName)} " +
                ">/dev/null 2>&1 &"
        LogX.i(TAG, "start daemon", socketName)
        Runtime.getRuntime().exec(arrayOf("su", "-c", command))
    }

    private fun waitForDaemonReady() {
        repeat(STARTUP_RETRY_COUNT) {
            if (isDaemonAlive()) {
                return
            }
            Thread.sleep(STARTUP_RETRY_DELAY_MS)
        }

        throw IllegalStateException("Memory tool helper daemon did not start.")
    }

    private fun hasRootAccess(): Boolean {
        val output = Shell(su = true).execute("id")
        return output.contains("uid=0")
    }

    private fun shellEscape(value: String): String {
        return "'${value.replace("'", "'\"'\"'")}'"
    }
}
