# Локализация SwiftNetPulse

**Язык:** [English](../LOCALIZATION.md) · [Русский](LOCALIZATION.md)

Канонический язык авторства документации, комментариев публичного API,
идентификаторов, инструкций по разработке и вывода библиотеки по умолчанию —
английский. Русский — полный первый перевод. Другие языки подключаются по этому
же процессу; автоматического обещания поддержки всех языков нет.

Этот файл — контракт локализации. Реализации runtime-типов соответствуют
сигнатурам ниже. Имена в Swift (`SwiftNetPulse`, `ConnectionMonitor`,
`DiagnosisReport`, команды, пути, URL, IP-адреса, коды HTTP и тела ответов)
не переводятся.

## Инвентарь

Принадлежащие библиотеке строки находятся в документации, черновиках лицензий,
`make help`, `Localizable.strings` и английских значениях `LocalizedError`.

| Поверхность | Английский источник | Русский эквивалент |
| --- | --- | --- |
| Установка и быстрый старт | `README.md` | `docs/ru/README.md` |
| Окружение, архитектура, ограничения | `DEVELOPMENT.md` | `docs/ru/DEVELOPMENT.md` |
| Обзор лицензирования | `LICENSING.md` | `docs/ru/LICENSING.md` |
| Статус лицензии | `LICENSE` | `docs/ru/LICENSE.md` |
| Некоммерческий черновик | `LICENSE-NONCOMMERCIAL.md` | `docs/ru/LICENSE-NONCOMMERCIAL.md` |
| Коммерческий черновик | `COMMERCIAL-LICENSE.md` | `docs/ru/COMMERCIAL-LICENSE.md` |
| Этот процесс и глоссарий | `docs/LOCALIZATION.md` | `docs/ru/LOCALIZATION.md` |
| Руководство по API | `docs/API.md` | `docs/ru/API.md` |
| Сообщения библиотеки | `Sources/SwiftNetPulse/Resources/en.lproj/Localizable.strings` | `…/ru.lproj/Localizable.strings` |
| Справка разработки | `make help` | `make help LANG=ru` |

Ключи сообщений (аргументы нумеруются `%1$@`, `%2$@`):

- Отчёт: `report.title`, `report.date`, `report.network_type`, `report.local_ip`,
  `report.dns_servers`, `report.vpn`, `report.vpn.yes`, `report.vpn.no`,
  `report.finished`
- Эндпоинт: `endpoint.separator`, `endpoint.url`, `endpoint.host`
- Шаги: `dns.resolved`, `dns.resolved_timed`, `dns.failed`, `dns.failed_timed`,
  `tcp.connected`, `tcp.failed`, `https.connect`, `tls.handshake`, `http.status`,
  `http.response`, `timing.total`, `timing.speed`
- Единицы: `unit.bytes_per_second`, `unit.milliseconds`
- Исходы: `outcome.success`, `outcome.rule_mismatch`,
  `outcome.transport_failure`
- Тело: `body.preview`, `body.binary`
- Трасса: `trace.start`, `trace.unavailable`, `trace.hop`, `trace.timeout_marker`,
  `trace.socket`, `trace.dns`, `trace.ipv4_only`
- Тип сети: `path.wifi`, `path.cellular`, `path.ethernet`, `path.loopback`,
  `path.other`, `path.unsatisfied`
- Ошибки: `error.empty_endpoints`, `error.invalid_interval`
- Сбои: `failure.missing_host`, `failure.dns_failed`,
  `failure.timeout_before_tcp`, `failure.timeout_before_http`,
  `failure.tcp_failed`, `failure.no_http_status`, `failure.non_http_response`,
  `failure.url_timeout`, `failure.url_dns`, `failure.url_connect`,
  `failure.url_offline`, `failure.url_cancelled`, `failure.url_tls`,
  `failure.url_generic`, `failure.generic_transport`
- Сырой системный текст: `raw.system_detail`

Не принадлежит библиотеке (не изменяется и не используется как ключ
классификации):

