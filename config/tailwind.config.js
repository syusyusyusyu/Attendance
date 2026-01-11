/** @type {import('tailwindcss').Config} */
const defaultTheme = require('tailwindcss/defaultTheme')

export default {
  content: [
    './app/views/**/*.{erb,html}',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.{js,ts,jsx,tsx}',
    './app/assets/stylesheets/**/*.{css,scss}',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', ...defaultTheme.fontFamily.sans],
      },
      colors: {
        gray: {
          50: '#F9FAFB',  // Lightest background
          100: '#F3F4F6',
          200: '#E5E7EB',
          300: '#D1D5DB',
          400: '#9CA3AF',
          500: '#6B7280',
          600: '#4B5563',
          700: '#374151',
          800: '#1F2937',
          900: '#111827',
        }
      }
    },
  },
  plugins: [],
};