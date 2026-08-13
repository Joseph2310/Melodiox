package com.personalhymns.personal_hymns_library

import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaMuxer.OutputFormat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import kotlin.concurrent.thread
import kotlin.math.max

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "melodiox/media_trimmer",
        ).setMethodCallHandler { call, result ->
            if (call.method != "trimInPlace") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val sourcePath = call.argument<String>("sourcePath")
            val outputPath = call.argument<String>("outputPath")
            val startMs = call.argument<Number>("startMs")?.toLong()
            val endMs = call.argument<Number>("endMs")?.toLong()
            if (sourcePath.isNullOrBlank() ||
                outputPath.isNullOrBlank() ||
                startMs == null ||
                endMs == null ||
                endMs <= startMs
            ) {
                result.error("INVALID_ARGUMENTS", "Invalid trim arguments.", null)
                return@setMethodCallHandler
            }

            thread(name = "MelodioxMediaTrim") {
                try {
                    AndroidMediaTrimmer.trim(sourcePath, outputPath, startMs, endMs)
                    runOnUiThread { result.success(null) }
                } catch (error: Throwable) {
                    runOnUiThread {
                        result.error(
                            "TRIM_FAILED",
                            error.message ?: "Trim failed.",
                            null,
                        )
                    }
                }
            }
        }
    }
}

private object AndroidMediaTrimmer {
    fun trim(sourcePath: String, outputPath: String, startMs: Long, endMs: Long) {
        val source = File(sourcePath)
        if (!source.exists()) {
            throw IllegalArgumentException("Media file was not found.")
        }

        if (source.extension.equals("mp3", ignoreCase = true)) {
            trimMp3(source, File(outputPath), startMs, endMs)
        } else {
            trimWithMuxer(sourcePath, outputPath, startMs, endMs)
        }
    }

