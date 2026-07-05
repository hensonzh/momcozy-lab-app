export const MILK_RECORDS_CHANGED_EVENT = "momcozy-milk-records-changed";

export interface MilkRecordsChangedDetail {
  user_id?: string;
}

export function notifyMilkRecordsChanged(detail: MilkRecordsChangedDetail = {}): void {
  if (typeof window === "undefined") return;
  try {
    window.dispatchEvent(new CustomEvent<MilkRecordsChangedDetail>(MILK_RECORDS_CHANGED_EVENT, { detail }));
  } catch {
    /* ignore */
  }
}

export function subscribeMilkRecordsChanged(callback: (event: CustomEvent<MilkRecordsChangedDetail>) => void): () => void {
  if (typeof window === "undefined") return () => {};
  const listener = (event: Event) => callback(event as CustomEvent<MilkRecordsChangedDetail>);
  window.addEventListener(MILK_RECORDS_CHANGED_EVENT, listener);
  return () => window.removeEventListener(MILK_RECORDS_CHANGED_EVENT, listener);
}
