import "@testing-library/jest-dom/vitest";

function createMemoryStorage(): Storage {
  const items = new Map<string, string>();
  return {
    get length() {
      return items.size;
    },
    clear() {
      items.clear();
    },
    getItem(key: string) {
      return items.get(String(key)) ?? null;
    },
    key(index: number) {
      return Array.from(items.keys())[index] ?? null;
    },
    removeItem(key: string) {
      items.delete(String(key));
    },
    setItem(key: string, value: string) {
      items.set(String(key), String(value));
    },
  };
}

for (const storageKey of ["localStorage", "sessionStorage"] as const) {
  const storage = createMemoryStorage();
  for (const target of [globalThis, window]) {
    try {
      Object.defineProperty(target, storageKey, {
        value: storage,
        configurable: true,
        writable: true,
      });
    } catch {
      // Keep tests that do not need web storage unaffected if a runtime locks this property.
    }
  }
}