    private fun trimWithMuxer(
        sourcePath: String,
        outputPath: String,
        startMs: Long,
        endMs: Long,
    ) {
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        var wroteSamples = false
        try {
            extractor.setDataSource(sourcePath)
            muxer = MediaMuxer(outputPath, OutputFormat.MUXER_OUTPUT_MPEG_4)
            applyVideoRotation(sourcePath, muxer)

            val trackMap = mutableMapOf<Int, Int>()
            var bufferSize = 1024 * 1024
            var hasVideoTrack = false
            for (trackIndex in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(trackIndex)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("audio/") && !mime.startsWith("video/")) {
                    continue
                }
                if (mime == "audio/mpeg") {
                    throw IllegalArgumentException(
                        "MP3 files use the native MP3 trimmer only.",
                    )
                }
                if (mime.startsWith("video/")) {
                    hasVideoTrack = true
                }
                if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    bufferSize = max(
                        bufferSize,
                        format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE),
                    )
                }
                trackMap[trackIndex] = muxer.addTrack(format)
                extractor.selectTrack(trackIndex)
            }

            if (trackMap.isEmpty()) {
                throw IllegalArgumentException("No supported audio/video tracks found.")
            }

            muxer.start()
            muxerStarted = true
            val buffer = ByteBuffer.allocateDirect(bufferSize)
            val info = android.media.MediaCodec.BufferInfo()
            val startUs = startMs * 1000
            val endUs = endMs * 1000
            val trimStartUs = if (hasVideoTrack) {
                findNextVideoSyncUs(sourcePath, startUs) ?: startUs
            } else {
                startUs
            }
            var outputBaseUs: Long? = null

            extractor.seekTo(trimStartUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            while (true) {
                val trackIndex = extractor.sampleTrackIndex
                if (trackIndex < 0) {
                    break
                }
                val muxerTrackIndex = trackMap[trackIndex]
                if (muxerTrackIndex == null) {
                    extractor.advance()
                    continue
                }
                val sampleTimeUs = extractor.sampleTime
                if (sampleTimeUs < 0 || sampleTimeUs > endUs) {
                    break
                }
                if (sampleTimeUs < trimStartUs) {
                    extractor.advance()
                    continue
                }

                buffer.clear()
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) {
                    break
                }

                val firstSampleUs = outputBaseUs ?: sampleTimeUs
                outputBaseUs = firstSampleUs
                info.set(
                    0,
                    sampleSize,
                    max(0L, sampleTimeUs - firstSampleUs),
                    extractor.sampleFlags,
                )
                muxer.writeSampleData(muxerTrackIndex, buffer, info)
                wroteSamples = true
                extractor.advance()
            }

            if (!wroteSamples) {
                throw IllegalArgumentException(
                    "No video/audio samples found in the selected range. Try a wider range.",
                )
            }
            try {
                muxer.stop()
                muxerStarted = false
            } catch (error: Exception) {
                muxerStarted = false
                throw error
            }
        } finally {
            if (muxerStarted) {
                try {
                    muxer?.stop()
                } catch (_: Exception) {
                }
            }
            muxer?.release()
            extractor.release()
        }
    }

    private fun findNextVideoSyncUs(sourcePath: String, requestedStartUs: Long): Long? {
        if (requestedStartUs <= 0) {
            return 0
        }

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(sourcePath)
            for (trackIndex in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(trackIndex)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/")) {
                    continue
                }
                extractor.selectTrack(trackIndex)
                extractor.seekTo(requestedStartUs, MediaExtractor.SEEK_TO_NEXT_SYNC)
                val sampleTimeUs = extractor.sampleTime
                return if (sampleTimeUs >= 0) sampleTimeUs else null
            }
            return null
        } finally {
            extractor.release()
        }
    }

    private fun applyVideoRotation(sourcePath: String, muxer: MediaMuxer) {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(sourcePath)
            val rotation = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION,
            )?.toIntOrNull()
            if (rotation != null) {
                muxer.setOrientationHint(rotation)
            }
        } catch (_: Exception) {
        } finally {
            retriever.release()
        }
    }

    private fun trimMp3(source: File, output: File, startMs: Long, endMs: Long) {
        FileInputStream(source).use { input ->
            val fileSize = source.length()
            val id3Size = readId3v2Size(input)
            var offset = id3Size
            var currentUs = 0L
            var copyStart = -1L
            var copyEnd = -1L

            while (offset + 4 <= fileSize) {
                input.channel.position(offset)
                val headerBytes = ByteArray(4)
                if (input.read(headerBytes) != 4) {
                    break
                }
                val frame = Mp3Frame.fromHeader(headerBytes)
                if (frame == null) {
                    offset += 1
                    continue
                }

                val nextUs = currentUs + frame.durationUs
                if (nextUs >= startMs * 1000 && currentUs <= endMs * 1000) {
                    if (copyStart < 0) {
                        copyStart = offset
                    }
                    copyEnd = offset + frame.size
                }
                if (currentUs > endMs * 1000) {
                    break
                }
                currentUs = nextUs
                offset += frame.size
            }

            if (copyStart < 0 || copyEnd <= copyStart) {
                throw IllegalArgumentException("No MP3 frames found in the selected range.")
            }

            FileOutputStream(output).use { out ->
                if (id3Size > 0) {
                    copyRange(source, out, 0, id3Size)
                }
                copyRange(source, out, copyStart, copyEnd)
            }
        }
    }

    private fun readId3v2Size(input: FileInputStream): Long {
        input.channel.position(0)
        val header = ByteArray(10)
        if (input.read(header) != 10) {
            return 0
        }
        if (header[0].toInt().toChar() != 'I' ||
            header[1].toInt().toChar() != 'D' ||
            header[2].toInt().toChar() != '3'
        ) {
            return 0
        }
        val tagSize =
            ((header[6].toInt() and 0x7F) shl 21) or
                ((header[7].toInt() and 0x7F) shl 14) or
                ((header[8].toInt() and 0x7F) shl 7) or
                (header[9].toInt() and 0x7F)
        val hasFooter = (header[5].toInt() and 0x10) != 0
        return 10L + tagSize + if (hasFooter) 10L else 0L
    }

    private fun copyRange(source: File, output: FileOutputStream, start: Long, end: Long) {
        FileInputStream(source).use { input ->
            input.channel.position(start)
            val buffer = ByteArray(64 * 1024)
            var remaining = end - start
            while (remaining > 0) {
                val read = input.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
                if (read <= 0) {
                    break
                }
                output.write(buffer, 0, read)
                remaining -= read
            }
        }
    }

    private data class Mp3Frame(val size: Int, val durationUs: Long) {
        companion object {
            fun fromHeader(bytes: ByteArray): Mp3Frame? {
                val header =
                    ((bytes[0].toInt() and 0xFF) shl 24) or
                        ((bytes[1].toInt() and 0xFF) shl 16) or
                        ((bytes[2].toInt() and 0xFF) shl 8) or
                        (bytes[3].toInt() and 0xFF)
                if ((header and 0xFFE00000.toInt()) != 0xFFE00000.toInt()) {
                    return null
                }

                val version = (header shr 19) and 0x3
                val layer = (header shr 17) and 0x3
                val bitrateIndex = (header shr 12) and 0xF
                val sampleRateIndex = (header shr 10) and 0x3
                val padding = (header shr 9) and 0x1
                if (version == 1 || layer == 0 || bitrateIndex == 0 || bitrateIndex == 15 ||
                    sampleRateIndex == 3
                ) {
                    return null
                }

                val sampleRate = sampleRate(version, sampleRateIndex) ?: return null
                val bitrate = bitrateKbps(version, layer, bitrateIndex) ?: return null
                val samplesPerFrame = when (layer) {
                    3 -> 384
                    2 -> 1152
                    else -> if (version == 3) 1152 else 576
                }
                val frameSize = when (layer) {
                    3 -> (((12 * bitrate * 1000) / sampleRate) + padding) * 4
                    2 -> ((144 * bitrate * 1000) / sampleRate) + padding
                    else -> {
                        val coefficient = if (version == 3) 144 else 72
                        ((coefficient * bitrate * 1000) / sampleRate) + padding
                    }
                }
                if (frameSize <= 4) {
                    return null
                }
                return Mp3Frame(
                    frameSize,
                    (samplesPerFrame * 1_000_000L) / sampleRate,
                )
            }

            private fun sampleRate(version: Int, index: Int): Int? {
                val rates = when (version) {
                    3 -> intArrayOf(44100, 48000, 32000)
                    2 -> intArrayOf(22050, 24000, 16000)
                    0 -> intArrayOf(11025, 12000, 8000)
                    else -> return null
                }
                return rates[index]
            }

            private fun bitrateKbps(version: Int, layer: Int, index: Int): Int? {
                val table = when {
                    version == 3 && layer == 3 ->
                        intArrayOf(0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448)
                    version == 3 && layer == 2 ->
                        intArrayOf(0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384)
                    version == 3 ->
                        intArrayOf(0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320)
                    layer == 3 ->
                        intArrayOf(0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256)
                    else ->
                        intArrayOf(0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160)
                }
                return table[index]
            }
        }
    }
}
