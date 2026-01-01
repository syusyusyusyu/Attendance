/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './app/views/**/*.{erb,html}',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.{js,ts,jsx,tsx}',
    './app/assets/stylesheets/**/*.{css,scss}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};
