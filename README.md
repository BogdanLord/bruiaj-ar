# Bruiaj AR — Virtual UO

Aplicație iOS care CITEȘTE zonele de bruiaj GNSS din Supabase (tabela `bruiaj_zones`)
și le afișează în **AR pe cameră** (cupole plasate în jurul tău după poziția GPS și busolă),
plus un **radar 2D** și o **listă**.

> Simulator / digital-twin. Nu emite și nu citește semnal radio real — doar date din baza de date.

## Structura proiectului (în repo)

```
.
├── project.yml                 # definiția XcodeGen
├── .github/workflows/ios.yml   # build CI -> IPA nesemnat
└── Sources/
    ├── BruiajARApp.swift       # @main + Config (URL + anon key) + paletă
    ├── Models.swift            # modelul Zone (decode tolerant)
    ├── GeoMath.swift           # distanță/azimut + UIColor(hex:)
    ├── LocationManager.swift   # GPS + busolă
    ├── SupabaseService.swift   # citire REST din Supabase
    ├── RadarView.swift         # radar 2D
    ├── ZonesListView.swift     # listă zone
    ├── ZoneARView.swift        # RealityKit AR
    └── ContentView.swift       # tab-uri Zone / Radar / AR
```

## Configurare

În `Sources/BruiajARApp.swift`, în `enum Config`:
- `supabaseURL` — URL-ul instanței tale (ex. `https://supabase.virtual.uoradea.ro`)
- `supabaseAnonKey` — cheia anon (din `.env`-ul instanței)

## Build (Windows-friendly, fără Mac)

1. Push pe `main` → rulează GitHub Action „iOS Build (unsigned IPA)".
2. Din rularea workflow-ului descarci artefactul **BruiajAR-ipa** (`BruiajAR.ipa`).
3. Instalezi cu **Sideloadly** (semnează la instalare cu Apple ID-ul tău).

## Permisiuni

La prima pornire iOS cere acces la **cameră** (AR) și **locație** (GPS/busolă). Acceptă ambele.
