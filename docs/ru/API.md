# Использование API SwiftNetPulse

**Язык:** [English](../API.md) · [Русский](API.md)

Это руководство описывает публичную инициализацию, отчёты диагностики,
локализованный вывод и совместимость. Имена идентификаторов Swift не дублируются
вторым языком на каждом символе; комментарии в исходниках — на английском.

Связанные страницы: [README.md](README.md), [LOCALIZATION.md](LOCALIZATION.md),
[DEVELOPMENT.md](DEVELOPMENT.md).

## Монитор с английским по умолчанию

```swift
import SwiftNetPulse

let monitor = try ConnectionMonitor(endpoints: [
    Endpoint(url: URL(string: "https://example.test/health")!, rule: .anyData),
])
let report = await monitor.check()
print(report.log) // английские подписи, числа в стиле POSIX
```

`ConnectionMonitor(endpoints:)` не меняется. Он использует
`ReportLocalization.english`. `Foundation.LocalizedError.errorDescription` для
`ConnectionMonitorError` остаётся английским, даже если монитор настроен на
другой язык.

## Явный русский и независимые мониторы

```swift
let english = try ConnectionMonitor(
    endpoints: [Endpoint(url: URL(string: "https://example.test/")!, rule: .anyData)],
    localization: .english
)
let russian = try ConnectionMonitor(
    endpoints: [Endpoint(url: URL(string: "https://example.test/")!, rule: .anyData)],
    localization: .russian
)
let englishReport = await english.check()
let russianReport = await russian.check()
// Издатели событий и ошибок сохраняют ту же структурную семантику.
_ = english.events
_ = russian.failures
```

`ReportLocalization.system(preferredLanguages:localeIdentifier:)` один раз
фиксирует список предпочтений (в тестах список подставляется). Неподдерживаемые
теги дают английский. Региональные теги вроде `ru-RU` разрешаются в таблицу `ru`.

Язык выбирает таблицы сообщений. `localeIdentifier` выбирает только числовое
форматирование. Их можно сочетать:

```swift
let mixed = ReportLocalization(languageIdentifier: "ru", localeIdentifier: "en_US_POSIX")
print(englishReport.localizedLog(using: mixed))
```

Повторный рендер не выполняет пробы и не меняет сохранённый `log`. Если
`DiagnosisReport` создан с произвольной строкой `log`, этот текст хранится;
`localizedLog(using:)` всё равно собирается из `date`, `snapshot` и `results`.

## Совместимость traceroute

```swift
let legacy: TracerouteResult = await monitor.traceroute(to: "example.test")
switch legacy {
case .hops(let hops):
    print(hops.count)
case .unavailable(let message):
    print(message) // сырая строка совместимости; может быть текстом библиотеки или клиента
}

let details: TracerouteDetails = await monitor.tracerouteDetails(to: "example.test")
print(details.localizedLog(using: .russian))
```

Не добавляйте третий публичный case в `TracerouteResult`. Вручную созданный
`.unavailable(message: "custom")` сохраняет `custom` точно; переводятся только
окружающие подписи вроде «Трассировка недоступна». Типизированные причины
недоступности живой трассы передаются в
`TracerouteDetails.unavailableMetadata` и при `check()` — в
`ProbeResult.tracerouteFailureMetadata`.

## Метаданные сбоев

Живые ошибки DNS, TCP, HTTP и TLS заполняют `ProbeResult.failureMetadata` и
`ProbeFailure.metadata` с `ProbeStage` и стабильным `reasonCode`. Известные коды
`URLError` отображаются на собственные краткие формулировки.
`localizedDescription` ОС сохраняется в `rawDetail` и при наличии печатается
отдельной строкой «Системные сведения (без перевода)».

`ProbeOutcome.transportFailure(String)` остаётся строкой совместимости
(английская для живых проб). Не разбирайте её, чтобы отличить DNS от TCP;
используйте `stage`. Устаревший результат, в тексте которого случайно есть
«DNS», заново не классифицируется.

## Ошибки

```swift
do {
    _ = try ConnectionMonitor(endpoints: [])
} catch let error as ConnectionMonitorError {
    print(error.errorDescription ?? "") // английский
    print(error.localizedDescription(using: .russian))
}
```

## Что никогда не переводится

Имена хостов, IP-адреса, URL, числовые HTTP-статусы, байты тела ответа,
неизвестные токены типа сети и произвольные сообщения недоступности, заданные
клиентом. Текст полезной нагрузки может быть на другом языке по замыслу.

Редакция источника этого руководства учитывается в
[translations.json](../translations.json).
