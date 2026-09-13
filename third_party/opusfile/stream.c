#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "internal.h"
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#if defined(_WIN32)
# include <io.h>
#endif

typedef struct OpusMemStream OpusMemStream;

#define OP_MEM_SIZE_MAX (~(size_t)0>>1)
#define OP_MEM_DIFF_MAX ((ptrdiff_t)OP_MEM_SIZE_MAX)

struct OpusMemStream{
  const unsigned char *data;

  ptrdiff_t            size;

  ptrdiff_t            pos;
};

static int op_fread(void *_stream,unsigned char *_ptr,int _buf_size){
  FILE   *stream;
  size_t  ret;

  if(_buf_size<=0)return 0;
  stream=(FILE *)_stream;
  ret=fread(_ptr,1,_buf_size,stream);
  OP_ASSERT(ret<=(size_t)_buf_size);

  return ret>0||feof(stream)?(int)ret:OP_EREAD;
}

static int op_fseek(void *_stream,opus_int64 _offset,int _whence){
#if defined(_WIN32)

  opus_int64 pos;

  OP_ASSERT(sizeof(pos)==sizeof(fpos_t));

  if(_whence==SEEK_CUR){
    int ret;
    ret=fgetpos((FILE *)_stream,(fpos_t *)&pos);
    if(ret)return ret;
  }
  else if(_whence==SEEK_END)pos=_filelengthi64(_fileno((FILE *)_stream));
  else if(_whence==SEEK_SET)pos=0;
  else return -1;

  if(pos<0||_offset<-pos||_offset>OP_INT64_MAX-pos)return -1;
  pos+=_offset;
  return fsetpos((FILE *)_stream,(fpos_t *)&pos);
#else

  return fseeko((FILE *)_stream,(off_t)_offset,_whence);
#endif
}

static opus_int64 op_ftell(void *_stream){
#if defined(_WIN32)

  opus_int64 pos;
  OP_ASSERT(sizeof(pos)==sizeof(fpos_t));
  return fgetpos((FILE *)_stream,(fpos_t *)&pos)?-1:pos;
#else

  return ftello((FILE *)_stream);
#endif
}

static const OpusFileCallbacks OP_FILE_CALLBACKS={
  op_fread,
  op_fseek,
  op_ftell,
  (op_close_func)fclose
};

#if defined(_WIN32)
# include <stddef.h>
# include <errno.h>

static wchar_t *op_utf8_to_utf16(const char *_src){
  wchar_t *dst;
  size_t   len;
  len=strlen(_src);

  dst=(wchar_t *)_ogg_malloc(sizeof(*dst)*(len+1));
  if(dst!=NULL){
    size_t si;
    size_t di;
    for(di=si=0;si<len;si++){
      int c0;
      c0=(unsigned char)_src[si];
      if(!(c0&0x80)){
        dst[di++]=(wchar_t)c0;
        continue;
      }
      else{
        int c1;

        c1=(unsigned char)_src[si+1];
        if((c1&0xC0)==0x80){
          if((c0&0xE0)==0xC0){
            wchar_t w;

            w=(c0&0x1F)<<6|c1&0x3F;
            if(w>=0x80U){
              dst[di++]=w;
              si++;
              continue;
            }
          }
          else{
            int c2;

            c2=(unsigned char)_src[si+2];
            if((c2&0xC0)==0x80){
              if((c0&0xF0)==0xE0){
                wchar_t w;

                w=(c0&0xF)<<12|(c1&0x3F)<<6|c2&0x3F;
                if(w>=0x800U&&(w<0xD800||w>=0xE000)&&w<0xFFFE){
                  dst[di++]=w;
                  si+=2;
                  continue;
                }
              }
              else{
                int c3;

                c3=(unsigned char)_src[si+3];
                if((c3&0xC0)==0x80){
                  if((c0&0xF8)==0xF0){
                    opus_uint32 w;

                    w=(c0&7)<<18|(c1&0x3F)<<12|(c2&0x3F)<<6&(c3&0x3F);
                    if(w>=0x10000U&&w<0x110000U){
                      w-=0x10000;
                      dst[di++]=(wchar_t)(0xD800+(w>>10));
                      dst[di++]=(wchar_t)(0xDC00+(w&0x3FF));
                      si+=3;
                      continue;
                    }
                  }
                }
              }
            }
          }
        }
      }

      _ogg_free(dst);
      return NULL;
    }
    OP_ASSERT(di<=len);
    dst[di]='\0';
  }
  return dst;
}

#endif