- Имена хостов, IP, URL, тела HTTP, произвольные строки лога клиента
- Неизвестные значения `NetworkSnapshot.pathType`
- Ассоциированные значения `ProbeOutcome.transportFailure(String)` и
  `TracerouteResult.unavailable(message:)` у объектов, созданных клиентом
- OS `localizedDescription`, сохраняемое только как `rawDetail`
- Диагностика компилятора, SwiftPM и Xcode

## Разрешение языка

Поддерживаемые таблицы: `en`, `ru`.

1. Точный поддерживаемый тег (`en`, `ru`).
2. Базовый язык регионального тега (`ru-RU` → `ru`, `en-GB` → `en`).
3. Английский.

`ReportLocalization.system(preferredLanguages:localeIdentifier:)` один раз
фиксирует список предпочтений. Идёт по списку по порядку и выбирает первый
поддерживаемый язык; если совпадений нет — английский. Не читает и не пишет
`AppleLanguages`, `Bundle.main` и локаль процесса.

Отсутствующий ключ в запрошенном языке берётся из английской таблицы.
Отсутствующий английский ключ проваливает `make check-localization`; во время
выполнения библиотека возвращает жёстко заданную английскую фразу
`An error occurred.` и не падает из-за format-string. Переводчики могут менять
порядок нумерованных плейсхолдеров и не должны менять число или типы аргументов.
Литерал `%%` допускается.

## API представления

```swift
public struct ReportLocalization: Equatable, Sendable {
    public var languageIdentifier: String
    public var localeIdentifier: String
    public init(languageIdentifier: String, localeIdentifier: String? = nil)
    public static let english: ReportLocalization
    public static let russian: ReportLocalization
    public static func system(
        preferredLanguages: [String],
        localeIdentifier: String?
    ) -> ReportLocalization
}

extension DiagnosisReport {
    public func localizedLog(using localization: ReportLocalization) -> String
}

extension TracerouteResult {
    public func localizedLog(using localization: ReportLocalization) -> String
}

extension TracerouteDetails {
    public func localizedLog(using localization: ReportLocalization) -> String
}

extension ConnectionMonitorError {
    public func localizedDescription(using localization: ReportLocalization) -> String
}

extension ConnectionMonitor {
    public convenience init(endpoints: [Endpoint]) throws
    public convenience init(endpoints: [Endpoint], localization: ReportLocalization) throws
    public func traceroute(to host: String, maxHops: Int) async -> TracerouteResult
    public func tracerouteDetails(to host: String, maxHops: Int) async -> TracerouteDetails
}
```

`init(endpoints:)` сохраняется и делегирует в `localization: .english`.
`check().log` использует неизменяемую конфигурацию монитора. Два монитора могут
одновременно использовать разные языки. Повторный рендер сохранённого отчёта не
выполняет сетевых операций и не меняет `DiagnosisReport.log`. Произвольный `log`,
переданный в `DiagnosisReport.init`, хранится как есть; `localizedLog(using:)`
всегда строит текст из структурированных полей.

`errorDescription` для `ConnectionMonitorError` остаётся английским.
`localeIdentifier` влияет только на числа. Английские числа по умолчанию —
`en_US_POSIX`. Русские — `ru_RU`. Даты остаются ISO-8601 UTC.

## Метаданные сбоев и совместимость исходников

Добавочные необязательные поля на `ProbeResult` и `ProbeFailure`:

```swift
public enum ProbeStage: String, Equatable, Sendable {
    case dns, tcp, http, tls, traceroute, unknown
}

public struct ProbeFailureMetadata: Equatable, Sendable {
    public var stage: ProbeStage
    public var reasonCode: String
    public var arguments: [String]
    public var systemDomain: String?
    public var systemCode: Int?
    public var rawDetail: String?
}
```

Существующие memberwise-инициализаторы получают новые параметры со значениями
по умолчанию, поэтому старые вызовы компилируются. Метаданные входят в
`Equatable`. Живые пробы заполняют типизированные stage и reason code.
Классификация никогда не ищет в переведённых или сырых строках `DNS` / `TCP`.

