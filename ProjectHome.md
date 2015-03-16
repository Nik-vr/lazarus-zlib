### Description / Описание ###

lazarus-zlib - is library, contains simple functions for work with zlib-archives (it uses the original zlib source, compiled in obj-files).

_Простой в использовании класс-обёртка для zlib, основанные на исходниках JEDI и библиотеке delphi.zlib, и адаптированные для Lazarus/FPC._


### Comments / Примечания ###
Current version of lazarus-zlib can compiled only in Lazarus/FPC on Windows platform. For compile on other OS, you need to create new obj-files (use gcc for same OS).
To compile in Delphi, you may be need to modify code and create obj-files from Borland-compiler.

_Текущая версия использует obj-файлы, скомпилированные с помощью gcc под Windows, и не работает в других ОС. При этом сам код должен (в теории) быть кросс-платформенным (необходимо тестирование).
Исходные компоненты компилировались в Delphi 7, но текущая версия на совместимость с Delphi не тестировалась (скорее всего для успешной компиляции в Delphi придётся пересоздать obj-файлы из исходников с помощью компилятора от Borland)._