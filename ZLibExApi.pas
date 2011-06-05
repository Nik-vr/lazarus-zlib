{*****************************************************************************
*  ZLibExApi.pas                                                             *
*                                                                            *
*  copyright (c) 2010 Nikolay Petrochenko                                    *
*  copyright (c) 2000-2010 base2 technologies                                *
*  copyright (c) 1995-2002 Borland Software Corporation                      *
*                                                                            *
*  revision history                                                          *
*    13.12.2010  first version, compiled in Lazarus                          *
*    20.04.2010  updated to zlib version 1.2.5                               *
*                                                                            *
*****************************************************************************}

unit ZLibExApi;

interface

const
  {** version ids ***********************************************************}

  ZLIB_VERSION         = '1.2.5';
  ZLIB_VERNUM          = $1250;

  ZLIB_VER_MAJOR       = 1;
  ZLIB_VER_MINOR       = 2;
  ZLIB_VER_REVISION    = 5;
  ZLIB_VER_SUBREVISION = 0;

  {** compression methods ***************************************************}

  Z_DEFLATED = 8;

  {** information flags *****************************************************}

  Z_INFO_FLAG_SIZE  = $1;
  Z_INFO_FLAG_CRC   = $2;
  Z_INFO_FLAG_ADLER = $4;

  Z_INFO_NONE       = 0;
  Z_INFO_DEFAULT    = Z_INFO_FLAG_SIZE or Z_INFO_FLAG_CRC;

  {** flush constants *******************************************************}

  Z_NO_FLUSH      = 0;
  Z_PARTIAL_FLUSH = 1;
  Z_SYNC_FLUSH    = 2;
  Z_FULL_FLUSH    = 3;
  Z_FINISH        = 4;
  Z_BLOCK         = 5;
  Z_TREES         = 6;

  {** return codes **********************************************************}

  Z_OK            = 0;
  Z_STREAM_END    = 1;
  Z_NEED_DICT     = 2;
  Z_ERRNO         = (-1);
  Z_STREAM_ERROR  = (-2);
  Z_DATA_ERROR    = (-3);
  Z_MEM_ERROR     = (-4);
  Z_BUF_ERROR     = (-5);
  Z_VERSION_ERROR = (-6);

  {** compression levels ****************************************************}

  Z_NO_COMPRESSION      =   0;
  Z_BEST_SPEED          =   1;
  Z_BEST_COMPRESSION    =   9;
  Z_DEFAULT_COMPRESSION = (-1);

  {** compression strategies ************************************************}

  Z_FILTERED         = 1;
  Z_HUFFMAN_ONLY     = 2;
  Z_RLE              = 3;
  Z_FIXED            = 4;
  Z_DEFAULT_STRATEGY = 0;

  {** data types ************************************************************}

  Z_BINARY  = 0;
  Z_ASCII   = 1;
  Z_TEXT    = Z_ASCII;
  Z_UNKNOWN = 2;

  {** return code messages **************************************************}

  _z_errmsg: Array [0..9] of String = (
    'Need dictionary',      // Z_NEED_DICT      (2)
    'Stream end',           // Z_STREAM_END     (1)
    'OK',                   // Z_OK             (0)
    'File error',           // Z_ERRNO          (-1)
    'Stream error',         // Z_STREAM_ERROR   (-2)
    'Data error',           // Z_DATA_ERROR     (-3)
    'Insufficient memory',  // Z_MEM_ERROR      (-4)
    'Buffer error',         // Z_BUF_ERROR      (-5)
    'Incompatible version', // Z_VERSION_ERROR  (-6)
    ''
  );

type
  TZAlloc = function (opaque: Pointer; items, size: Integer): Pointer;
  TZFree  = procedure (opaque, block: Pointer);

  {** TZStreamRec ***********************************************************}

  TZStreamRec = packed record
    next_in  : Pointer;   // next input byte
    avail_in : Longint;   // number of bytes available at next_in
    total_in : Longint;   // total nb of input bytes read so far

    next_out : Pointer;   // next output byte should be put here
    avail_out: Longint;   // remaining free space at next_out
    total_out: Longint;   // total nb of bytes output so far

    msg      : Pointer;   // last error message, NULL if no error
    state    : Pointer;   // not visible by applications

    zalloc   : TZAlloc;   // used to allocate the internal state
    zfree    : TZFree;    // used to free the internal state
    opaque   : Pointer;   // private data object passed to zalloc and zfree

    data_type: Integer;   // best guess about the data type: ascii or binary
    adler    : Longint;   // adler32 value of the uncompressed data
    reserved : Longint;   // reserved for future use
  end;

