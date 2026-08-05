package ai.arena.zirconcinema.recording;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.media.MediaFormat;
import android.net.Uri;
import android.os.Environment;
import android.os.ParcelFileDescriptor;
import android.provider.MediaStore;
import android.util.Log;
import android.view.Surface;

import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Manual recording engine that replaces MediaRecorder.
 * 
 * Pipeline:
 * Camera2 P010 → FrameQueue → VideoEncoder → Muxer → MP4
 * AudioRecord → AudioEncoder → Muxer
 * 
 * Phase 1: Basic 4K HEVC Main10 with synced AAC audio.
 */
public class ManualRecordingEngine {
    private static final String TAG = "ManualRecordingEngine";
    
    private final Context context;
    private final int width;
    private final int height;
    private final int frameRate;
    private final int bitRate;
    
    private VideoEncoderWrapper videoEncoder;
    private AudioEncoderWrapper audioEncoder;
    private MuxerController muxer;
    private TimestampManager timestampManager;
    private FrameQueue frameQueue;
    
    private Surface cameraOutputSurface;
    private Uri recordingUri;
    private ParcelFileDescriptor recordingFd;
    
    private Thread videoDrainThread;
    private Thread audioDrainThread;
    
    private final AtomicBoolean isRecording = new AtomicBoolean(false);
    
    public ManualRecordingEngine(Context context, int width, int height, int frameRate, int bitRate) {
        this.context = context;
        this.width = width;
        this.height = height;
        this.frameRate = frameRate;
        this.bitRate = bitRate;
        
        Log.i(TAG, "Manual recording engine created: " + width + "x" + height + 
              " @ " + frameRate + "fps, " + (bitRate / 1_000_000) + " Mbps");
    }
    
    /**
     * Start recording.
     * 
     * @return Surface for camera frames
     * @throws IOException if setup fails
     */
    public Surface start() throws IOException {
        if (isRecording.get()) {
            throw new IllegalStateException("Already recording");
        }
        
        Log.i(TAG, "Starting manual recording...");
        
        // Initialize components
        timestampManager = new TimestampManager();
        frameQueue = new FrameQueue();
        
        // Create output file
        recordingUri = createOutputFile();
        recordingFd = context.getContentResolver().openFileDescriptor(recordingUri, "rw");
        
        // Initialize muxer with FileDescriptor (not path string)
        muxer = new MuxerController(recordingFd, true);
        
        // Initialize video encoder
        videoEncoder = new VideoEncoderWrapper(width, height, frameRate, bitRate);
        cameraOutputSurface = videoEncoder.start();
        
        // Initialize audio encoder
        audioEncoder = new AudioEncoderWrapper(timestampManager);
        audioEncoder.start();
        
        // Start drain threads
        startDrainThreads();
        
        isRecording.set(true);
        
        Log.i(TAG, "Manual recording started successfully");
        Log.i(TAG, "Output file: " + recordingUri);
        
        return cameraOutputSurface;
    }
    
    /**
     * Stop recording.
     */
    public void stop() {
        if (!isRecording.get()) {
            Log.w(TAG, "Not recording");
            return;
        }
        
        Log.i(TAG, "Stopping manual recording...");
        isRecording.set(false);
        
        // Signal end of stream to encoders
        if (videoEncoder != null) {
            videoEncoder.signalEndOfStream();
        }
        
        // Wait for drain threads to finish
        stopDrainThreads();
        
        // Stop encoders
        if (audioEncoder != null) {
            audioEncoder.stop();
        }
        if (videoEncoder != null) {
            videoEncoder.stop();
        }
        
        // Stop muxer
        if (muxer != null) {
            muxer.stop();
        }
        
        // Close file descriptor
        if (recordingFd != null) {
            try {
                recordingFd.close();
            } catch (IOException e) {
                Log.w(TAG, "Failed to close file descriptor: " + e.getMessage());
            }
        }
        
        // Mark file as ready in MediaStore
        if (recordingUri != null) {
            markFileReady(recordingUri);
        }
        
        // Log final stats
        logFinalStats();
        
        // Clean up
        frameQueue.clear();
        timestampManager.reset();
        
        cameraOutputSurface = null;
        
        Log.i(TAG, "Manual recording stopped");
    }
    
    /**
     * Start drain threads for video and audio encoders.
     */
    private void startDrainThreads() {
        // Video drain thread (regular Thread, not HandlerThread)
        videoDrainThread = new Thread(this::videoDrainLoop, "VideoDrainThread");
        videoDrainThread.start();
        
        // Audio drain thread (regular Thread, not HandlerThread)
        audioDrainThread = new Thread(this::audioDrainLoop, "AudioDrainThread");
        audioDrainThread.start();
        
        Log.i(TAG, "Drain threads started");
    }
    
