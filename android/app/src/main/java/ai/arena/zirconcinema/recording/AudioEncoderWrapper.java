package ai.arena.zirconcinema.recording;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.AudioTimestamp;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaRecorder;
import android.os.Build;
import android.util.Log;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Wraps AudioRecord + MediaCodec for AAC audio encoding.
 * 
 * Phase 1: Basic audio capture and encoding with proper timestamps.
 */
public class AudioEncoderWrapper {
    private static final String TAG = "AudioEncoderWrapper";
    
    private static final int SAMPLE_RATE = 48000;
    private static final int CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_STEREO;
    private static final int AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT;
    private static final int BIT_RATE = 192000; // 192 kbps AAC
    
    private AudioRecord audioRecord;
    private MediaCodec audioEncoder;
    private MediaCodec.BufferInfo outputBufferInfo;
    
    private Thread audioInputThread;
    private final AtomicBoolean isRunning = new AtomicBoolean(false);
    private final AtomicInteger samplesCaptured = new AtomicInteger(0);
    private final AtomicInteger audioChunksEncoded = new AtomicInteger(0);
    
    private final TimestampManager timestampManager;
    
    public AudioEncoderWrapper(TimestampManager timestampManager) {
        this.timestampManager = timestampManager;
        Log.i(TAG, "Audio encoder wrapper created");
    }
    
