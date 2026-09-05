# YouTube Music Control

Android telefondan yerel ağ üzerinden YouTube Music kontrol eden Flutter uygulaması. Pear Desktop'ın HTTP API'siyle konuşur.

## Yapı

- `lib/` — Flutter/Dart uygulaması
- `android/` `ios/` `macos/` `windows/` `linux/` — platform kabukları

## Çalıştırma

```
flutter pub get
flutter run
```

## Dikkat

Karşı taraf [Pear Desktop](https://github.com/pear-devs/pear-desktop) — HTTP API'si
açık olmalı ve iki cihaz aynı yerel ağda olmalı. Bağlantı sorunlarında önce bunu doğrula.

graft'ın Dart için ürettiği çağrı kenarları zayıf (`edges` sayısı düşük); sembol ve
dosya araması güvenilir ama "kim çağırıyor" sorusunda Grep'e düşmen gerekebilir.

## Kod aramadan önce: graft

Bu repo **graft** ile indekslenmiş. Dosya okumaya/grep'lemeye başlamadan önce
`mcp__graft__*` araçlarını kullan — tek çağrı genelde birkaç dosya okumasının yerine geçer.

- `graft_find_code` — "X nasıl çalışıyor" / "Y nerede"
- `graft_find_all` — her geçtiği yer lazımsa
- `graft_trace_calls` — kim çağırıyor / ne çağırıyor (blast radius)
- `graft_file_api` — bir dosyanın imza yüzeyi
- `graft_repo_map` — repo yönelimi

Graf `graft/` altında, git-ignore'lu yerel bir cache. Bayatlarsa: `graft build`
(PostToolUse hook'u düzenlemelerden sonra otomatik tazeliyor).
