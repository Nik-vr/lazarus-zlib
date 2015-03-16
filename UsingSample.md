
```
uses zlibfunc;
 
// Сжатие одиночного файла
// Compress singe file
CompressFile(SourceFile: string, PackedFile: string);
 
// Сжатие заданного каталога
// Compress directory
procedure CompressDirectory(const Directory: string; Recursive: Boolean; const FileName: string);
 
// Распаковка zlib-архива в заданный каталог
// Unpack files from zlib to directory
DecompressFile(PackedFile: string, UnPackedFile: string);
```