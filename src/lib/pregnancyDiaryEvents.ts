export const PREGNANCY_DIARY_CHANGED_EVENT = "momcozy-pregnancy-diary-changed";

export function notifyPregnancyDiaryChanged(): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent(PREGNANCY_DIARY_CHANGED_EVENT));
}

export function subscribePregnancyDiaryChanged(callback: () => void): () => void {
  if (typeof window === "undefined") return () => {};
  window.addEventListener(PREGNANCY_DIARY_CHANGED_EVENT, callback);
  return () => window.removeEventListener(PREGNANCY_DIARY_CHANGED_EVENT, callback);
}
