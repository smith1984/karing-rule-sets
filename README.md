# smart-home rule-sets

Публичные sing-box rule-sets для централизованного распределения правил маршрутизации между клиентами (малинка / ноут / телефоны через Karing).

## Зачем

Часть RU-сайтов хостится на иностранных TLD (`.com`, `.io`, `.eu`) и не покрывается стандартными правилами `domain_suffix .ru` или `geosite:category-ru`. Чтобы не патчить конфиги всех устройств вручную при появлении нового сайта — храним список централизованно. Каждый sing-box подгружает remote rule-set с `update_interval: 1h` и автоматически получает обновления.

## Файлы

- `ru-extras.json` — список RU-сайтов на foreign-доменах, которым нужен **direct маршрут** (минуя VPN). Пустой по умолчанию, наполняется по мере встречи проблем.
- `examples/ru-extras-sample.json` — пример с заполненным списком, для понимания формата.

## Формат

sing-box [SRS source format](https://sing-box.sagernet.org/configuration/rule-set/source-format/) — JSON с массивом `rules`. Поля внутри rule:
- `domain` — точное совпадение (`habr.com` матчит ровно `habr.com`, не `subdomain.habr.com`)
- `domain_suffix` — суффикс (`.habr.com` матчит `habr.com` и все поддомены)
- `domain_keyword` — подстрока в имени

## Raw URL для sing-box

**Primary (GitHub mirror):**
```
https://raw.githubusercontent.com/smith1984/karing-rule-sets/main/ru-extras.json
```

**Sourcecraft mirror** (`ssh://ssh.sourcecraft.dev/smith15031984/karing-rule-sets.git`) — не имеет прямого raw-URL для анонимного доступа (отдаёт HTML SPA). Используется только как backup git-mirror.

При обновлении — push в **оба** remote одновременно:
```bash
cd /path/to/karing-rule-sets
git push github main && git push origin main
```

## Подключение в sing-box

В `route.rule_set`:
```json
{
  "type": "remote",
  "tag": "ru-extras",
  "format": "source",
  "url": "<RAW_URL>/ru-extras.json",
  "download_detour": "direct",
  "update_interval": "1h"
}
```

В `route.rules` (перед `final`):
```json
{ "rule_set": "ru-extras", "outbound": "direct-out" }
```

В `dns.rules` (резолвить через local DNS):
```json
{ "rule_set": "ru-extras", "server": "local" }
```

## Как добавить новый домен

1. Открыть PR в этот репо с добавлением домена в `ru-extras.json`:
   ```json
   {
     "version": 1,
     "rules": [{ "domain": ["habr.com"] }]
   }
   ```
2. Merge в main.
3. Через ~1 час все sing-box-клиенты подхватят обновление автоматически (зависит от их `update_interval`).
4. Если нужно срочно — на каждом клиенте `sing-box geosite` reload (или systemctl restart).

## Принципы наполнения

- Добавляем **только** RU-сайты которые **точно** должны идти через ISP (медиа, госуслуги-домены на foreign TLD, RU-сервисы которые блокируют не-RU IP).
- НЕ добавляем международные сайты с русскоязычными версиями (например `wikipedia.org/wiki/Россия`) — нет смысла.
- При сомнениях — оставлять через VPN (default).

## Cм. также

- [decisions/network-cases.md](../smarthome/decisions/network-cases.md) — архитектура маршрутизации
- [Karing GitHub](https://github.com/KaringX/karing) — клиент для мобильных
