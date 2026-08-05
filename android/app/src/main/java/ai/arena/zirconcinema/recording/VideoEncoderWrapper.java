package ai.arena.zirconcinema.recording;

import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.os.Build;
import android.util.Log;
import android.view.Surface;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Wraps MediaCodec for HEVC Main10 encoding.
 * 
 * Phase 1: Simple wrapper that accepts P010 frames via Surface input.
 * Future: Add processing pipeline between camera and encoder.
 */
public class VideoEncoderWrapper {
    private static final String TAG = "VideoEncoderWrapper";
    
    private final int width;
    private final int height;
    private final int frameRate;
    private final int bitRate;
    
    private MediaCodec encoder;
    private Surface inputSurface;
    private MediaCodec.BufferInfo outputBufferInfo;
    
    private final AtomicInteger framesEncoded = new AtomicInteger(0);
    private final AtomicInteger bytesWritten = new AtomicInteger(0);
    private final AtomicBoolean isRunning = new AtomicBoolean(false);
    
    public VideoEncoderWrapper(int width, int height, int frameRate, int bitRate) {
        this.width = width;
        this.height = height;
        this.frameRate = frameRate;
        this.bitRate = bitRate;
        
        Log.i(TAG, "Video encoder created: " + width + "x" + height + 
              " @ " + frameRate + "fps, " + (bitRate / 1_000_000) + " Mbps");
    }
    
    /**
     * Configure and start the encoder.
     * 
     * @return Input surface for camera frames
     * @throws IOException if encoder setup fails
     */
    public Surface start() throws IOException {
        if (encoder != null) {
            throw new IllegalStateException("Encoder already started");
        }
        
        // Configure HEVC Main10
        MediaFormat format = MediaFormat.createVideoFormat("video/hevc", width, height);
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface);
        format.setInteger(MediaFormat.KEY_BIT_RATE, bitRate);
        format.setInteger(MediaFormat.KEY_FRAME_RATE, frameRate);
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1); // 1 second GOP
        
        // Set Main10 profile (10-bit)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            format.setInteger(MediaFormat.KEY_PROFILE,
                    MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10);
            format.setInteger(MediaFormat.KEY_LEVEL,
                    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel51);
        }
        
        // Color metadata (BT.709 for now)
        format.setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709);
        format.setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO);
        format.setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED);
        
        Log.i(TAG, "Creating encoder with format: " + format);
        
        encoder = MediaCodec.createEncoderByType("video/hevc");
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        inputSurface = encoder.createInputSurface();
        encoder.start();
        isRunning.set(true);
        
        outputBufferInfo = new MediaCodec.BufferInfo();
        
        Log.i(TAG, "Video encoder started successfully");
        return inputSurface;
    }
    
    /**
     * Drain encoded output buffers.
     * Call this repeatedly from a dedicated thread.
     * 
     * @param muxer MuxerController to write encoded data
     * @param trackIndex Muxer track index for video
     * @param timestampManager TimestampManager for PTS
     * @return true if encoder is still running, false if EOS
     */
    public boolean drainOutput(MuxerController muxer, int trackIndex, TimestampManager timestampManager) {
        if (encoder == null || !isRunning.get()) {
            return false;
        }
        
        int outputIndex = encoder.dequeueOutputBuffer(outputBufferInfo, 10000); // 10ms timeout
        
        if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
            // Format changed - add track to muxer
            MediaFormat outputFormat = encoder.getOutputFormat();
            Log.i(TAG, "Encoder output format changed: " + outputFormat);
            // Muxer will handle this
            return true;
        }
        
        if (outputIndex >= 0) {
            ByteBuffer outputBuffer = encoder.getOutputBuffer(outputIndex);
            
            // Rebase the raw sensor-clock PTS (CLOCK_BOOTTIME domain) onto
            // zero-based clip time before it reaches the muxer.
            outputBufferInfo.presentationTimeUs =
                    timestampManager.rebaseVideoPts(outputBufferInfo.presentationTimeUs);
            
            if (outputBuffer != null && outputBufferInfo.size > 0) {
                // Write to muxer
                muxer.writeSampleData(trackIndex, outputBuffer, outputBufferInfo);
                
                int frameCount = framesEncoded.incrementAndGet();
                bytesWritten.addAndGet(outputBufferInfo.size);
                
                if (frameCount <= 5 || frameCount % 300 == 0) {
                    Log.d(TAG, "Encoded frame #" + frameCount + 
                          " PTS: " + outputBufferInfo.presentationTimeUs + " µs" +
                          " Size: " + outputBufferInfo.size + " bytes");
                }
            }
            
            encoder.releaseOutputBuffer(outputIndex, false);
            
            // Check for EOS
            if ((outputBufferInfo.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                Log.i(TAG, "Encoder reached end of stream");
                isRunning.set(false);
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * Signal end of stream to encoder.
     */
    public void signalEndOfStream() {
        if (encoder != null && isRunning.get()) {
            Log.i(TAG, "Signaling end of stream to encoder");
            encoder.signalEndOfInputStream();
        }
    }
    
    /**
     * Stop and release the encoder.
     */
    public void stop() {
        if (encoder != null) {
            Log.i(TAG, "Stopping video encoder");
            isRunning.set(false);
            
            try {
                encoder.stop();
            } catch (IllegalStateException e) {
                Log.w(TAG, "Encoder stop failed: " + e.getMessage());
            }
            
            encoder.release();
            encoder = null;
            inputSurface = null;
            
            Log.i(TAG, "Video encoder stopped");
        }
    }
    
    /**
     * Get the input surface for camera frames.
     */
    public Surface getInputSurface() {
        return inputSurface;
    }
    
    /**
     * Get encoder output format.
     * Only valid after encoder is started and format has changed.
     */
    public MediaFormat getOutputFormat() {
        if (encoder != null) {
            try {
                return encoder.getOutputFormat();
            } catch (IllegalStateException e) {
                return null;
            }
        }
        return null;
    }
    
    /**
     * Check if encoder is running.
     */
    public boolean isRunning() {
        return isRunning.get();
    }
    
    /**
     * Get encoded frame count.
     */
    public int getFramesEncoded() {
        return framesEncoded.get();
    }
    
    /**
     * Get total bytes written.
     */
    public int getBytesWritten() {
        return bytesWritten.get();
    }
    
    /**
     * Log encoder statistics.
     */
    public void logStats() {
        int frames = framesEncoded.get();
        int bytes = bytesWritten.get();
        
        Log.i(TAG, "Video encoder stats:");
        Log.i(TAG, "  Frames encoded: " + frames);
        Log.i(TAG, "  Total bytes: " + bytes + " (" + (bytes / 1_000_000) + " MB)");
        
        if (frames > 0) {
            double avgBitrate = (bytes * 8.0) / (frames / (double) frameRate);
            Log.i(TAG, "  Average bitrate: " + String.format("%.2f Mbps", avgBitrate / 1_000_000));
        }
    }
}
