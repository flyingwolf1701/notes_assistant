package com.trini.notes_assistant

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.SamplerConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Bridges LiteRT-LM's Kotlin Engine into Flutter.
 *
 * Lifecycle: one engine + one conversation at a time (sufficient for this app).
 * Channel names must stay in sync with [LocalLlmService] on the Dart side.
 */
class LiteRtLmPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var appContext: Context
    private var activity: Activity? = null

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val mainHandler = Handler(Looper.getMainLooper())

    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var streamJob: Job? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        streamJob?.cancel()
        scope.launch { safeClose() }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isEngineReady" -> result.success(engine != null && conversation != null)
            "initEngine" -> initEngine(call, result)
            "sendMessage" -> sendMessage(call, result)
            "cancelStream" -> {
                streamJob?.cancel()
                result.success(null)
            }
            "close" -> scope.launch {
                safeClose()
                mainHandler.post { result.success(null) }
            }
            "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
            "requestAllFilesAccess" -> {
                requestAllFilesAccess()
                result.success(null)
            }
            "findGalleryModel" -> scope.launch {
                val path = findGalleryModel()
                mainHandler.post { result.success(path) }
            }
            "importGalleryModel" -> {
                val destPath = call.argument<String>("destPath")
                if (destPath == null) { result.error("BAD_ARGS", "destPath required", null); return }
                scope.launch {
                    try {
                        val src = findGalleryModel()
                        if (src == null) {
                            mainHandler.post { result.error("NOT_FOUND", "No .litertlm found in AI Edge Gallery", null) }
                            return@launch
                        }
                        File(src).copyTo(File(destPath), overwrite = true)
                        mainHandler.post { result.success(src) }
                    } catch (t: Throwable) {
                        mainHandler.post { result.error("COPY_FAILED", t.message, null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun initEngine(call: MethodCall, result: MethodChannel.Result) {
        val modelPath = call.argument<String>("modelPath")
        if (modelPath.isNullOrBlank() || !File(modelPath).exists()) {
            result.error("MODEL_NOT_FOUND", "Model file missing at $modelPath", null)
            return
        }
        val backendName = call.argument<String>("backend") ?: "gpu"
        val systemPrompt = call.argument<String>("systemPrompt")

        scope.launch {
            try {
                safeClose()

                // NPU intentionally omitted — its constructor requires a
                // vendor-specific library directory we don't have a source for.
                val backend: Backend = when (backendName.lowercase()) {
                    "cpu" -> Backend.CPU()
                    else -> Backend.GPU()
                }

                val newEngine = Engine(
                    EngineConfig(
                        modelPath = modelPath,
                        backend = backend,
                        cacheDir = appContext.cacheDir.path,
                    )
                )
                newEngine.initialize()

                val convConfig = ConversationConfig(
                    systemInstruction = systemPrompt?.let { Contents.of(it) },
                    samplerConfig = SamplerConfig(
                        topK = 10,
                        topP = 0.95,
                        temperature = 0.8,
                    ),
                )
                val newConversation = newEngine.createConversation(convConfig)

                engine = newEngine
                conversation = newConversation
                mainHandler.post { result.success(null) }
            } catch (t: Throwable) {
                mainHandler.post {
                    result.error("INIT_FAILED", t.message ?: "init failed", null)
                }
            }
        }
    }

    /**
     * Sends a message and streams token chunks to [eventSink].
     * Terminates with either `{"type":"done"}` or `{"type":"error","message":...}`.
     */
    private fun sendMessage(call: MethodCall, result: MethodChannel.Result) {
        val conv = conversation
        if (conv == null) {
            result.error("NO_CONVERSATION", "Engine not initialized", null)
            return
        }
        val text = call.argument<String>("text").orEmpty()
        val imagePath = call.argument<String>("imagePath")
        val audioPath = call.argument<String>("audioPath")

        val contents: Contents = if (imagePath == null && audioPath == null) {
            Contents.of(text)
        } else {
            val parts = mutableListOf<Content>()
            imagePath?.let { parts += Content.ImageFile(it) }
            audioPath?.let { parts += Content.AudioBytes(File(it).readBytes()) }
            if (text.isNotEmpty()) parts += Content.Text(text)
            Contents.of(*parts.toTypedArray())
        }

        streamJob?.cancel()
        streamJob = scope.launch {
            try {
                conv.sendMessageAsync(contents)
                    .catch { emitError(it.message ?: "stream error") }
                    .onCompletion { cause -> if (cause == null) emitDone() }
                    .collect { chunk -> emitChunk(chunk.toString()) }
            } catch (t: Throwable) {
                emitError(t.message ?: "send failed")
            }
        }
        result.success(null)
    }

    private fun emitChunk(text: String) = mainHandler.post {
        eventSink?.success(mapOf("type" to "chunk", "text" to text))
    }

    private fun emitDone() = mainHandler.post {
        eventSink?.success(mapOf("type" to "done"))
    }

    private fun emitError(message: String) = mainHandler.post {
        eventSink?.success(mapOf("type" to "error", "message" to message))
    }

    private suspend fun safeClose() = withContext(Dispatchers.IO) {
        try { conversation?.close() } catch (_: Throwable) {}
        try { engine?.close() } catch (_: Throwable) {}
        conversation = null
        engine = null
    }

    private fun hasAllFilesAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) {
            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                data = Uri.parse("package:${appContext.packageName}")
            }
            activity?.startActivity(intent)
        }
    }

    private fun findGalleryModel(): String? {
        val galleryRoot = File(
            Environment.getExternalStorageDirectory(),
            "Android/data/com.google.ai.edge.gallery/files"
        )
        if (!galleryRoot.exists()) return null
        return galleryRoot.walkTopDown()
            .firstOrNull { it.isFile && it.extension == "litertlm" }
            ?.absolutePath
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    companion object {
        private const val METHOD_CHANNEL = "notes_assistant/litertlm"
        private const val EVENT_CHANNEL = "notes_assistant/litertlm/stream"
    }
}
