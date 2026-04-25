import clsx from 'clsx';

type StatusBadgeProps = {
  label: string;
  tone?: 'blue' | 'green' | 'amber' | 'red' | 'slate';
};

const tones = {
  blue: 'bg-blue-50 text-blue-700 ring-blue-200',
  green: 'bg-emerald-50 text-emerald-700 ring-emerald-200',
  amber: 'bg-amber-50 text-amber-700 ring-amber-200',
  red: 'bg-rose-50 text-rose-700 ring-rose-200',
  slate: 'bg-slate-100 text-slate-700 ring-slate-200',
};

export function StatusBadge({ label, tone = 'slate' }: StatusBadgeProps) {
  return (
    <span
      className={clsx(
        'inline-flex items-center rounded px-2 py-1 text-xs font-semibold ring-1',
        tones[tone],
      )}
    >
      {label}
    </span>
  );
}
