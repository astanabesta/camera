package ai.arena.zirconcinema.recording;

import android.media.MediaCodec;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.os.ParcelFileDescriptor;
import android.os.SystemClock;
import android.util.Log;

import java.io.IOException;
import java.nio.ByteBuffer;

/**
 * Wraps MediaMuxer for MP4 file creation.
 * 
 * Handles:
 * - Adding video and audio tracks
 * - Writing encoded samples with proper timestamps
 * - Starting/stopping muxer at correct lifecycle points
 */
public class MuxerController {
    private static final String TAG = "MuxerController";
    
    /** How long to wait for the audio track before starting video-only. */
    private static final long AUDIO_TRACK_WAIT_MS = 1500;
    
    private MediaMuxer muxer;
    private int videoTrackIndex = -1;
    private int audioTrackIndex = -1;
    private boolean muxerStarted = false;
    private boolean requireAudio;
    private long audioTrackDeadlineMs = -1;
    
    public MuxerController(ParcelFileDescriptor fileDescriptor, boolean requireAudio) throws IOException {
        if (fileDescriptor == null) {
            throw new IllegalArgumentException("FileDescriptor cannot be null");
        }
        this.requireAudio = requireAudio;
        muxer = new MediaMuxer(fileDescriptor.getFileDescriptor(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        Log.i(TAG, "Muxer initialized with FileDescriptor");
    }
    
    /**
     * Start the muxer when all expected tracks have been added.
     * 
     * MediaMuxer rejects addTrack() after start(), so starting early and
     * adding the audio track later would crash. This method is a no-op until
     * the video track exists AND (the audio track exists OR the audio wait
     * deadline expires). Call it after every addTrack and periodically from
     * a drain loop so the deadline path can fire.
     * 
     * @throws IOException if the muxer fails to start
     */
    public synchronized void maybeStart() throws IOException {
        if (muxer == null) {
            throw new IllegalStateException("Muxer not initialized");
        }
        if (muxerStarted) {
            return;
        }
        if (videoTrackIndex < 0) {
            return; // Video track is mandatory.
        }
        if (requireAudio && audioTrackIndex < 0) {
            if (audioTrackDeadlineMs < 0) {
                audioTrackDeadlineMs = SystemClock.uptimeMillis() + AUDIO_TRACK_WAIT_MS;
            }
            if (SystemClock.uptimeMillis() < audioTrackDeadlineMs) {
                return; // Audio track is still expected; keep waiting.
            }
            Log.w(TAG, "Audio track not available within " + AUDIO_TRACK_WAIT_MS +
                  " ms; starting muxer video-only");
            requireAudio = false;
        }
        
        muxer.start();
        muxerStarted = true;
        Log.i(TAG, "Muxer started (videoTrack=" + videoTrackIndex +
              ", audioTrack=" + (audioTrackIndex >= 0 ? audioTrackIndex : "none") + ")");
    }
    
    /**
     * Check whether the audio track is still expected before start.
     * Drain loops can use this to prioritize adding the audio track.
     */
    public synchronized boolean isAwaitingAudioTrack() {
        return !muxerStarted && requireAudio && audioTrackIndex < 0;
    }
    
    /**
     * Add video track to muxer.
     * Call this when video encoder format changes.
     * 
     * @param format Video output format from encoder
     * @return Track index
     */
    public synchronized int addVideoTrack(MediaFormat format) {
        if (muxer == null) {
            throw new IllegalStateException("Muxer not initialized");
        }
        if (videoTrackIndex >= 0) {
            Log.w(TAG, "Video track already added at index " + videoTrackIndex);
            return videoTrackIndex;
        }
        
        videoTrackIndex = muxer.addTrack(format);
        Log.i(TAG, "Video track added at index " + videoTrackIndex);
        
        return videoTrackIndex;
    }
    
    /**
     * Add audio track to muxer.
     * Call this when audio encoder format changes.
     * 
     * @param format Audio output format from encoder
     * @return Track index
     */
    public synchronized int addAudioTrack(MediaFormat format) {
        if (muxer == null) {
            throw new IllegalStateException("Muxer not initialized");
        }
        if (audioTrackIndex >= 0) {
            Log.w(TAG, "Audio track already added at index " + audioTrackIndex);
            return audioTrackIndex;
        }
        
        audioTrackIndex = muxer.addTrack(format);
        Log.i(TAG, "Audio track added at index " + audioTrackIndex);
        
        return audioTrackIndex;
    }
    
    /**
     * Write sample data to muxer.
     * 
     * @param trackIndex Track index (video or audio)
     * @param buffer Encoded data buffer
     * @param bufferInfo Buffer metadata (PTS, flags, size)
     */
    public synchronized void writeSampleData(int trackIndex, ByteBuffer buffer, MediaCodec.BufferInfo bufferInfo) {
        if (muxer == null || !muxerStarted) {
            Log.w(TAG, "Cannot write sample - muxer not ready");
            return;
        }
        
        try {
            buffer.position(bufferInfo.offset);
            buffer.limit(bufferInfo.offset + bufferInfo.size);
            muxer.writeSampleData(trackIndex, buffer, bufferInfo);
        } catch (Exception e) {
            Log.e(TAG, "Failed to write sample data: " + e.getMessage());
        }
    }
    
    /**
     * Stop and release the muxer.
     */
    public synchronized void stop() {
        if (muxer != null) {
            Log.i(TAG, "Stopping muxer");
            
            try {
                if (muxerStarted) {
                    muxer.stop();
                    Log.i(TAG, "Muxer stopped");
                }
            } catch (IllegalStateException e) {
                Log.w(TAG, "Muxer stop failed: " + e.getMessage());
            }
            
            try {
                muxer.release();
                Log.i(TAG, "Muxer released");
            } catch (Exception e) {
                Log.w(TAG, "Muxer release failed: " + e.getMessage());
            }
            
            muxer = null;
            videoTrackIndex = -1;
            audioTrackIndex = -1;
            muxerStarted = false;
        }
    }
    
    /**
     * Get video track index.
     */
    public synchronized int getVideoTrackIndex() {
        return videoTrackIndex;
    }
    
    /**
     * Get audio track index.
     */
    public synchronized int getAudioTrackIndex() {
        return audioTrackIndex;
    }
    
    /**
     * Check if muxer is ready to write samples.
     */
    public synchronized boolean isReady() {
        return muxer != null && muxerStarted;
    }
    
    /**
     * Log muxer state.
     */
    public void logStats() {
        Log.i(TAG, "Muxer stats:");
        Log.i(TAG, "  Video track: " + (videoTrackIndex >= 0 ? videoTrackIndex : "not added"));
        Log.i(TAG, "  Audio track: " + (audioTrackIndex >= 0 ? audioTrackIndex : "not added"));
        Log.i(TAG, "  Muxer started: " + muxerStarted);
    }
}
