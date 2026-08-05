package ai.arena.zirconcinema.recording;

import android.media.Image;
import android.util.Log;

import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Bounded frame queue between camera callback and processing thread.
 * 
 * Design:
 * - Camera thread produces P010 frames
 * - Processing thread consumes them
 * - If queue is full, oldest frame is dropped (camera thread never blocks)
 * - Tracks dropped frame count for diagnostics
 */
public class FrameQueue {
    private static final String TAG = "FrameQueue";
    private static final int DEFAULT_CAPACITY = 4; // 4 frames = ~133ms buffer at 30fps
    
    private final ArrayBlockingQueue<Image> queue;
    private final AtomicInteger framesEnqueued = new AtomicInteger(0);
    private final AtomicInteger framesDequeued = new AtomicInteger(0);
    private final AtomicInteger framesDropped = new AtomicInteger(0);
    
    public FrameQueue() {
        this(DEFAULT_CAPACITY);
    }
    
    public FrameQueue(int capacity) {
        queue = new ArrayBlockingQueue<>(capacity);
        Log.i(TAG, "Frame queue created with capacity: " + capacity);
    }
    
    /**
     * Enqueue a frame from camera callback.
     * Non-blocking: if queue is full, oldest frame is dropped.
     * 
     * @param image P010 frame from Camera2
     * @return true if enqueued, false if a frame was dropped
     */
    public boolean enqueue(Image image) {
        if (image == null) {
            return false;
        }
        
        boolean success = queue.offer(image);
        
        if (!success) {
            // Queue is full - drop oldest frame
            Image dropped = queue.poll();
            if (dropped != null) {
                dropped.close();
                framesDropped.incrementAndGet();
                
                int droppedCount = framesDropped.get();
                if (droppedCount <= 5 || droppedCount % 100 == 0) {
                    Log.w(TAG, "Frame dropped (queue full). Total dropped: " + droppedCount);
                }
                
                // Try again after making space
                success = queue.offer(image);
            }
        }
        
        if (success) {
            framesEnqueued.incrementAndGet();
        }
        
        return success;
    }
    
    /**
     * Dequeue a frame for processing.
     * Blocks until a frame is available or timeout expires.
     * 
     * @param timeoutMs Maximum time to wait in milliseconds
     * @return P010 frame, or null if timeout expired
     */
    public Image dequeue(long timeoutMs) {
        try {
            Image image = queue.poll(timeoutMs, TimeUnit.MILLISECONDS);
            if (image != null) {
                framesDequeued.incrementAndGet();
            }
            return image;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return null;
        }
    }
    
    /**
     * Dequeue a frame, blocking indefinitely until one is available.
     * 
     * @return P010 frame
     * @throws InterruptedException if thread is interrupted
     */
    public Image dequeueBlocking() throws InterruptedException {
        Image image = queue.take();
        framesDequeued.incrementAndGet();
        return image;
    }
    
    /**
     * Check if queue is empty.
     */
    public boolean isEmpty() {
        return queue.isEmpty();
    }
    
    /**
     * Get current queue size.
     */
    public int size() {
        return queue.size();
    }
    
    /**
     * Clear all frames from queue and close them.
     */
    public void clear() {
        Image image;
        int cleared = 0;
        while ((image = queue.poll()) != null) {
            image.close();
            cleared++;
        }
        if (cleared > 0) {
            Log.i(TAG, "Cleared " + cleared + " frames from queue");
        }
    }
    
    /**
     * Log queue statistics.
     */
    public void logStats() {
        int enqueued = framesEnqueued.get();
        int dequeued = framesDequeued.get();
        int dropped = framesDropped.get();
        int pending = queue.size();
        
        Log.i(TAG, "Frame queue stats:");
        Log.i(TAG, "  Enqueued: " + enqueued);
        Log.i(TAG, "  Dequeued: " + dequeued);
        Log.i(TAG, "  Dropped: " + dropped);
        Log.i(TAG, "  Pending: " + pending);
        
        if (enqueued > 0) {
            double dropRate = (dropped * 100.0) / enqueued;
            Log.i(TAG, "  Drop rate: " + String.format("%.2f%%", dropRate));
        }
    }
    
    /**
     * Reset statistics counters.
     */
    public void resetStats() {
        framesEnqueued.set(0);
        framesDequeued.set(0);
        framesDropped.set(0);
    }
}
