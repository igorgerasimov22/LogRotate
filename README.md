# LogRotate

PowerShell-скрипт для автоматической архивации IIS-логов с помощью 7-Zip и удаления старых архивов.

Скрипт рассчитан на регулярный запуск, в том числе через Windows Task Scheduler. По умолчанию обрабатываются каталоги IIS:

```text
C:\inetpub\logs\LogFiles\W3SVC1
C:\inetpub\logs\LogFiles\W3SVC2
```

## Возможности

- рекурсивный поиск файлов `.log` и `.txt`;
- архивирование только файлов старше заданного периода;
- группировка логов по дате `LastWriteTime`;
- имена архивов в независимом от региональных настроек формате `yyyy-MM-dd.7z`;
- работа сразу с несколькими каталогами;
- максимальное сжатие 7-Zip/LZMA2;
- проверка кода возврата `7z.exe`;
- удаление исходного файла только после успешной архивации;
- автоматическое удаление старых архивов;
- обработка ошибок через `try/catch`;
- запись работы скрипта в отдельный лог-файл;
- автоматическое создание каталога для лог-файла, если его ещё нет.

## Требования

- Windows Server / Windows;
- Windows PowerShell 5.1 или новее;
- установленный [7-Zip](https://www.7-zip.org/);
- права чтения, записи и удаления в каталогах с IIS-логами;
- права записи в каталог, указанный в параметре `LogFile`.

По умолчанию ожидается, что 7-Zip установлен здесь:

```text
C:\Program Files\7-Zip\7z.exe
```

## Параметры

| Параметр | Тип | Значение по умолчанию | Назначение |
|---|---|---|---|
| `SevenZipPath` | `String` | `C:\Program Files\7-Zip\7z.exe` | Путь к `7z.exe` |
| `BackupPaths` | `String[]` | `W3SVC1`, `W3SVC2` | Каталоги, которые необходимо обрабатывать |
| `ArchiveExtension` | `String` | `.7z` | Расширение создаваемых архивов |
| `Days` | `Int` | `-1` | Архивировать файлы с `LastWriteTime` старше указанного периода |
| `ArchiveDays` | `Int` | `-31` | Удалять архивы старше указанного периода |
| `LogFile` | `String` | `C:\Logs\IIS-Archive.log` | Файл журнала работы скрипта |

### Как работают Days и ArchiveDays

Скрипт вычисляет пороговую дату так:

```powershell
(Get-Date).AddDays($Days)
```

Поэтому:

```text
-Days -1
```

означает: архивировать файлы, которые не изменялись более суток.

А:

```text
-ArchiveDays -31
```

означает: удалять архивы старше 31 дня.

## Принцип работы

Для каждого каталога из `BackupPaths` выполняются следующие действия:

1. Проверяется существование каталога.
2. Рекурсивно находятся файлы `.log` и `.txt`.
3. Отбираются файлы, у которых `LastWriteTime` меньше или равен пороговой дате.
4. Файлы группируются по дате последнего изменения.
5. Для каждой даты создаётся или дополняется архив вида:

```text
2026-09-27.7z
2026-09-28.7z
2026-09-29.7z
```

6. Каждый файл передаётся в 7-Zip.
7. Проверяется `$LASTEXITCODE`.
8. Только если 7-Zip завершился с кодом `0`, исходный файл удаляется.
9. После архивации удаляются архивы старше `ArchiveDays`.

Такой подход защищает исходные IIS-логи от удаления при ошибке 7-Zip.

## Параметры 7-Zip

Скрипт использует:

```text
-t7z
-m0=lzma2
-mx=9
-aoa
-mfb=64
-md=32m
-ms=on
```

Основные параметры:

- `-t7z` — формат архива 7z;
- `-m0=lzma2` — алгоритм LZMA2;
- `-mx=9` — максимальный уровень сжатия;
- `-aoa` — перезапись существующих файлов внутри архива;
- `-md=32m` — словарь 32 МБ;
- `-ms=on` — solid-сжатие.

## Логирование

По умолчанию журнал работы создаётся здесь:

```text
C:\Logs\IIS-Archive.log
```

Пример:

```text
2026-09-29 11:31:02 [INFO] IIS log archive script started.
2026-09-29 11:31:02 [INFO] Processing directory: C:\inetpub\logs\LogFiles\W3SVC1
2026-09-29 11:31:02 [INFO] Found 7 file(s) for archiving.
2026-09-29 11:31:02 [INFO] Creating/updating archive: C:\inetpub\logs\LogFiles\W3SVC1\2026-09-28.7z
2026-09-29 11:31:03 [INFO] Archiving: C:\inetpub\logs\LogFiles\W3SVC1\u_ex260928.log
2026-09-29 11:31:05 [INFO] Archived and removed source file: C:\inetpub\logs\LogFiles\W3SVC1\u_ex260928.log
```

При ошибке:

```text
2026-09-29 11:31:05 [ERROR] 7-Zip failed for 'C:\inetpub\logs\LogFiles\W3SVC1\u_ex260928.log'. Exit code: 2
```

В этом случае исходный файл не удаляется.

## Запуск

### С параметрами по умолчанию

```powershell
.\ArchiveLogs.ps1
```

### Указать отдельный лог-файл

```powershell
.\ArchiveLogs.ps1 -LogFile "D:\ScriptLogs\IIS-Archive.txt"
```

### Указать свои каталоги

```powershell
.\ArchiveLogs.ps1 `
    -BackupPaths "D:\IISLogs\Site1","D:\IISLogs\Site2" `
    -LogFile "D:\ScriptLogs\IIS-Archive.txt"
```

### Изменить сроки хранения

Например, архивировать логи старше 2 дней и хранить архивы 60 дней:

```powershell
.\ArchiveLogs.ps1 `
    -Days -2 `
    -ArchiveDays -60
```

### Полный пример

```powershell
.\ArchiveLogs.ps1 `
    -SevenZipPath "C:\Program Files\7-Zip\7z.exe" `
    -BackupPaths "C:\inetpub\logs\LogFiles\W3SVC1","C:\inetpub\logs\LogFiles\W3SVC2" `
    -Days -1 `
    -ArchiveDays -31 `
    -LogFile "C:\Logs\IIS-Archive.txt"
```

## Windows Task Scheduler

Для автоматического запуска рекомендуется создать задачу в Task Scheduler.

### General

Рекомендуемые параметры:

- **Run whether user is logged on or not**;
- **Run with highest privileges**;
- учётная запись задачи должна иметь права на каталоги IIS-логов, файл журнала и `7z.exe`.

### Action

**Program/script**

```text
powershell.exe
```

**Add arguments**

```text
-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\ArchiveLogs.ps1" -LogFile "C:\Logs\IIS-Archive.txt"
```

**Start in**

```text
C:\Scripts
```

В поле **Start in** путь рекомендуется указывать без кавычек.

## Проверка перед добавлением в Task Scheduler

Сначала рекомендуется выполнить ту же команду вручную:

```cmd
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\ArchiveLogs.ps1" -LogFile "C:\Logs\IIS-Archive.txt"
```

После выполнения:

```cmd
echo %ERRORLEVEL%
```

Также можно проверить наличие 7-Zip:

```powershell
Test-Path "C:\Program Files\7-Zip\7z.exe"
```

Ожидаемый результат:

```text
True
```

## Права доступа

Учётная запись, от которой запускается скрипт, должна иметь:

- Read на `ArchiveLogs.ps1`;
- Read/Execute на `7z.exe`;
- Read/Write/Delete на каталогах из `BackupPaths`;
- Write на каталог, содержащий `LogFile`.

Например:

```text
C:\inetpub\logs\LogFiles\W3SVC1
C:\inetpub\logs\LogFiles\W3SVC2
C:\Logs
```

## Устранение проблем

### Логи не архивируются

Проверьте:

```powershell
Test-Path "C:\inetpub\logs\LogFiles\W3SVC1"
Test-Path "C:\inetpub\logs\LogFiles\W3SVC2"
```

Посмотрите файлы, которые подходят под текущий порог:

```powershell
$CutoffDate = (Get-Date).AddDays(-1)

Get-ChildItem "C:\inetpub\logs\LogFiles\W3SVC1" -File -Recurse |
    Where-Object {
        $_.Extension -in @(".log", ".txt") -and
        $_.LastWriteTime -le $CutoffDate
    } |
    Select-Object FullName, LastWriteTime
```

### Вместо архива появились каталоги с датой

Старые версии скрипта могли использовать:

```powershell
.ToShortDateString()
```

При формате даты вроде:

```text
9/28/2026
```

символ `/` интерпретировался как разделитель пути, из-за чего могли появляться каталоги:

```text
9\28\2026.7z
```

Текущая версия использует:

```powershell
.ToString("yyyy-MM-dd")
```

поэтому региональные настройки Windows не влияют на имя архива.

### Task Scheduler: return code 2147942401

Десятичный код:

```text
2147942401
```

соответствует:

```text
0x80070001
ERROR_INVALID_FUNCTION
```

При такой ошибке сначала:

1. запустите команду PowerShell вручную;
2. проверьте путь к `ArchiveLogs.ps1`;
3. проверьте путь к `7z.exe`;
4. убедитесь, что каталог для `LogFile` доступен учётной записи задачи;
5. проверьте поля **Program/script**, **Add arguments** и **Start in**;
6. проверьте права пользователя, от имени которого запускается задача.

## Безопасность

Перед первым запуском в production рекомендуется:

1. проверить скрипт вручную;
2. убедиться, что создаваемые архивы действительно содержат нужные файлы;
3. проверить журнал работы;
4. только после этого настраивать регулярный запуск через Task Scheduler.

Не удаляйте вручную активные IIS-логи без понимания того, какой процесс их использует.

## Структура репозитория

```text
LogRotate/
├── ArchiveLogs.ps1
└── README.md
```

## Назначение проекта

Проект предназначен прежде всего для автоматизации ротации IIS-логов на Windows Server, когда стандартного хранения логов недостаточно или требуется дополнительное сжатие и контролируемое удаление старых файлов.