    /**
     * Stop drain threads.
     */
    private void stopDrainThreads() {
        if (videoDrainThread != null) {
            videoDrainThread.interrupt();
            try {
                videoDrainThread.join(2000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            videoDrainThread = null;
        }
        
        if (audioDrainThread != null) {
            audioDrainThread.interrupt();
            try {
                audioDrainThread.join(2000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            audioDrainThread = null;
        }
        
        Log.i(TAG, "Drain threads stopped");
    }
    
    /**
     * Video drain loop - runs on dedicated thread.
     */
    private void videoDrainLoop() {
        Log.i(TAG, "Video drain loop started");
        
        int videoTrackIndex = -1;
        
        while (isRecording.get() || (videoEncoder != null && videoEncoder.isRunning())) {
            // Check if video track needs to be added
            if (videoTrackIndex < 0 && videoEncoder != null) {
                MediaFormat outputFormat = videoEncoder.getOutputFormat();
                if (outputFormat != null) {
                    videoTrackIndex = muxer.addVideoTrack(outputFormat);
                    Log.i(TAG, "Video track added to muxer at index " + videoTrackIndex);
                    
                    // Start muxer now that video track is added
                    try {
                        muxer.start();
                        Log.i(TAG, "Muxer started after adding video track");
                    } catch (IOException e) {
                        Log.e(TAG, "Failed to start muxer: " + e.getMessage());
                        break;
                    }
                }
            }
            
            // Drain encoder output
            if (videoEncoder != null && videoTrackIndex >= 0) {
                boolean running = videoEncoder.drainOutput(muxer, videoTrackIndex, timestampManager);
                if (!running) {
                    break;
                }
            }
            
            // Small delay to prevent busy-waiting
            try {
                Thread.sleep(1);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        
        Log.i(TAG, "Video drain loop stopped");
    }
    
    /**
     * Audio drain loop - runs on dedicated thread.
     */
    private void audioDrainLoop() {
        Log.i(TAG, "Audio drain loop started");
        
        int audioTrackIndex = -1;
        
        while (isRecording.get()) {
            // Check if audio track needs to be added
            if (audioTrackIndex < 0 && audioEncoder != null) {
                MediaFormat outputFormat = audioEncoder.getOutputFormat();
                if (outputFormat != null) {
                    audioTrackIndex = muxer.addAudioTrack(outputFormat);
                    Log.i(TAG, "Audio track added to muxer at index " + audioTrackIndex);
                }
            }
            
            // Drain encoder output
            if (audioEncoder != null && audioTrackIndex >= 0) {
                boolean running = audioEncoder.drainOutput(muxer, audioTrackIndex);
                if (!running) {
                    break;
                }
            }
            
            // Small delay to prevent busy-waiting
            try {
                Thread.sleep(1);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        
        Log.i(TAG, "Audio drain loop stopped");
    }
    
    /**
     * Get the camera output surface.
     * Camera2 should be configured to write frames to this surface.
     */
    public Surface getCameraOutputSurface() {
        return cameraOutputSurface;
    }
    
    /**
     * Register a video frame timestamp.
     * Call this from camera capture callback when a frame is captured.
     * 
     * @param timestampNs Camera frame timestamp in nanoseconds
     */
    public void registerVideoFrameTimestamp(long timestampNs) {
        if (timestampManager != null) {
            timestampManager.registerVideoFrame(timestampNs);
        }
    }
    
    /**
     * Create output file in MediaStore.
     */
    private Uri createOutputFile() throws IOException {
        ContentResolver resolver = context.getContentResolver();
        ContentValues values = new ContentValues();
        
        String timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
        String mode = width + "x" + height + "_" + frameRate + "fps_" + (bitRate / 1_000_000) + "Mbps";
        
        values.put(MediaStore.Video.Media.DISPLAY_NAME, "ZC_MANUAL_" + timestamp + "_" + mode + "_HEVC.mp4");
        values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
        values.put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/ZirconCinema");
        values.put(MediaStore.Video.Media.IS_PENDING, 1);
        
        Uri uri = resolver.insert(MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values);
        if (uri == null) {
            throw new IOException("MediaStore insert returned null");
        }
        
        return uri;
    }
    
    /**
     * Mark file as ready in MediaStore.
     */
    private void markFileReady(Uri uri) {
        try {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Video.Media.IS_PENDING, 0);
            context.getContentResolver().update(uri, values, null, null);
            Log.i(TAG, "File marked as ready: " + uri);
        } catch (Exception e) {
            Log.w(TAG, "Failed to mark file as ready: " + e.getMessage());
        }
    }
    
    /**
     * Log final statistics.
     */
    private void logFinalStats() {
        Log.i(TAG, "===== RECORDING STATISTICS =====");
        
        if (videoEncoder != null) {
            videoEncoder.logStats();
        }
        
        if (audioEncoder != null) {
            audioEncoder.logStats();
        }
        
        if (muxer != null) {
            muxer.logStats();
        }
        
        timestampManager.logStats();
        frameQueue.logStats();
        
        Log.i(TAG, "================================");
    }
    
    /**
     * Check if recording is active.
     */
    public boolean isRecording() {
        return isRecording.get();
    }
    
    /**
     * Get recording URI.
     */
    public Uri getRecordingUri() {
        return recordingUri;
    }
}
