/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        market: {
          ink: '#172033',
          blue: '#2563eb',
          sky: '#0ea5e9',
          mint: '#14b8a6',
          amber: '#f59e0b',
          rose: '#e11d48',
        },
      },
      boxShadow: {
        panel: '0 12px 30px rgba(15, 23, 42, 0.08)',
      },
    },
  },
  plugins: [],
}
