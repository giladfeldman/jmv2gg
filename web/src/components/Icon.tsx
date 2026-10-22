const paths = {
  download: 'M12 3v12m-5-5 5 5 5-5M5 16v4h14v-4',
  arrow: 'M4 12h16m-6-6 6 6-6 6',
  shield: 'M12 3 4 6v6c0 5 8 9 8 9s8-4 8-9V6l-8-3Zm-4 9 3 3 5-6',
  copy: 'M9 8h11v13H9zM4 16V3h11',
  chart: 'M4 3v17h17M7 15l4-6 4 3 5-7',
};

export type IconName = keyof typeof paths;

export function Icon({ name }: { name: IconName }) {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
    <path d={paths[name]} strokeLinejoin="round" strokeLinecap="round"/>
  </svg>;
}
