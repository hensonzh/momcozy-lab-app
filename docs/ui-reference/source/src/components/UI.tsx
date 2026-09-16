import type { ButtonHTMLAttributes, ReactNode } from 'react'

export function Icon({ name }: { name: string }) {
  const paths: Record<string, string> = {
    grid: 'M5 3h4a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Zm10 0h4a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2ZM5 13h4a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2Zm10 0h4a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2Z',
    'chevron-right': 'm9 5 7 7-7 7',
    home: 'M3 10.5 12 3l9 7.5M5.5 9v10h13V9M9 19v-5h6v5', baby: 'M12 4a3 3 0 1 0 0 6 3 3 0 0 0 0-6ZM5 21c.7-4 3-6 7-6s6.3 2 7 6',
    spark: 'm12 2 1.6 6.4L20 10l-6.4 1.6L12 18l-1.6-6.4L4 10l6.4-1.6L12 2ZM19 16v6M16 19h6', plan: 'M5 4h14v16H5zM8 8h8M8 12h8M8 16h5', more: 'M5 12h.01M12 12h.01M19 12h.01', arrow: 'M5 12h14M13 6l6 6-6 6', 'chevron-down': 'm7 9 5 5 5-5', back: 'M19 12H5M11 6l-6 6 6 6', check: 'm5 12 4 4L19 6', clock: 'M12 7v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0', video: 'M4 7h11v10H4zM15 10l5-3v10l-5-3', mic: 'M9 5a3 3 0 0 1 6 0v7a3 3 0 0 1-6 0V5ZM5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8', shield: 'M12 3 20 6v5c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6l8-3Z', users: 'M8.5 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM3.5 20c.4-3.3 2.2-5 5-5s4.6 1.7 5 5M16 11a2.5 2.5 0 1 0 0-5M15.5 15c2.8 0 4.6 1.7 5 5', search: 'm20 20-4.5-4.5M10.5 17a6.5 6.5 0 1 1 0-13 6.5 6.5 0 0 1 0 13', filter: 'M4 6h16M7 12h10M10 18h4', calendar: 'M5 4h14v16H5zM8 2v4M16 2v4M5 9h14', note: 'M6 3h12v18H6zM9 8h6M9 12h6M9 16h4', send: 'm4 4 16 8-16 8 3-8-3-8ZM7 12h13', play: 'm8 5 11 7-11 7V5Z', lock: 'M7 10V8a5 5 0 0 1 10 0v2M5 10h14v10H5z', menu: 'M4 7h16M4 12h16M4 17h16', bell: 'M6 17h12l-1.5-2v-4a4.5 4.5 0 0 0-9 0v4L6 17ZM10 20h4', drop: 'M12 2.8S6.5 9.1 6.5 13.3a5.5 5.5 0 0 0 11 0C17.5 9.1 12 2.8 12 2.8Z', heart: 'M20.8 8.8c0 5.1-8.8 10.2-8.8 10.2S3.2 13.9 3.2 8.8A4.8 4.8 0 0 1 12 6.1a4.8 4.8 0 0 1 8.8 2.7Z', moon: 'M20.4 15.2A8.5 8.5 0 0 1 8.8 3.6 8.5 8.5 0 1 0 20.4 15.2Z',
    plus: 'M12 5v14M5 12h14', history: 'M3 12a9 9 0 1 0 3-6.7M3 4v6h6M12 7v5l3 2', stop: 'M8 8h8v8H8z', volume: 'M5 10v4h3l4 4V6L8 10H5Zm10.5-1.5a5 5 0 0 1 0 7M18 6a9 9 0 0 1 0 12', 'volume-off': 'M5 10v4h3l4 4V6L8 10H5Zm10 2 4 4m0-4-4 4', image: 'M4 5h16v14H4zM7 15l3-3 2 2 2-2 3 3M8.5 9h.01', camera: 'M4 8h3l1.5-2h7L17 8h3v11H4V8Zm8 3a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z', chat: 'M4 5h16v12H9l-5 4V5Z', file: 'M7 3h7l4 4v14H7zM14 3v5h5', wifi: 'M3 8.5a14 14 0 0 1 18 0M6 12a9 9 0 0 1 12 0M9.5 15.5a4 4 0 0 1 5 0M12 19h.01M4 4l16 16'
  }
  return <span className={`icon icon-${name}`} aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d={paths[name] ?? 'M12 12h.01'} /></svg></span>
}

export function Button({ variant = 'primary', size = 'md', children, className = '', ...props }: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'soft'; size?: 'sm' | 'md' | 'lg' }) {
  return <button className={`btn btn-${variant} btn-${size} ${className}`} {...props}>{children}</button>
}

export function Badge({ children, tone = 'neutral' }: { children: ReactNode; tone?: 'neutral' | 'rose' | 'green' | 'amber' | 'blue' | 'red' }) {
  return <span className={`badge badge-${tone}`}>{children}</span>
}

export function Card({ children, className = '', onClick }: { children: ReactNode; className?: string; onClick?: () => void }) {
  return <section className={`card ${onClick ? 'card-clickable' : ''} ${className}`} onClick={onClick} role={onClick ? 'button' : undefined} tabIndex={onClick ? 0 : undefined} onKeyDown={onClick ? (event) => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); onClick() } } : undefined}>{children}</section>
}

export function SectionTitle({ eyebrow, title, action }: { eyebrow?: string; title: string; action?: ReactNode }) {
  return <div className="section-title"><div>{eyebrow && <p className="eyebrow">{eyebrow}</p>}<h2>{title}</h2></div>{action}</div>
}

export function EmptyState({ title, body, action }: { title: string; body: string; action?: ReactNode }) {
  return <div className="empty-state"><h3>{title}</h3><p>{body}</p>{action}</div>
}

export function StatusDot({ tone = 'green' }: { tone?: 'green' | 'amber' | 'red' | 'gray' }) {
  return <span className={`status-dot status-${tone}`} />
}

export function ProgressBar({ value, tone = 'rose' }: { value: number; tone?: 'rose' | 'green' | 'blue' }) {
  return <div className="progress-track"><div className={`progress-fill progress-${tone}`} style={{ width: `${Math.min(100, Math.max(0, value))}%` }} /></div>
}

export function Modal({ title, children, onClose, className = '', showClose = true, closeIcon = false }: { title: string; children: ReactNode; onClose: () => void; className?: string; showClose?: boolean; closeIcon?: boolean }) {
  return <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label={title}><div className={`modal ${className}`}><div className="modal-header"><h3>{title}</h3>{showClose && <Button variant="ghost" size="sm" aria-label={closeIcon ? '关闭' : undefined} onClick={onClose}>{closeIcon ? '×' : '关闭'}</Button>}</div>{children}</div></div>
}