{** macros ******************************************************************}

function deflateInit(var strm: TZStreamRec; level: Integer): Integer;

function deflateInit2(var strm: TZStreamRec; level, method, windowBits,
  memLevel, strategy: Integer): Integer;

function inflateInit(var strm: TZStreamRec): Integer;

function inflateInit2(var strm: TZStreamRec; windowBits: Integer): Integer;

{** external routines *******************************************************}

function deflateInit_(var strm: TZStreamRec; level: Integer;
  version: PAnsiChar; recsize: Integer): Integer; cdecl; external;

function deflateInit2_(var strm: TZStreamRec; level, method, windowBits,
  memLevel, strategy: Integer; version: PAnsiChar; recsize: Integer): Integer; cdecl; external;

function deflate(var strm: TZStreamRec; flush: Integer): Integer; cdecl; external;

function deflateEnd(var strm: TZStreamRec): Integer; cdecl; external;

function deflateReset(var strm: TZStreamRec): Integer; cdecl; external;

function inflateInit_(var strm: TZStreamRec; version: PAnsiChar;
  recsize: Integer): Integer; cdecl; external;

function inflateInit2_(var strm: TZStreamRec; windowBits: Integer;
  version: PAnsiChar; recsize: Integer): Integer; cdecl; external;

function inflate(var strm: TZStreamRec; flush: Integer): Integer; cdecl; external;

function inflateEnd(var strm: TZStreamRec): Integer; cdecl; external;

function inflateReset(var strm: TZStreamRec): Integer; cdecl; external;

function adler32(adler: Longint; const buf; len: Integer): Longint; cdecl; external;

function crc32(crc: Longint; const buf; len: Integer): Longint; cdecl; external;

implementation

{*****************************************************************************
*  link zlib code                                                            *
*                                                                            *
*  to make in gcc use:                                                       *
*    make LOC=-DASMV OBJA=match.o -f makefile.gcc                            *
*****************************************************************************}

{$IFDEF FPC}
 {$IFDEF WIN32}
  {$I win32-obj.inc}
 {$ENDIF}
{$ENDIF}

function _malloc(Size: Integer): Pointer; cdecl; [public, alias: '_malloc'];
begin
  Result:=AllocMem(Size);
end;

procedure _free(Block: Pointer); cdecl; [public, alias: '_free'];
begin
  FreeMem(Block);
end;

{** macros ******************************************************************}

function deflateInit(var strm: TZStreamRec; level: Integer): Integer;
begin
  result := deflateInit_(strm, level, ZLIB_VERSION, SizeOf(TZStreamRec));
end;

function deflateInit2(var strm: TZStreamRec; level, method, windowBits,
  memLevel, strategy: Integer): Integer;
begin
  result := deflateInit2_(strm, level, method, windowBits,
    memLevel, strategy, ZLIB_VERSION, SizeOf(TZStreamRec));
end;

function inflateInit(var strm: TZStreamRec): Integer;
begin
  result := inflateInit_(strm, ZLIB_VERSION, SizeOf(TZStreamRec));
end;

function inflateInit2(var strm: TZStreamRec; windowBits: Integer): Integer;
begin
  result := inflateInit2_(strm, windowBits, ZLIB_VERSION,
    SizeOf(TZStreamRec));
end;


{** zlib function implementations *******************************************}

function zcalloc(opaque: Pointer; items, size: Integer): Pointer;
begin
  GetMem(result,items * size);
end;

procedure zcfree(opaque, block: Pointer);
begin
  FreeMem(block);
end;

{** c function implementations **********************************************}

procedure _memset(p: Pointer; b: Byte; count: Integer); cdecl;
begin
  FillChar(p^,count,b);
end;

procedure _memcpy(dest, source: Pointer; count: Integer); cdecl;
begin
  Move(source^,dest^,count);
end;

end.
