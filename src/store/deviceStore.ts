import { create } from 'zustand';

export type DeviceSide = 'L' | 'R';
export type ConnectionState = 'disconnected' | 'connecting' | 'connected';
export type SessionState = 'idle' | 'running' | 'paused';
export type PumpMode = 'stimulate' | 'deep' | 'mixed';

export interface DeviceState {
  id: string;
  side: DeviceSide;
  connectionState: ConnectionState;
  battery: number;
  signalStrength: '强' | '良' | '弱' | '无';
  model: string;
  flangeSize: number;
  sealSize: string;
  sessionState: SessionState;
  currentMode: PumpMode;
  currentLevel: number;
}

interface DeviceStore {
  leftDevice: DeviceState;
  rightDevice: DeviceState;

  // Actions
  connectDevice: (side: DeviceSide) => Promise<void>;
  disconnectDevice: (side: DeviceSide) => void;
  startSession: (side: DeviceSide) => void;
  pauseSession: (side: DeviceSide) => void;
  stopSession: (side: DeviceSide) => void;
  setMode: (side: DeviceSide, mode: PumpMode) => void;
  setLevel: (side: DeviceSide, level: number) => void;
}

const initialDeviceState = (side: DeviceSide): DeviceState => ({
  id: side === 'L' ? 'd1' : 'd2',
  side,
  connectionState: 'disconnected',
  battery: side === 'L' ? 78 : 65,
  signalStrength: '无',
  model: 'Air One',
  flangeSize: 24,
  sealSize: 'M',
  sessionState: 'idle',
  currentMode: 'stimulate',
  currentLevel: 1,
});

export const useDeviceStore = create<DeviceStore>((set) => ({
  leftDevice: initialDeviceState('L'),
  rightDevice: initialDeviceState('R'),

  connectDevice: async (side: DeviceSide) => {
    const deviceKey = side === 'L' ? 'leftDevice' : 'rightDevice';

    // Set to connecting
    set((state) => ({
      [deviceKey]: { ...state[deviceKey], connectionState: 'connecting' }
    }));

    // Mock connection delay
    await new Promise((resolve) => setTimeout(resolve, 1500));

    // Set to connected
    set((state) => ({
      [deviceKey]: {
        ...state[deviceKey],
        connectionState: 'connected',
        signalStrength: side === 'L' ? '强' : '良'
      }
    }));
  },

  disconnectDevice: (side: DeviceSide) => {
    const deviceKey = side === 'L' ? 'leftDevice' : 'rightDevice';
    set((state) => ({
      [deviceKey]: {
        ...state[deviceKey],
        connectionState: 'disconnected',
        signalStrength: '无',
        sessionState: 'idle'
      }
    }));
  },

  startSession: (side: DeviceSide) => {
    const deviceKey = side === 'L' ? 'leftDevice' : 'rightDevice';
    set((state) => ({
      [deviceKey]: { ...state[deviceKey], sessionState: 'running' }
    }));
  },

  pauseSession: (side: DeviceSide) => {
    const deviceKey = side === 'L' ? 'leftDevice' : 'rightDevice';
    set((state) => ({
      [deviceKey]: { ...state[deviceKey], sessionState: 'paused' }
    }));
  },

  stopSession: (side: DeviceSide) => {
    const deviceKey = side === 'L' ? 'leftDevice' : 'rightDevice';
    set((state) => ({
      [deviceKey]: { ...state[deviceKey], sessionState: 'idle' }
    }));
  },

  setMode: (side: DeviceSide, mode: PumpMode) => {
    const deviceKey = side === 'L' ? 'leftDevice' : 'rightDevice';
    set((state) => ({
      [deviceKey]: { ...state[deviceKey], currentMode: mode }
    }));
  },

  setLevel: (side: DeviceSide, level: number) => {
    const deviceKey = side === 'L' ? 'leftDevice' : 'rightDevice';
    set((state) => ({
      [deviceKey]: { ...state[deviceKey], currentLevel: Math.max(1, Math.min(9, level)) }
    }));
  }
}));
