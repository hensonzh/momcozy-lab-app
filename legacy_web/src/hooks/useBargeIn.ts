import { useRef, useCallback } from "react";

/**
 * Hook to support "barge-in": when the user sends a new message while
 * M.ai is still streaming, cancel pending output and show an interrupted marker.
 */
export function useBargeIn() {
  const refs = useRef<NodeJS.Timeout[]>([]);

  /** Register a setTimeout id so it can be cleared on barge-in */
  const track = useCallback((t: NodeJS.Timeout) => {
    refs.current.push(t);
  }, []);

  /**
   * Cancel all pending streaming timeouts.
   * Returns `true` if there was something to cancel.
   */
  const interrupt = useCallback(() => {
    const had = refs.current.length > 0;
    refs.current.forEach(clearTimeout);
    refs.current = [];
    return had;
  }, []);

  return { track, interrupt };
}
