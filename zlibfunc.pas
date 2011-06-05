{*****************************************************************************
*  zlibfunc.pas                                                              *
*                                                                            *
*  copyright (c) 2004-2011 Nikolay Petrochenko                               *
*  copyright (c) 2001 SИbastien Buysse [sbuysse@buypin.com]                  *
*  based on part of JvZlibMultiple.PAS (c) JCL                               *
*                                                                            *
*  revision history                                                          *
*    04.06.2011  code cleanup, create Project page on Google Code            *
*    13.12.2010  first version, compiled in Lazarus                          *
*                                                                            *
*  This file contaned simple functions for work with zlib-archives           *
*  It's used original zlib source, compiled in obj-files                     *
*                                                                            *
*  License: Mozilla Public License версии 1.1                                *
*           http://www.mozilla.org/MPL/MPL-1.1.html                          *
*                                                                            *
*****************************************************************************}

unit zlibfunc;

interface

uses SysUtils, Classes, Controls, zlibEx;

    procedure AddFile(const FileName, Directory, FilePath: string; DestStream: TStream);
    // compresses a list of files (can contain wildcards)
    // NOTE: caller must free returned stream!
    function CompressFiles(Files: TStrings): TStream; overload;
    // compresses a list of files (can contain wildcards)
    // and saves the compressed result to FileName
    procedure CompressFiles(Files: TStrings; const FileName: string); overload;
    // Сжатие одного файла
    procedure CompressFile(FileName: string; CompressedFileName: string);
    // compresses a Directory (recursing if Recursive is true)
    // NOTE: caller must free returned stream!
    function CompressDirectory(Directory: string; Recursive: Boolean): TStream; overload;
    // compresses a Directory (recursing if Recursive is true)
    // and saves the compressed result to FileName
    procedure CompressDirectory(const Directory: string; Recursive: Boolean; const FileName: string); overload;
    // decompresses FileName into Directory. If Overwrite is true, overwrites any existing files with
    // the same name as those in the compressed archive
    procedure DecompressStream(Stream: TStream; Directory: string; Overwrite: Boolean; const RelativePaths: Boolean);
    // decompresses Stream into Directory optionally overwriting any existing files
    procedure DecompressFile(const FileName, Directory: string; Overwrite: Boolean; const RelativePaths: Boolean);

implementation

//uses FileCtrl;

{*******************************************************}
{  Format of the File:                                  }
{   File Header                                         }
{    1 Byte    Size of the directory variable           }
{    x bytes   Directory of the file                    }
{    1 Byte    Size of the filename                     }
{    x bytes   Filename                                 }
{    4 bytes   Size of the file (uncompressed)          }
{    4 bytes   Size of the file (compressed)            }
{   Data chunk                                          }
{    x bytes   the compressed chunk                     }
{*******************************************************}

function CompressDirectory(Directory: string; Recursive: Boolean): TStream;

  procedure SearchDirectory(const SDirectory: string);
  var
    SearchRec: TSearchRec;
    Res: Integer;
    fn:String;
  begin
    // (rom) this may not work for network drives and compressed files
    // (rom) because of faAnyFile
    Res := FindFirst(Directory + SDirectory + AllFilesMask, faAnyFile, SearchRec);
    try
      while Res = 0 do
      begin
        if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        begin
          if (SearchRec.Attr and faDirectory) = 0 then begin
            try
              fn := Directory + SDirectory + SearchRec.Name;
              AddFile(SearchRec.Name, SDirectory, fn, Result)
            except
            end;
          end
          else
          if Recursive then
            SearchDirectory(SDirectory + SearchRec.Name + PathDelim);
        end;
        Res := FindNext(SearchRec);
      end;
    finally
      FindClose(SearchRec);
    end;
  end;

