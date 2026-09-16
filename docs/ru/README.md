# SwiftNetPulse

**Язык:** [English](../../README.md) · [Русский](README.md)

Swift SPM-библиотека для проверки списка URL: разовая диагностика, периодический мониторинг ошибок через **Combine** и трассировка маршрута по запросу.

ICMP ping в v1 **не входит** в критерии успеха и не выполняется.

## Установка

В `Package.swift` приложения:

```swift
.package(path: "../SwiftNetPulse")
```

или по URL репозитория, когда пакет опубликован.

Платформы: iOS 15+, macOS 12+.

## Инициализация

```swift
import SwiftNetPulse

let monitor = try ConnectionMonitor(endpoints: [
    Endpoint(url: URL(string: "https://skills.example/")!, rule: .anyData),
    Endpoint(
        url: URL(string: "https://api.example/health")!,
        rule: .all([.statusEqual(200), .bodyContains("ok")]),
        timeout: 5,
        traceOnCheck: true
    ),
])
```

Одно правило на URL. Составные условия — `.all([...])`.

Отчёты по умолчанию на английском. Передайте `localization:` для русского или
другой поддерживаемой таблицы; два монитора могут одновременно использовать
разные языки:

```swift
let english = try ConnectionMonitor(endpoints: endpoints) // английский
let russian = try ConnectionMonitor(endpoints: endpoints, localization: .russian)
let report = await russian.check()
print(report.log)
print(report.localizedLog(using: .english)) // повторный рендер без пробы
```

## Разовая проверка `check()`

```swift
let cancellable = monitor.events.sink { event in
    switch event {
    case .success(let result): print("ok", result.httpStatus ?? 0)
    case .failure(let result): print("fail", result.outcome)
    }
}

let report = await monitor.check()
print(report.log)
```

`report.log` — ориентировочный человекочитаемый отчёт (DNS, TCP, HTTPS, статус, скорость, preview тела). События успеха и ошибки приходят **по мере** завершения каждого URL, до возврата полного отчёта.

## Периодический мониторинг (Combine)

```swift
let failures = monitor.failures.sink { failure in
    print(failure.kind, failure.endpoint.url)
}

try monitor.startMonitoring(every: 30)
// ...
monitor.stopMonitoring()
```

В фоне применяются те же правила, что и в `check()`. Traceroute не запускается. В поток попадают только ошибки (транспорт или несовпадение правила). Успешный 404 при `.anyData` в `failures` не публикуется.

## Traceroute

```swift
let route = await monitor.traceroute(to: "api.example.com")
print(route.log)          // текст маршрута
print(route.hopList)      // структурированные хопы
```

Возвращает список хопов (таймаут хопа — без адреса и RTT) или `.unavailable`, если ICMP-сокет недоступен. Системный бинарь `traceroute` не вызывается.

В `check()` маршрут добавляется только если у эндпоинта `traceOnCheck == true`.

## Замеры

До полезной нагрузки: DNS, TCP connect, TLS / HTTPS connect.
После: HTTP response time, total, скорость = байты тела / время ответа (если тело непустое и длительность > 0).

## Разработка

Из корня репозитория на macOS с установленным Xcode:

```bash
make setup
```

Команда проверяет инструменты, собирает пакет и запускает тесты. Дополнительные
команды: `make test`, `make release`, `make ios`, `make help`.
Для работы в Xcode откройте `Package.swift` и выберите схему `SwiftNetPulse`.
Имя каталога репозитория — `SwiftNetPulse`, имя импортируемого модуля — `SwiftNetPulse`.

Тесты отдельно: `swift test` из корня репозитория.
Требования, архитектура и ограничения описаны в [DEVELOPMENT.md](DEVELOPMENT.md).
Политика локализации и работа переводчика: [LOCALIZATION.md](LOCALIZATION.md).
Использование публичного API: [API.md](API.md).

## Лицензирование

SwiftNetPulse распространяется по лицензии [Creative Commons Attribution 4.0
International](https://creativecommons.org/licenses/by/4.0/deed.ru) (CC BY 4.0).
Его можно копировать, изменять и использовать, в том числе коммерчески, с
указанием авторства.

Текст лицензии — в [LICENSE](../../LICENSE). Обзор: [LICENSING.md](LICENSING.md).