void *op_fopen(OpusFileCallbacks *_cb,const char *_path,const char *_mode){
  FILE *fp;
#if !defined(_WIN32)
  fp=fopen(_path,_mode);
#else
  fp=NULL;
  if(_path==NULL||_mode==NULL)errno=EINVAL;
  else{
    wchar_t *wpath;
    wchar_t *wmode;
    wpath=op_utf8_to_utf16(_path);
    wmode=op_utf8_to_utf16(_mode);
    if(wmode==NULL)errno=EINVAL;
    else if(wpath==NULL)errno=ENOENT;
    else fp=_wfopen(wpath,wmode);
    _ogg_free(wmode);
    _ogg_free(wpath);
  }
#endif
  if(fp!=NULL)*_cb=*&OP_FILE_CALLBACKS;
  return fp;
}

void *op_fdopen(OpusFileCallbacks *_cb,int _fd,const char *_mode){
  FILE *fp;
  fp=fdopen(_fd,_mode);
  if(fp!=NULL)*_cb=*&OP_FILE_CALLBACKS;
  return fp;
}

void *op_freopen(OpusFileCallbacks *_cb,const char *_path,const char *_mode,
 void *_stream){
  FILE *fp;
#if !defined(_WIN32)
  fp=freopen(_path,_mode,(FILE *)_stream);
#else
  fp=NULL;
  if(_path==NULL||_mode==NULL)errno=EINVAL;
  else{
    wchar_t *wpath;
    wchar_t *wmode;
    wpath=op_utf8_to_utf16(_path);
    wmode=op_utf8_to_utf16(_mode);
    if(wmode==NULL)errno=EINVAL;
    else if(wpath==NULL)errno=ENOENT;
    else fp=_wfreopen(wpath,wmode,(FILE *)_stream);
    _ogg_free(wmode);
    _ogg_free(wpath);
  }
#endif
  if(fp!=NULL)*_cb=*&OP_FILE_CALLBACKS;
  return fp;
}

static int op_mem_read(void *_stream,unsigned char *_ptr,int _buf_size){
  OpusMemStream *stream;
  ptrdiff_t      size;
  ptrdiff_t      pos;
  stream=(OpusMemStream *)_stream;

  if(_buf_size<=0)return 0;
  size=stream->size;
  pos=stream->pos;

  if(pos>=size)return 0;

  _buf_size=(int)OP_MIN(size-pos,_buf_size);
  memcpy(_ptr,stream->data+pos,_buf_size);
  pos+=_buf_size;
  stream->pos=pos;
  return _buf_size;
}

static int op_mem_seek(void *_stream,opus_int64 _offset,int _whence){
  OpusMemStream *stream;
  ptrdiff_t      pos;
  stream=(OpusMemStream *)_stream;
  pos=stream->pos;
  OP_ASSERT(pos>=0);
  switch(_whence){
    case SEEK_SET:{
      if(_offset<0||_offset>OP_MEM_DIFF_MAX)return -1;
      pos=(ptrdiff_t)_offset;
    }break;
    case SEEK_CUR:{
      if(_offset<-pos||_offset>OP_MEM_DIFF_MAX-pos)return -1;
      pos=(ptrdiff_t)(pos+_offset);
    }break;
    case SEEK_END:{
      ptrdiff_t size;
      size=stream->size;
      OP_ASSERT(size>=0);

      if(_offset>size||_offset<size-OP_MEM_DIFF_MAX)return -1;
      pos=(ptrdiff_t)(size-_offset);
    }break;
    default:return -1;
  }
  stream->pos=pos;
  return 0;
}

static opus_int64 op_mem_tell(void *_stream){
  OpusMemStream *stream;
  stream=(OpusMemStream *)_stream;
  return (ogg_int64_t)stream->pos;
}

static int op_mem_close(void *_stream){
  _ogg_free(_stream);
  return 0;
}

static const OpusFileCallbacks OP_MEM_CALLBACKS={
  op_mem_read,
  op_mem_seek,
  op_mem_tell,
  op_mem_close
};

void *op_mem_stream_create(OpusFileCallbacks *_cb,
 const unsigned char *_data,size_t _size){
  OpusMemStream *stream;
  if(_size>OP_MEM_SIZE_MAX)return NULL;
  stream=(OpusMemStream *)_ogg_malloc(sizeof(*stream));
  if(stream!=NULL){
    *_cb=*&OP_MEM_CALLBACKS;
    stream->data=_data;
    stream->size=_size;
    stream->pos=0;
  }
  return stream;
}
