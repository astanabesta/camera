package ai.arena.zirconcinema.recording;

import android.util.Log;

/**
 * Manages presentation timestamps (PTS) for audio and video tracks.
 * 
 * Ensures audio and video stay synchronized by tracking:
 * - Base timestamp (first frame/chunk)
 * - Running frame count for video
 * - Running chunk count for audio
 * 
 * Both tracks use CLOCK_MONOTONIC via the camera and AudioRecord.
 */
public class TimestampManager {
    private static final String TAG = "TimestampManager";
    
    private long videoBaseTimestampUs = -1;
    private long audioBaseTimestampUs = -1;
    private int videoFrameCount = 0;
    private int audioChunkCount = 0;
    
    /**
     * Register a video frame timestamp.
     * 
     * @param cameraTimestampNs Camera2 frame timestamp in nanoseconds (CLOCK_MONOTONIC)
     * @return Presentation timestamp in microseconds, relative to video base
     */
    public synchronized long registerVideoFrame(long cameraTimestampNs) {
        long timestampUs = cameraTimestampNs / 1000; // ns → µs
        
        if (videoBaseTimestampUs < 0) {
            videoBaseTimestampUs = timestampUs;
            Log.i(TAG, "Video base timestamp set: " + videoBaseTimestampUs + " µs");
        }
        
        long ptsUs = timestampUs - videoBaseTimestampUs;
        videoFrameCount++;
        
        if (videoFrameCount <= 5 || videoFrameCount % 300 == 0) {
            Log.d(TAG, "Video frame #" + videoFrameCount + " PTS: " + ptsUs + " µs");
        }
        
        return ptsUs;
    }
    
    /**
     * Rebase an encoder-produced video PTS onto zero-based clip time.
     * 
     * With a Surface-input encoder, output buffers carry the camera sensor
     * timestamp (CLOCK_BOOTTIME domain) converted to µs — an absolute clock
     * reading that would otherwise land hours into the file. The first
     * encoded frame becomes PTS 0 so the MP4 starts at t=0.
     * 
     * @param encoderPtsUs Raw PTS from encoder BufferInfo in microseconds
     * @return Zero-based presentation timestamp in microseconds
     */
    public synchronized long rebaseVideoPts(long encoderPtsUs) {
        if (videoBaseTimestampUs < 0) {
            videoBaseTimestampUs = encoderPtsUs;
            Log.i(TAG, "Video base timestamp set (encoder pts): " + videoBaseTimestampUs + " µs");
        }
        
        long ptsUs = encoderPtsUs - videoBaseTimestampUs;
        videoFrameCount++;
        
        if (videoFrameCount <= 5 || videoFrameCount % 300 == 0) {
            Log.d(TAG, "Video frame #" + videoFrameCount + " PTS: " + ptsUs + " µs");
        }
        
        return ptsUs;
    }
    
    /**
     * Absolute video base timestamp (µs, camera clock), or -1 if not set.
     */
    public synchronized long getVideoBaseTimestampUs() {
        return videoBaseTimestampUs;
    }
    
    /**
     * Register an audio chunk timestamp.
     * 
     * @param audioTimestampUs AudioRecord timestamp in microseconds (CLOCK_MONOTONIC)
     * @return Presentation timestamp in microseconds, relative to audio base
     */
    public synchronized long registerAudioChunk(long audioTimestampUs) {
        if (audioBaseTimestampUs < 0) {
            audioBaseTimestampUs = audioTimestampUs;
            Log.i(TAG, "Audio base timestamp set: " + audioBaseTimestampUs + " µs");
        }
        
        long ptsUs = audioTimestampUs - audioBaseTimestampUs;
        audioChunkCount++;
        
        if (audioChunkCount <= 5 || audioChunkCount % 100 == 0) {
            Log.d(TAG, "Audio chunk #" + audioChunkCount + " PTS: " + ptsUs + " µs");
        }
        
        return ptsUs;
    }
    
    /**
     * Get the difference between audio and video base timestamps.
     * Positive = audio started after video, Negative = audio started before video.
     * 
     * @return Offset in microseconds, or -1 if either base is not set
     */
    public synchronized long getAudioVideoOffsetUs() {
        if (videoBaseTimestampUs < 0 || audioBaseTimestampUs < 0) {
            return -1;
        }
        return audioBaseTimestampUs - videoBaseTimestampUs;
    }
    
    public synchronized int getVideoFrameCount() {
        return videoFrameCount;
    }
    
    public synchronized int getAudioChunkCount() {
        return audioChunkCount;
    }
    
    public synchronized void reset() {
        videoBaseTimestampUs = -1;
        audioBaseTimestampUs = -1;
        videoFrameCount = 0;
        audioChunkCount = 0;
        Log.i(TAG, "Timestamp manager reset");
    }
    
    public synchronized void logStats() {
        Log.i(TAG, "Timestamp stats:");
        Log.i(TAG, "  Video frames: " + videoFrameCount);
        Log.i(TAG, "  Audio chunks: " + audioChunkCount);
        if (videoBaseTimestampUs >= 0) {
            Log.i(TAG, "  Video base: " + videoBaseTimestampUs + " µs");
        }
        if (audioBaseTimestampUs >= 0) {
            Log.i(TAG, "  Audio base: " + audioBaseTimestampUs + " µs");
        }
        long offset = getAudioVideoOffsetUs();
        if (offset >= 0) {
            Log.i(TAG, "  A/V offset: " + offset + " µs (" + (offset / 1000.0) + " ms)");
        }
    }
}