`ProbeOutcome.transportFailure(String)` и `ProbeFailure.message` остаются
английским текстом совместимости для живых результатов. Устаревшие значения без
метаданных сохраняют исходную строку и показываются как общая транспортная
ошибка плюс сырые сведения.

Случаи `TracerouteResult` остаются `.hops([TraceHop])` и
`.unavailable(message: String)`. Сопровождающее значение `TracerouteDetails`
несёт этот enum и необязательные типизированные метаданные недоступности.
`traceroute(to:)` — адаптер совместимости; `tracerouteDetails(to:)` — подробная
точка входа. Вручную созданный `.unavailable(message:)` сохраняет точное
сообщение; окружающие подписи локализуются.

Известные коды `URLError` / `NSURLErrorDomain` отображаются на собственные ключи.
Неизвестные коды используют `failure.url_generic` с доменом и числовым кодом.
Текст ОС хранится в `rawDetail` и при показе помечается как сырой.

## Гарантии форматирования

- Длительность: миллисекунды, один знак после разделителя (RTT хопа: два знака).
- Скорость: тот же расчёт байт/секунду и округление; переводится только единица.
  Значения не переводятся в биты.
- Отсутствующие тайминги опускаются. Пустое тело не даёт preview. Не-UTF-8 тело
  использует `body.binary`. Хоп с таймаутом использует `trace.timeout_marker`.
- Английские заголовок и подвал по умолчанию остаются `NETWORK DIAGNOSIS` /
  `DIAGNOSIS FINISHED`.

## Процесс перевода

1. Сначала править английскую документацию или `en.lproj`.
2. Обновить соответствующие русские файлы.
3. Запустить `make check-localization`.
4. Записать SHA-256 английского источника (нормализованный LF) и выставить
   статус `current` в [translations.json](../translations.json). Сам манифест
   не хешируется.

Статусы: `current`, `stale`, `missing`. Устаревший поддерживаемый перевод должен
ссылаться на английский источник и содержать предупреждение. Проверки выпуска
не проходят, пока поддерживаемый перевод устарел или отсутствует.

Черновики лицензий остаются черновиками. Перевод не заполняет поля владельца,
контакта, цены или применимого права. Английский предлагается как определяющий
юридический текст, русский — как информационный перевод; это должен принять
правообладатель при финализации. Плейсхолдеры сопоставляются по семантическому
ID в `docs/translations.json`.

## Добавление языка

1. Скопировать `en.lproj/Localizable.strings` в `xx.lproj` и перевести значения.
2. Добавить страницы `docs/xx/` для каждого документа манифеста.
3. Зарегистрировать язык и дайджесты в `docs/translations.json`.
4. Выбирать его через `ReportLocalization(languageIdentifier: "xx")`.

Новый Swift API для дополнительной таблицы сообщений не нужен.

## Глоссарий

| English | Русский | Примечание |
| --- | --- | --- |
| endpoint | эндпоинт | Публичный тип остаётся `Endpoint` |
| probe / check | проверка | Метод остаётся `check()` |
| traceroute | traceroute / трассировка | Командная подпись может сохраняться |
| hop | хоп | Индекс и адреса не меняются |
| rule mismatch | несовпадение правила | Только подпись исхода |
| transport failure | транспортная ошибка | Только подпись исхода |
| monitoring | мониторинг | `startMonitoring` не меняется |

## Замечания о совместимости

- Стабильность ABI не обещается; цель — совместимость исходников для клиентов SwiftPM.
- Исчерпывающие `switch` по `TracerouteResult`, `ProbeOutcome`, `ProbeEvent`,
  `ProbeFailureKind` и `ConnectionMonitorError` должны по-прежнему компилироваться.
- Существующий `ConnectionMonitor(endpoints:)` и инициализаторы моделей с
  параметрами по умолчанию должны компилироваться.
- ICMP ping по-прежнему вне области. Алгоритмы сети, отмена и режим языка Swift
  локализацией не меняются.
