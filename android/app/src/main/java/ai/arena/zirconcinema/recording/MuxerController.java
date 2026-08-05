package ai.arena.zirconcinema.recording;

import android.media.MediaCodec;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.os.ParcelFileDescriptor;
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
    
    private MediaMuxer muxer;
    private int videoTrackIndex = -1;
    private int audioTrackIndex = -1;
    private boolean muxerStarted = false;
    
    public MuxerController(ParcelFileDescriptor fileDescriptor, boolean requireAudio) throws IOException {
        if (fileDescriptor == null) {
            throw new IllegalArgumentException("FileDescriptor cannot be null");
        }
        muxer = new MediaMuxer(fileDescriptor.getFileDescriptor(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        Log.i(TAG, "Muxer initialized with FileDescriptor");
    }
    
    /**
     * Initialize the muxer (starts writing to file).
     * 
     * @throws IOException if muxer start fails
     */
    public synchronized void start() throws IOException {
        if (muxer == null) {
            throw new IllegalStateException("Muxer not initialized");
        }
        if (muxerStarted) {
            throw new IllegalStateException("Muxer already started");
        }
        
        // Start muxer immediately after video track is added
        // Audio track can be added later if needed
        if (videoTrackIndex >= 0) {
            muxer.start();
            muxerStarted = true;
            Log.i(TAG, "Muxer started with video track");
        }
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
    public int getVideoTrackIndex() {
        return videoTrackIndex;
    }
    
    /**
     * Get audio track index.
     */
    public int getAudioTrackIndex() {
        return audioTrackIndex;
    }
    
    /**
     * Check if muxer is ready to write samples.
     */
    public boolean isReady() {
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