    /**
     * Configure and start audio recording + encoding.
     * 
     * @throws IOException if setup fails
     */
    public void start() throws IOException {
        if (isRunning.get()) {
            throw new IllegalStateException("Audio encoder already started");
        }
        
        // Create AudioRecord
        int bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT);
        if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
            throw new IOException("Invalid audio buffer size");
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioRecord = new AudioRecord.Builder()
                    .setAudioSource(MediaRecorder.AudioSource.MIC)
                    .setAudioFormat(new AudioFormat.Builder()
                            .setSampleRate(SAMPLE_RATE)
                            .setChannelMask(CHANNEL_CONFIG)
                            .setEncoding(AUDIO_FORMAT)
                            .build())
                    .setBufferSizeInBytes(bufferSize * 2) // Extra buffering
                    .build();
        } else {
            audioRecord = new AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE,
                    CHANNEL_CONFIG,
                    AUDIO_FORMAT,
                    bufferSize * 2);
        }
        
        if (audioRecord.getState() != AudioRecord.STATE_INITIALIZED) {
            throw new IOException("AudioRecord initialization failed");
        }
        
        // Create AAC encoder
        MediaFormat audioFormat = new MediaFormat();
        audioFormat.setString(MediaFormat.KEY_MIME, "audio/mp4a-latm");
        audioFormat.setInteger(MediaFormat.KEY_SAMPLE_RATE, SAMPLE_RATE);
        audioFormat.setInteger(MediaFormat.KEY_CHANNEL_COUNT, 2);
        audioFormat.setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE);
        audioFormat.setInteger(MediaFormat.KEY_AAC_PROFILE,
                MediaCodecInfo.CodecProfileLevel.AACObjectLC);
        
        Log.i(TAG, "Creating AAC encoder with format: " + audioFormat);
        
        audioEncoder = MediaCodec.createEncoderByType("audio/mp4a-latm");
        audioEncoder.configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        audioEncoder.start();
        
        outputBufferInfo = new MediaCodec.BufferInfo();
        
        // Start recording
        audioRecord.startRecording();
        isRunning.set(true);
        
        // Start audio input thread
        audioInputThread = new Thread(this::audioInputLoop, "AudioInputThread");
        audioInputThread.start();
        
        Log.i(TAG, "Audio encoder started successfully");
    }
    
    /**
     * Audio input loop - reads from AudioRecord and feeds to encoder.
     */
    private void audioInputLoop() {
        Log.i(TAG, "Audio input thread started");
        
        // AAC frame is 1024 samples per channel
        int frameSize = 1024 * 2 * 2; // 1024 samples * 2 channels * 2 bytes per sample (PCM16)
        byte[] audioBuffer = new byte[frameSize];
        
        while (isRunning.get()) {
            int bytesRead = audioRecord.read(audioBuffer, 0, frameSize);
            
            if (bytesRead > 0) {
                // Get audio timestamp
                long timestampUs = -1;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    AudioTimestamp timestamp = new AudioTimestamp();
                    int result = audioRecord.getTimestamp(
                            timestamp, AudioTimestamp.TIMEBASE_BOOTTIME);
                    if (result == AudioRecord.SUCCESS) {
                        timestampUs = timestamp.nanoTime / 1000; // ns → µs
                    }
                }
                
                if (timestampUs < 0) {
                    // Fallback: estimate from sample count
                    timestampUs = (samplesCaptured.get() * 1000000L) / SAMPLE_RATE;
                }
                
                // Register with timestamp manager
                long ptsUs = timestampManager.registerAudioChunk(timestampUs);
                
                // Feed to encoder
                feedEncoder(audioBuffer, bytesRead, ptsUs);
                
                samplesCaptured.addAndGet(bytesRead / 4); // 4 bytes per stereo sample
                
                int sampleCount = samplesCaptured.get();
                if (sampleCount <= 48000 || sampleCount % 480000 == 0) { // Log first second and every 10 seconds
                    Log.d(TAG, "Audio samples captured: " + sampleCount + 
                          " (" + (sampleCount / SAMPLE_RATE) + " seconds)");
                }
            } else if (bytesRead < 0) {
                Log.e(TAG, "AudioRecord read error: " + bytesRead);
                break;
            }
        }
        
        Log.i(TAG, "Audio input thread stopped");
    }
    
    /**
     * Feed audio data to encoder.
     */
    private void feedEncoder(byte[] data, int size, long presentationTimeUs) {
        if (audioEncoder == null) return;
        
        int inputIndex = audioEncoder.dequeueInputBuffer(10000); // 10ms timeout
        if (inputIndex >= 0) {
            ByteBuffer inputBuffer = audioEncoder.getInputBuffer(inputIndex);
            if (inputBuffer != null) {
                inputBuffer.clear();
                inputBuffer.put(data, 0, size);
                audioEncoder.queueInputBuffer(inputIndex, 0, size, presentationTimeUs, 0);
            }
        } else {
            Log.w(TAG, "Audio encoder input buffer not available");
        }
    }
    
    /**
     * Drain encoded audio output.
     * Call this repeatedly from a dedicated thread.
     * 
     * @param muxer MuxerController to write encoded data
     * @param trackIndex Muxer track index for audio
     * @return true if encoder is still running, false if EOS
     */
    public boolean drainOutput(MuxerController muxer, int trackIndex) {
        if (audioEncoder == null || !isRunning.get()) {
            return false;
        }
        
        int outputIndex = audioEncoder.dequeueOutputBuffer(outputBufferInfo, 10000);
        
        if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
            MediaFormat outputFormat = audioEncoder.getOutputFormat();
            Log.i(TAG, "Audio encoder output format changed: " + outputFormat);
            // Muxer will handle this
            return true;
        }
        
        if (outputIndex >= 0) {
            ByteBuffer outputBuffer = audioEncoder.getOutputBuffer(outputIndex);
            
            if (outputBuffer != null && outputBufferInfo.size > 0) {
                muxer.writeSampleData(trackIndex, outputBuffer, outputBufferInfo);
                
                int chunkCount = audioChunksEncoded.incrementAndGet();
                if (chunkCount <= 5 || chunkCount % 100 == 0) {
                    Log.d(TAG, "Audio chunk #" + chunkCount + 
                          " PTS: " + outputBufferInfo.presentationTimeUs + " µs" +
                          " Size: " + outputBufferInfo.size + " bytes");
                }
            }
            
            audioEncoder.releaseOutputBuffer(outputIndex, false);
            
            if ((outputBufferInfo.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                Log.i(TAG, "Audio encoder reached end of stream");
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * Stop and release audio resources.
     */
    public void stop() {
        if (!isRunning.get()) return;
        
        Log.i(TAG, "Stopping audio encoder");
        isRunning.set(false);
        
        // Wait for audio input thread
        if (audioInputThread != null) {
            try {
                audioInputThread.join(2000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
        
        // Stop AudioRecord
        if (audioRecord != null) {
            audioRecord.stop();
            audioRecord.release();
            audioRecord = null;
        }
        
        // Stop encoder
        if (audioEncoder != null) {
            try {
                audioEncoder.stop();
            } catch (IllegalStateException e) {
                Log.w(TAG, "Audio encoder stop failed: " + e.getMessage());
            }
            audioEncoder.release();
            audioEncoder = null;
        }
        
        Log.i(TAG, "Audio encoder stopped");
    }
    
    /**
     * Get samples captured count.
     */
    public int getSamplesCaptured() {
        return samplesCaptured.get();
    }
    
    /**
     * Get audio chunks encoded count.
     */
    public int getAudioChunksEncoded() {
        return audioChunksEncoded.get();
    }
    
    /**
     * Get encoder output format.
     * Only valid after encoder is started and format has changed.
     */
    public MediaFormat getOutputFormat() {
        if (audioEncoder != null) {
            try {
                return audioEncoder.getOutputFormat();
            } catch (IllegalStateException e) {
                return null;
            }
        }
        return null;
    }
    
    /**
     * Log audio statistics.
     */
    public void logStats() {
        int samples = samplesCaptured.get();
        int chunks = audioChunksEncoded.get();
        
        Log.i(TAG, "Audio encoder stats:");
        Log.i(TAG, "  Samples captured: " + samples + " (" + (samples / SAMPLE_RATE) + " seconds)");
        Log.i(TAG, "  AAC chunks encoded: " + chunks);
    }
}