begin
  { (RB) Letting this function create a stream is not a good idea;
         see other CompressDirectory function that causes a memory leak }
  Result := TMemoryStream.Create;
  if Directory <> '' then // do not start with '\' if the caller specifies ''.
    Directory := IncludeTrailingPathDelimiter(Directory);
  SearchDirectory('');
  Result.Position := 0;
end;


procedure AddFile(const FileName, Directory, FilePath: string; DestStream: TStream);
var
  Stream: TStream;
  FileStream: TFileStream;
  ZStream: TZCompressionStream;
  Buffer: array [0..1023] of Byte;
  Count: Integer;
  FileStreamPos, FileStreamSize: Int64;

  procedure WriteFileRecord(const Directory, FileName: string; FileSize: Integer; CompressedSize: Integer);
  var
    B: Byte;
    AnsiStr: AnsiString;
  begin
    AnsiStr := AnsiString(Directory);
    if Length(AnsiStr) > 255 then
      SetLength(AnsiStr, 255);
    B := Length(AnsiStr);
    DestStream.Write(B, SizeOf(B));
    DestStream.Write(PAnsiChar(AnsiStr)^, B);

    AnsiStr := AnsiString(FileName);
    if Length(AnsiStr) > 255 then
      SetLength(AnsiStr, 255);
    B := Length(AnsiStr);
    DestStream.Write(B, SizeOf(B));
    DestStream.Write(PAnsiChar(AnsiStr)^, B);

    DestStream.Write(FileSize, SizeOf(FileSize));
    DestStream.Write(CompressedSize, SizeOf(CompressedSize));
  end;

begin
  Stream := TMemoryStream.Create;

  FileStream := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);

  if FileStream.Size=0 then begin
      Stream.Free;
      FileStream.Free;
      exit;
  end;

  try
    ZStream := TZCompressionStream.Create(Stream, zcMax);
    try
      FileStreamPos := FileStream.Position;
      FileStreamSize := FileStream.Size;
      { (RB) ZStream has an OnProgress event, thus CopyFrom can be used }
      repeat
        Count := FileStream.Read(Buffer, SizeOf(Buffer));
        Inc(FileStreamPos, Count);
        if Count > 0 then
          ZStream.Write(Buffer, Count);
        //DoProgress(FileStreamPos, FileStreamSize);
      until (Count = 0);
    finally
      ZStream.Free;
    end;

    WriteFileRecord(Directory, FileName, FileStreamSize, Stream.Size);

    DestStream.CopyFrom(Stream, 0);
  finally
    FileStream.Free;
    Stream.Free;
  end;
end;


procedure CompressDirectory(const Directory: string; Recursive: Boolean; const FileName: string);
var
  TmpStream: TStream;
begin
  // don't create file until we save it so we don't accidentally
  // try to compress ourselves!
  DeleteFile(FileName); // make sure we don't compress a previous archive into ourselves
  TmpStream := CompressDirectory(Directory, Recursive);
  try
    TMemoryStream(TmpStream).SaveToFile(FileName);
  finally
    TmpStream.Free;
  end;
end;


function CompressFiles(Files: TStrings): TStream;
var
  I: Integer;
  S1, S2, Common: string;
begin
  { (RB) Letting this function create a stream is not a good idea;
         see other CompressFiles function that causes a memory leak }
  Result := TMemoryStream.Create;
  if Files.Count = 0 then
    Exit;

  //Find the biggest Common part of all files
  S1 := UpperCase(Files[0]);
  for I := 1 to Files.Count - 1 do
  begin
    S2 := Files[I];
    while (Pos(S1, S2) = 0) and (S1 <> '') do
      S1 := Copy(S1, 1, Length(S1) - 1);
  end;
  { (RB) This should be Common := S1 (?) }
  Common := S2;

  //Add the files to the stream
  for I := 0 to Files.Count - 1 do
  begin
    S1 := ExtractFileName(Files[I]);
    S2 := ExtractFilePath(Files[I]);
    S2 := Copy(S2, 1, Length(Common));
    AddFile(S1, S2, Files[I], Result);
  end;

  Result.Position := 0;
