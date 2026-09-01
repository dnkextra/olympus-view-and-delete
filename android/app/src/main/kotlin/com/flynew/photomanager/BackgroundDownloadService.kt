package com.flynew.photomanager

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.provider.MediaStore
import androidx.exifinterface.media.ExifInterface
import org.json.JSONArray
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

class BackgroundDownloadService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val queuePath = intent?.getStringExtra(EXTRA_QUEUE_PATH)
        if (queuePath.isNullOrBlank()) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (isRunning) return START_NOT_STICKY

        val queueFile = File(queuePath)
        val items = try {
            JSONArray(queueFile.readText())
        } catch (_: Exception) {
            queueFile.delete()
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (items.length() == 0) {
            queueFile.delete()
            stopSelf(startId)
            return START_NOT_STICKY
        }

        isRunning = true
        startForeground(
            PROGRESS_NOTIFICATION_ID,
            buildProgressNotification(0, items.length(), "Starting download…"),
        )

        Thread {
            var success = 0
            var failed = 0
            val history = DownloadHistoryStore(this)
            // A redelivered intent means Android killed us mid-batch and restarted the
            // whole queue. Skip what already landed; a fresh batch always re-downloads,
            // because re-downloading a known file is a deliberate user action.
            // ponytail: history is not per-batch, so a redelivered batch also skips a
            // deliberate re-download of a file downloaded in some earlier batch. Track
            // per-batch completion (rewriting the queue file as items finish) if that
            // ever matters more than the duplicate-import storm it prevents.
            val alreadyDownloaded = if ((flags and START_FLAG_REDELIVERY) != 0) {
                history.getKeys()
            } else {
                emptySet<String>()
            }
            try {
                for (index in 0 until items.length()) {
                    val item = items.getJSONObject(index)
                    val filename = item.getString("filename")
                    val url = item.getString("url")
                    val historyKey = item.getString("historyKey")
                    val targetBytes = item.optInt("targetBytes", 0)

                    // Blank keys are never marked, so they are never in the set.
                    if (historyKey in alreadyDownloaded) {
                        success++
                        updateProgress(index + 1, items.length(), filename)
                        continue
                    }

                    updateProgress(index, items.length(), filename)
                    try {
                        downloadAndSave(url, filename, targetBytes)
                        history.mark(historyKey)
                        success++
                    } catch (_: Exception) {
                        failed++
                    }
                    updateProgress(index + 1, items.length(), filename)
                }
            } finally {
                queueFile.delete()
                isRunning = false
                stopForegroundCompat()
                showCompletionNotification(success, failed)
                stopSelf(startId)
            }
        }.start()

        return START_REDELIVER_INTENT
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    private fun downloadAndSave(url: String, filename: String, targetBytes: Int) {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 15_000
            connection.readTimeout = 120_000
            connection.requestMethod = "GET"
            connection.setRequestProperty("User-Agent", "OI.Share v2")
            connection.setRequestProperty("Host", "192.168.0.10")
            connection.setRequestProperty("Connection", "Keep-Alive")
            connection.connect()

            if (connection.responseCode !in 200..299) {
                error("Camera returned HTTP ${connection.responseCode}")
            }

            connection.inputStream.buffered().use { input ->
                // Only JPEGs with a size target are buffered and re-encoded.
                // Everything else — RAW/ORF above all — streams straight to
                // disk and never reaches a bitmap decoder.
                if (targetBytes > 0 && isJpeg(filename)) {
                    saveRecompressed(filename, input.readBytes(), targetBytes)
                } else {
                    saveStream(filename, input)
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    /**
     * Saves [source] re-encoded to fit [targetBytes]. Falls back to saving the
     * original bytes whenever the re-encode cannot be completed with its
     * metadata intact — a full-size photo beats a lost or stripped one.
     */
    private fun saveRecompressed(filename: String, source: ByteArray, targetBytes: Int) {
        // Already small enough: re-encoding could only lose quality.
        val recompressed = if (source.size <= targetBytes) {
            null
        } else {
            prepareRecompressed(source, targetBytes)
        }

        if (recompressed == null) {
            ByteArrayInputStream(source).use { saveStream(filename, it) }
            return
        }
        try {
            FileInputStream(recompressed).buffered().use { saveStream(filename, it) }
        } finally {
            recompressed.delete()
        }
    }

    /** Re-encoded copy carrying the original EXIF, or null to save the original. */
    private fun prepareRecompressed(source: ByteArray, targetBytes: Int): File? {
        val compressed = try {
            compressJpeg(source, targetBytes)
        } catch (_: Exception) {
            null
        } ?: return null

        val temp = File.createTempFile("recompressed", ".jpg", cacheDir)
        return try {
            FileOutputStream(temp).use { it.write(compressed) }
            copyExif(source, temp)
            temp
        } catch (_: Exception) {
            temp.delete()
            null
        }
    }

    /**
     * Largest JPEG at or under [targetBytes], searched by quality only: the
     * output keeps the source's pixel dimensions. Mirrors
     * lib/services/jpeg_compressor.dart. Returns null when the bitmap cannot be
     * decoded or does not fit in memory.
     */
    private fun compressJpeg(source: ByteArray, targetBytes: Int): ByteArray? {
        // Decoded once and reused for every search step; a 20 MP frame is
        // ~80 MB as ARGB_8888, so re-decoding per step is not affordable and
        // running out of memory has to be survivable.
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = try {
            BitmapFactory.decodeByteArray(source, 0, source.size, options)
        } catch (_: OutOfMemoryError) {
            null
        } ?: return null

        return try {
            val buffer = ByteArrayOutputStream()
            var low = MIN_JPEG_QUALITY
            var high = MAX_JPEG_QUALITY
            var best: ByteArray? = null
            while (low <= high) {
                val quality = (low + high) / 2
                val candidate = encodeJpeg(bitmap, quality, buffer)
                if (candidate.size <= targetBytes) {
                    best = candidate
                    low = quality + 1
                } else {
                    high = quality - 1
                }
            }
            // Nothing fit: the lowest quality worth saving is still better than
            // silently handing back a full-size file.
            best ?: encodeJpeg(bitmap, MIN_JPEG_QUALITY, buffer)
        } catch (_: OutOfMemoryError) {
            null
        } finally {
            bitmap.recycle()
        }
    }

    private fun encodeJpeg(
        bitmap: Bitmap,
        quality: Int,
        buffer: ByteArrayOutputStream,
    ): ByteArray {
        buffer.reset()
        if (!bitmap.compress(Bitmap.CompressFormat.JPEG, quality, buffer)) {
            error("JPEG encoding failed at quality $quality")
        }
        return buffer.toByteArray()
    }

    /**
     * Bitmap.compress writes no EXIF at all, so every tag is copied over from
     * the original. Dimensions are unchanged by the re-encode, so the dimension
     * and orientation tags are copied verbatim.
     */
    private fun copyExif(source: ByteArray, destination: File) {
        val sourceExif = ByteArrayInputStream(source).use { ExifInterface(it) }
        val destinationExif = ExifInterface(destination)
        var copied = false
        for (tag in COPIED_EXIF_TAGS) {
            val value = sourceExif.getAttribute(tag) ?: continue
            destinationExif.setAttribute(tag, value)
            copied = true
        }
        if (copied) destinationExif.saveAttributes()
    }

    private fun saveStream(filename: String, input: InputStream) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(filename, input)
        } else {
            saveLegacy(filename, input)
        }
    }

    private fun saveWithMediaStore(filename: String, input: InputStream) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeTypeFor(filename))
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DCIM}/OlympusView",
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = if (isGalleryImage(filename)) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val uri = contentResolver.insert(collection, values)
            ?: error("MediaStore could not create destination")

        try {
            contentResolver.openOutputStream(uri, "w")?.use { output ->
                input.copyTo(output, DEFAULT_BUFFER_SIZE)
                output.flush()
            } ?: error("MediaStore could not open destination")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(filename: String, input: InputStream) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            error("Storage permission is required")
        }

        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
            "OlympusView",
        )
        if (!directory.exists() && !directory.mkdirs()) {
            error("Could not create ${directory.absolutePath}")
        }

        val file = File(directory, filename)
        FileOutputStream(file).use { output ->
            input.copyTo(output, DEFAULT_BUFFER_SIZE)
            output.flush()
        }
        MediaScannerConnection.scanFile(
            this,
            arrayOf(file.absolutePath),
            arrayOf(mimeTypeFor(filename)),
            null,
        )
    }

    private fun updateProgress(done: Int, total: Int, filename: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(
            PROGRESS_NOTIFICATION_ID,
            buildProgressNotification(done, total, filename),
        )
    }

    private fun buildProgressNotification(done: Int, total: Int, filename: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_PROGRESS)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.drawable.ic_download_notification)
            .setContentTitle("Olympus View — downloading")
            .setContentText("$done / $total · $filename")
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setProgress(total, done.coerceAtMost(total), false)
            .build()
    }

    private fun showCompletionNotification(success: Int, failed: Int) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_COMPLETE)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val text = if (failed == 0) {
            "$success file(s) downloaded"
        } else {
            "$success downloaded, $failed failed"
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_download_notification)
            .setContentTitle("Olympus View — download complete")
            .setContentText(text)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        getSystemService(NotificationManager::class.java)
            .notify(COMPLETE_NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val progress = NotificationChannel(
            CHANNEL_PROGRESS,
            "Camera downloads",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Progress while photos are downloaded from the camera"
            setSound(null, null)
        }
        val complete = NotificationChannel(
            CHANNEL_COMPLETE,
            "Download completed",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Alerts when camera downloads finish"
            enableVibration(true)
        }
        manager.createNotificationChannel(progress)
        manager.createNotificationChannel(complete)
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun isJpeg(filename: String): Boolean =
        when (filename.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> true
            else -> false
        }

    private fun isGalleryImage(filename: String): Boolean =
        when (filename.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg", "png", "gif", "webp", "heic", "heif" -> true
            else -> false
        }

    private fun mimeTypeFor(filename: String): String =
        when (filename.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "heic", "heif" -> "image/heic"
            "orf" -> "image/x-olympus-orf"
            "dng" -> "image/x-adobe-dng"
            "raw" -> "image/x-raw"
            else -> "application/octet-stream"
        }

    companion object {
        const val EXTRA_QUEUE_PATH = "queue_path"
        private const val CHANNEL_PROGRESS = "olympus_camera_downloads"
        private const val CHANNEL_COMPLETE = "olympus_camera_download_complete"
        private const val PROGRESS_NOTIFICATION_ID = 3101
        private const val COMPLETE_NOTIFICATION_ID = 3102

        // Same bounds as kMinJpegQuality/kMaxJpegQuality in
        // lib/services/jpeg_compressor.dart. Below the floor the result stops
        // looking like a photo, so a file that cannot reach the target is
        // saved at the floor rather than going lower.
        private const val MIN_JPEG_QUALITY = 40
        private const val MAX_JPEG_QUALITY = 95

        // Everything ExifInterface can carry as a well-typed value. Tags that
        // describe the JPEG bitstream itself (compression, sub-sampling, strip
        // and thumbnail offsets) are deliberately not copied: they belong to
        // the original encoding. MakerNote, UserComment and XMP are skipped
        // too — ExifInterface only exposes them as strings, which mangles
        // binary payloads, and Olympus maker notes carry absolute offsets that
        // no longer point anywhere once the EXIF block moves.
        private val COPIED_EXIF_TAGS = arrayOf(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.TAG_IMAGE_WIDTH,
            ExifInterface.TAG_IMAGE_LENGTH,
            ExifInterface.TAG_PIXEL_X_DIMENSION,
            ExifInterface.TAG_PIXEL_Y_DIMENSION,
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_DATETIME_ORIGINAL,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_OFFSET_TIME,
            ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
            ExifInterface.TAG_OFFSET_TIME_DIGITIZED,
            ExifInterface.TAG_SUBSEC_TIME,
            ExifInterface.TAG_SUBSEC_TIME_ORIGINAL,
            ExifInterface.TAG_SUBSEC_TIME_DIGITIZED,
            ExifInterface.TAG_MAKE,
            ExifInterface.TAG_MODEL,
            ExifInterface.TAG_SOFTWARE,
            ExifInterface.TAG_ARTIST,
            ExifInterface.TAG_COPYRIGHT,
            ExifInterface.TAG_IMAGE_DESCRIPTION,
            ExifInterface.TAG_IMAGE_UNIQUE_ID,
            ExifInterface.TAG_BODY_SERIAL_NUMBER,
            ExifInterface.TAG_CAMERA_OWNER_NAME,
            ExifInterface.TAG_LENS_MAKE,
            ExifInterface.TAG_LENS_MODEL,
            ExifInterface.TAG_LENS_SERIAL_NUMBER,
            ExifInterface.TAG_LENS_SPECIFICATION,
            ExifInterface.TAG_EXPOSURE_TIME,
            ExifInterface.TAG_F_NUMBER,
            ExifInterface.TAG_EXPOSURE_PROGRAM,
            ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY,
            ExifInterface.TAG_SENSITIVITY_TYPE,
            ExifInterface.TAG_STANDARD_OUTPUT_SENSITIVITY,
            ExifInterface.TAG_RECOMMENDED_EXPOSURE_INDEX,
            ExifInterface.TAG_ISO_SPEED,
            ExifInterface.TAG_ISO_SPEED_LATITUDE_YYY,
            ExifInterface.TAG_ISO_SPEED_LATITUDE_ZZZ,
            ExifInterface.TAG_SHUTTER_SPEED_VALUE,
            ExifInterface.TAG_APERTURE_VALUE,
            ExifInterface.TAG_BRIGHTNESS_VALUE,
            ExifInterface.TAG_EXPOSURE_BIAS_VALUE,
            ExifInterface.TAG_MAX_APERTURE_VALUE,
            ExifInterface.TAG_SUBJECT_DISTANCE,
            ExifInterface.TAG_SUBJECT_DISTANCE_RANGE,
            ExifInterface.TAG_SUBJECT_AREA,
            ExifInterface.TAG_SUBJECT_LOCATION,
            ExifInterface.TAG_METERING_MODE,
            ExifInterface.TAG_LIGHT_SOURCE,
            ExifInterface.TAG_FLASH,
            ExifInterface.TAG_FLASH_ENERGY,
            ExifInterface.TAG_FOCAL_LENGTH,
            ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM,
            ExifInterface.TAG_FOCAL_PLANE_X_RESOLUTION,
            ExifInterface.TAG_FOCAL_PLANE_Y_RESOLUTION,
            ExifInterface.TAG_FOCAL_PLANE_RESOLUTION_UNIT,
            ExifInterface.TAG_EXPOSURE_MODE,
            ExifInterface.TAG_EXPOSURE_INDEX,
            ExifInterface.TAG_WHITE_BALANCE,
            ExifInterface.TAG_DIGITAL_ZOOM_RATIO,
            ExifInterface.TAG_SCENE_CAPTURE_TYPE,
            ExifInterface.TAG_SCENE_TYPE,
            ExifInterface.TAG_SENSING_METHOD,
            ExifInterface.TAG_FILE_SOURCE,
            ExifInterface.TAG_CUSTOM_RENDERED,
            ExifInterface.TAG_GAIN_CONTROL,
            ExifInterface.TAG_CONTRAST,
            ExifInterface.TAG_SATURATION,
            ExifInterface.TAG_SHARPNESS,
            ExifInterface.TAG_SPECTRAL_SENSITIVITY,
            ExifInterface.TAG_RELATED_SOUND_FILE,
            ExifInterface.TAG_COLOR_SPACE,
            ExifInterface.TAG_GAMMA,
            ExifInterface.TAG_WHITE_POINT,
            ExifInterface.TAG_PRIMARY_CHROMATICITIES,
            ExifInterface.TAG_X_RESOLUTION,
            ExifInterface.TAG_Y_RESOLUTION,
            ExifInterface.TAG_RESOLUTION_UNIT,
            ExifInterface.TAG_EXIF_VERSION,
            ExifInterface.TAG_FLASHPIX_VERSION,
            ExifInterface.TAG_INTEROPERABILITY_INDEX,
            ExifInterface.TAG_GPS_VERSION_ID,
            ExifInterface.TAG_GPS_LATITUDE_REF,
            ExifInterface.TAG_GPS_LATITUDE,
            ExifInterface.TAG_GPS_LONGITUDE_REF,
            ExifInterface.TAG_GPS_LONGITUDE,
            ExifInterface.TAG_GPS_ALTITUDE_REF,
            ExifInterface.TAG_GPS_ALTITUDE,
            ExifInterface.TAG_GPS_TIMESTAMP,
            ExifInterface.TAG_GPS_DATESTAMP,
            ExifInterface.TAG_GPS_SATELLITES,
            ExifInterface.TAG_GPS_STATUS,
            ExifInterface.TAG_GPS_MEASURE_MODE,
            ExifInterface.TAG_GPS_DOP,
            ExifInterface.TAG_GPS_SPEED_REF,
            ExifInterface.TAG_GPS_SPEED,
            ExifInterface.TAG_GPS_TRACK_REF,
            ExifInterface.TAG_GPS_TRACK,
            ExifInterface.TAG_GPS_IMG_DIRECTION_REF,
            ExifInterface.TAG_GPS_IMG_DIRECTION,
            ExifInterface.TAG_GPS_MAP_DATUM,
            ExifInterface.TAG_GPS_DEST_LATITUDE_REF,
            ExifInterface.TAG_GPS_DEST_LATITUDE,
            ExifInterface.TAG_GPS_DEST_LONGITUDE_REF,
            ExifInterface.TAG_GPS_DEST_LONGITUDE,
            ExifInterface.TAG_GPS_DEST_BEARING_REF,
            ExifInterface.TAG_GPS_DEST_BEARING,
            ExifInterface.TAG_GPS_DEST_DISTANCE_REF,
            ExifInterface.TAG_GPS_DEST_DISTANCE,
            ExifInterface.TAG_GPS_PROCESSING_METHOD,
            ExifInterface.TAG_GPS_AREA_INFORMATION,
            ExifInterface.TAG_GPS_DIFFERENTIAL,
            ExifInterface.TAG_GPS_H_POSITIONING_ERROR,
        )

        @Volatile
        var isRunning: Boolean = false
            private set
    }
}
