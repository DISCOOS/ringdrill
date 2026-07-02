// Strings dictionary for the RingDrill site.
// Keep design tokens in CSS; keep copy here.

export type Lang = 'nb' | 'en';

export const strings = {
  nb: {
    htmlTitle: 'RingDrill: Rullering uten regneark',
    metaDescription:
      'Planlegg og kjør øvelser der lag rullerer mellom poster. RingDrill erstatter rulleringsregnearket med en app som timer hver runde og deler ut briefer.',

    nav: {
      features: 'Funksjoner',
      catalog: 'Katalog',
      download: 'Last ned',
      openWeb: 'Åpne på web',
      langSwitch: 'English',
      langSwitchHref: '/en/',
    },

    hero: {
      eyebrow: 'For øvelsesledere og veiledere',
      title: 'Rullering uten regneark.',
      lead: 'Du planlegger og leder øvelsen. RingDrill holder styr på rundetider, rullering og briefer til lag, veiledere og markører.',
      primaryCta: 'Last ned for Android',
      primaryHref:
        'https://play.google.com/store/apps/details?id=org.discoos.ringdrill',
      iosCta: 'Last ned for iOS',
      iosHref: 'https://apps.apple.com/no/app/ringdrill-app/id6777269410?l=nb',
      secondaryCta: 'Åpne på web',
      secondaryHref: 'https://web.ringdrill.app/',
      note: 'Gratis på Android og iOS. Eller åpne på web.',
    },

    features: {
      eyebrow: 'Funksjoner',
      title: 'Dette tar RingDrill seg av',
      items: [
        {
          title: 'Rundetider og rullering',
          body: 'Sett antall lag, poster og runder. RingDrill regner ut hvem som er hvor og når. Den varsler ved overgang.',
        },
        {
          title: 'Live status for alle',
          body: 'Alle ser samme status og nedtelling for øvelsen. Veiledere varsles når neste runde er klar.',
        },
        {
          title: 'Kart over postene',
          body: 'Marker postene i terrenget. Deltakere åpner kartet på telefonen og finner riktig post.',
        },
        {
          title: 'Briefer for hver rolle',
          body: 'RingDrill genererer briefer for deltakere, veiledere og øvelsesledere fra samme datakilde. Endre én gang, alle versjoner oppdateres.',
        },
      ],
    },

    shots: {
      eyebrow: 'Skjermbilder',
      title: 'Slik ser det ut',
      items: [
        { src: '/screenshots/nb/01-schedule.png', alt: 'Program-fanen med poster og runder' },
        { src: '/screenshots/nb/02-map.png', alt: 'Kart med poster markert i terrenget' },
        { src: '/screenshots/nb/03-live.png', alt: 'Live-skjerm med nedtelling for runden' },
        { src: '/screenshots/nb/04-brief.png', alt: 'Brief generert for valgt målgruppe' },
      ],
    },

    cta: {
      title: 'Klar til å legge vekk regnearket?',
      body: 'Last ned eller åpne på web. Det tar et minutt å sette opp første øvelse.',
      primary: 'Last ned for Android',
      ios: 'Last ned for iOS',
      secondary: 'Åpne på web',
    },

    catalog: {
      eyebrow: 'Katalog',
      title: 'Delte øvingsplaner',
      lead: 'Bla i øvingsplaner andre har delt i RingDrill-katalogen.',
      emptyNoPlans: 'Ingen planer er publisert ennå.',
      emptyUnavailable: 'Katalogen er midlertidig utilgjengelig. Prøv igjen senere.',
      updated: 'Oppdatert',
      download: 'Last ned',
      exerciseUnit: 'øvelse',
      exercisePlural: 'øvelser',
      mapAttribution: 'Kartdata © Kartverket',
    },

    footer: {
      tagline: 'Rullering uten regneark.',
      colMade: 'Laget av',
      madeBy: 'DISCOOS',
      madeByHref: 'https://github.com/DISCOOS',
      colLinks: 'Lenker',
      links: [
        { label: 'Google Play', href: 'https://play.google.com/store/apps/details?id=org.discoos.ringdrill' },
        { label: 'App Store', href: 'https://apps.apple.com/no/app/ringdrill-app/id6777269410?l=nb' },
        { label: 'Åpne på web', href: 'https://web.ringdrill.app/' },
        { label: 'Kildekode på GitHub', href: 'https://github.com/DISCOOS/ringdrill' },
        { label: 'API', href: 'https://ringdrill.app/api/docs' },
      ],
      colLegal: 'Juridisk',
      legal: [
        { label: 'Personvern', href: '/privacy' },
        { label: 'Vilkår', href: '/terms' },
      ],
      repoHref: 'https://github.com/DISCOOS/ringdrill',
      copyrightPre: '© 2026 DISCOOS. RingDrill er ',
      openSource: 'åpen kildekode',
      copyrightPost: '.',
    },
  },

  en: {
    htmlTitle: 'RingDrill: Rotation without the spreadsheet',
    metaDescription:
      'Plan and run drills where teams rotate between stations. RingDrill replaces the rotation spreadsheet with an app that times every round and hands out briefs.',

    nav: {
      features: 'Features',
      catalog: 'Catalog',
      download: 'Download',
      openWeb: 'Open on web',
      langSwitch: 'Norsk',
      langSwitchHref: '/',
    },

    hero: {
      eyebrow: 'For drill directors and trainers',
      title: 'Rotation without the spreadsheet.',
      lead: 'You plan and run the drill. RingDrill keeps track of round times, rotation and briefs for teams, trainers and role-players.',
      primaryCta: 'Download for Android',
      primaryHref:
        'https://play.google.com/store/apps/details?id=org.discoos.ringdrill',
      iosCta: 'Download for iOS',
      iosHref: 'https://apps.apple.com/no/app/ringdrill-app/id6777269410?l=en',
      secondaryCta: 'Open on web',
      secondaryHref: 'https://web.ringdrill.app/',
      note: 'Free on Android and iOS. Or open on the web.',
    },

    features: {
      eyebrow: 'Features',
      title: 'What RingDrill takes care of',
      items: [
        {
          title: 'Round times and rotation',
          body: 'Set teams, stations and rounds. RingDrill figures out who is where and when, then announces the handover.',
        },
        {
          title: 'Live status for everyone',
          body: 'Everyone on the drill sees the same status and countdown. Trainers get a signal when the next round is ready.',
        },
        {
          title: 'Map of every station',
          body: 'Drop pins for each station. Participants open the map on their phone and find the right station.',
        },
        {
          title: 'Briefs for every role',
          body: 'RingDrill generates briefs for participants, trainers and directors from a single source. Edit once, every version updates.',
        },
      ],
    },

    shots: {
      eyebrow: 'Screens',
      title: 'How it looks',
      items: [
        { src: '/screenshots/en/01-schedule.png', alt: 'Program tab with stations and rounds' },
        { src: '/screenshots/en/02-map.png', alt: 'Map with stations placed on the terrain' },
        { src: '/screenshots/en/03-live.png', alt: 'Live screen with round countdown' },
        { src: '/screenshots/en/04-brief.png', alt: 'Brief rendered for the selected audience' },
      ],
    },

    cta: {
      title: 'Ready to retire the spreadsheet?',
      body: 'Download or open it on the web. First drill takes a minute to set up.',
      primary: 'Download for Android',
      ios: 'Download for iOS',
      secondary: 'Open on web',
    },

    catalog: {
      eyebrow: 'Catalog',
      title: 'Shared drill plans',
      lead: 'Browse drill plans others have shared in the RingDrill catalog.',
      emptyNoPlans: 'No plans have been published yet.',
      emptyUnavailable: 'The catalog is temporarily unavailable. Please try again later.',
      updated: 'Updated',
      download: 'Download',
      exerciseUnit: 'exercise',
      exercisePlural: 'exercises',
      mapAttribution: 'Map data © Kartverket',
    },

    footer: {
      tagline: 'Rotation without the spreadsheet.',
      colMade: 'Made by',
      madeBy: 'DISCOOS',
      madeByHref: 'https://github.com/DISCOOS',
      colLinks: 'Links',
      links: [
        { label: 'Google Play', href: 'https://play.google.com/store/apps/details?id=org.discoos.ringdrill' },
        { label: 'App Store', href: 'https://apps.apple.com/no/app/ringdrill-app/id6777269410?l=en' },
        { label: 'Open on web', href: 'https://web.ringdrill.app/' },
        { label: 'Source on GitHub', href: 'https://github.com/DISCOOS/ringdrill' },
        { label: 'API', href: 'https://ringdrill.app/api/docs' },
      ],
      colLegal: 'Legal',
      legal: [
        { label: 'Privacy', href: '/en/privacy' },
        { label: 'Terms', href: '/en/terms' },
      ],
      repoHref: 'https://github.com/DISCOOS/ringdrill',
      copyrightPre: '© 2026 DISCOOS. RingDrill is ',
      openSource: 'open source',
      copyrightPost: '.',
    },
  },
} as const;

export function t(lang: Lang) {
  return strings[lang];
}