end;

procedure CompressFiles(Files: TStrings; const FileName: string);
var
  TmpStream: TStream;
begin
  TmpStream := CompressFiles(Files);
  try
    TMemoryStream(TmpStream).SaveToFile(FileName);
  finally
    TmpStream.Free;
  end;
end;

procedure DecompressStream(Stream: TStream; Directory: string; Overwrite: Boolean; const RelativePaths: Boolean);
var
  FileStream: TFileStream;
  ZStream: TZDecompressionStream;
  CStream: TMemoryStream;
  B, LastPos: Byte;
  AnsiS: AnsiString;
  S: string;
  Count, FileSize, I: Integer;
  Buffer: array [0..1023] of Byte;
  TotalByteCount: Longword;
  WriteMe: Boolean; // Allow skipping of files instead of writing them.
  FileStreamSize, StreamSize: Int64;
  fd: string; // name of directory to be made if it doesn't exist (unless we're skipping it)
begin
  if Directory <> '' then
    Directory := IncludeTrailingPathDelimiter(Directory);

  StreamSize := Stream.Size; // cache, to not FileSeek on every iteration
  while Stream.Position < StreamSize do
  begin
    //Read and force the directory
    Stream.Read(B, SizeOf(B));
    SetLength(AnsiS, B);
    if B > 0 then
      Stream.Read(AnsiS[1], B);
    S := string(AnsiS);

    fd := Directory + S;

      ForceDirectories(fd);

    if S <> '' then
      S := IncludeTrailingPathDelimiter(S);

    //This make files decompress either on Directory or Directory+SavedRelativePath
    if not RelativePaths then
      S := '';

    //Read filename
    Stream.Read(B, SizeOf(B));
    if B > 0 then
    begin
      AnsiS := AnsiString(S);
      LastPos := Length(AnsiS);
      SetLength(AnsiS, LastPos + B);
      Stream.Read(AnsiS[LastPos + 1], B);
      S := string(AnsiS);
    end;

    Stream.Read(FileSize, SizeOf(FileSize));
    Stream.Read(I, SizeOf(I));
    CStream := TMemoryStream.Create;

    try
      CStream.CopyFrom(Stream, I);
      CStream.Position := 0;

      //Decompress the file
      S := Directory + S;
      if Overwrite or not FileExists(S) then
      begin
        //This fails if Directory isn't empty
        WriteMe := True;

        if WriteMe then
          FileStream := TFileStream.Create(S, fmCreate or fmShareExclusive)
        else
          FileStream := nil; // skip it!

        ZStream := TZDecompressionStream.Create(CStream);
        try
          TotalByteCount := 0;

          { (RB) ZStream has an OnProgress event, thus copyfrom can be used }
          FileStreamSize := 0;
          repeat
            Count := ZStream.Read(Buffer, SizeOf(Buffer));
            if Assigned(FileStream) then
            begin
              Inc(FileStreamSize, FileStream.Write(Buffer, Count));
//              DoProgress(FileStreamSize, FileSize);
            end;
            Inc(TotalByteCount, Count);
          until (Count = 0);
        finally
          FreeAndNil(FileStream);
          ZStream.Free;
        end;
      end;
    finally
      CStream.Free;
    end;
  end;
end;

procedure DecompressFile(const FileName, Directory: string; Overwrite: Boolean; const RelativePaths: Boolean);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Stream.Position := 0;
    DecompressStream(Stream, Directory, Overwrite, RelativePaths);
  finally
    Stream.Free;
  end;
end;

procedure CompressFile(FileName: string; CompressedFileName: string);
var
 tmp: TStringList;
begin
 tmp:=TStringList.Create;
 tmp.Add(FileName);
 CompressFiles(tmp, CompressedFileName);
 tmp.Free;
end;

end.
