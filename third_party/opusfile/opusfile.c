#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <limits.h>
#include <string.h>
#include <math.h>

#include "opusfile.h"

#define OP_PAGE_SIZE_MAX  (65307)

#define OP_CHUNK_SIZE     (65536)

#define OP_CHUNK_SIZE_MAX (1024*(opus_int32)1024)

#define OP_READ_SIZE      (2048)

int op_test(OpusHead *_head,
 const unsigned char *_initial_data,size_t _initial_bytes){
  ogg_sync_state  oy;
  char           *data;
  int             err;

  if(_initial_bytes<47)return OP_FALSE;

  if(memcmp(_initial_data,"OggS",4)!=0)return OP_ENOTFORMAT;
  ogg_sync_init(&oy);
  data=ogg_sync_buffer(&oy,_initial_bytes);
  if(data!=NULL){
    ogg_stream_state os;
    ogg_page         og;
    int              ret;
    memcpy(data,_initial_data,_initial_bytes);
    ogg_sync_wrote(&oy,_initial_bytes);
    ogg_stream_init(&os,-1);
    err=OP_FALSE;
    do{
      ogg_packet op;
      ret=ogg_sync_pageout(&oy,&og);

      if(ret<0)continue;

      if(!ret)break;
      ogg_stream_reset_serialno(&os,ogg_page_serialno(&og));
      ogg_stream_pagein(&os,&og);

      if(ogg_stream_packetout(&os,&op)==1){
        if(op.b_o_s){
          ret=opus_head_parse(_head,op.packet,op.bytes);

          if(ret==OP_ENOTFORMAT)continue;

          err=ret;
        }

        else err=OP_ENOTFORMAT;
      }
    }
    while(err==OP_FALSE);
    ogg_stream_clear(&os);
  }
  else err=OP_EFAULT;
  ogg_sync_clear(&oy);
  return err;
}

static int op_get_data(OggOpusFile *_of,int _nbytes){
  unsigned char *buffer;
  int            nbytes;
  OP_ASSERT(_nbytes>0);
  buffer=(unsigned char *)ogg_sync_buffer(&_of->oy,_nbytes);
  nbytes=(int)(*_of->callbacks.read)(_of->source,buffer,_nbytes);
  OP_ASSERT(nbytes<=_nbytes);
  if(OP_LIKELY(nbytes>0))ogg_sync_wrote(&_of->oy,nbytes);
  return nbytes;
}

static int op_seek_helper(OggOpusFile *_of,opus_int64 _offset){
  if(_offset==_of->offset)return 0;
  if(_of->callbacks.seek==NULL||
   (*_of->callbacks.seek)(_of->source,_offset,SEEK_SET)){
    return OP_EREAD;
  }
  _of->offset=_offset;
  ogg_sync_reset(&_of->oy);
  return 0;
}

static opus_int64 op_position(const OggOpusFile *_of){
  return _of->offset+_of->oy.fill-_of->oy.returned;
}

static opus_int64 op_get_next_page(OggOpusFile *_of,ogg_page *_og,
 opus_int64 _boundary){
  while(_boundary<=0||_of->offset<_boundary){
    int more;
    more=ogg_sync_pageseek(&_of->oy,_og);

    if(OP_UNLIKELY(more<0))_of->offset-=more;
    else if(more==0){
      int read_nbytes;
      int ret;

      if(!_boundary)return OP_FALSE;
      if(_boundary<0)read_nbytes=OP_READ_SIZE;
      else{
        opus_int64 position;
        position=op_position(_of);
        if(position>=_boundary)return OP_FALSE;
        read_nbytes=(int)OP_MIN(_boundary-position,OP_READ_SIZE);
      }
      ret=op_get_data(_of,read_nbytes);
      if(OP_UNLIKELY(ret<0))return OP_EREAD;
      if(OP_UNLIKELY(ret==0)){
        return OP_UNLIKELY(_boundary<0)?OP_FALSE:OP_EBADLINK;
      }
    }
    else{
      opus_int64 page_offset;
      page_offset=_of->offset;
      _of->offset+=more;
      OP_ASSERT(page_offset>=0);
      return page_offset;
    }
  }
  return OP_FALSE;
}

static int op_add_serialno(const ogg_page *_og,
 ogg_uint32_t **_serialnos,int *_nserialnos,int *_cserialnos){
  ogg_uint32_t *serialnos;
  int           nserialnos;
  int           cserialnos;
  ogg_uint32_t s;
  s=ogg_page_serialno(_og);
  serialnos=*_serialnos;
  nserialnos=*_nserialnos;
  cserialnos=*_cserialnos;
  if(OP_UNLIKELY(nserialnos>=cserialnos)){
    if(OP_UNLIKELY(cserialnos>INT_MAX-1>>1))return OP_EFAULT;
    cserialnos=2*cserialnos+1;
    OP_ASSERT(nserialnos<cserialnos);
    serialnos=(ogg_uint32_t *)_ogg_realloc(serialnos,
     sizeof(*serialnos)*cserialnos);
    if(OP_UNLIKELY(serialnos==NULL))return OP_EFAULT;
  }
  serialnos[nserialnos++]=s;
  *_serialnos=serialnos;
  *_nserialnos=nserialnos;
  *_cserialnos=cserialnos;
  return 0;
}

static int op_lookup_serialno(ogg_uint32_t _s,
 const ogg_uint32_t *_serialnos,int _nserialnos){
  int i;
  for(i=0;i<_nserialnos&&_serialnos[i]!=_s;i++);
  return i<_nserialnos;
}

static int op_lookup_page_serialno(const ogg_page *_og,
 const ogg_uint32_t *_serialnos,int _nserialnos){
  return op_lookup_serialno(ogg_page_serialno(_og),_serialnos,_nserialnos);
}

typedef struct OpusSeekRecord OpusSeekRecord;

struct OpusSeekRecord{
  opus_int64   search_start;

  opus_int64   offset;

  opus_int32   size;

  ogg_uint32_t serialno;

  ogg_int64_t  gp;
};

static int op_get_prev_page_serial(OggOpusFile *_of,OpusSeekRecord *_sr,
 opus_int64 _offset,ogg_uint32_t _serialno,
 const ogg_uint32_t *_serialnos,int _nserialnos){
  OpusSeekRecord preferred_sr;
  ogg_page       og;
  opus_int64     begin;
  opus_int64     end;
  opus_int64     original_end;
  opus_int32     chunk_size;
  int            preferred_found;
  original_end=end=begin=_offset;
  preferred_found=0;
  _offset=-1;
  chunk_size=OP_CHUNK_SIZE;
  do{
    opus_int64 search_start;
    int        ret;
    OP_ASSERT(chunk_size>=OP_PAGE_SIZE_MAX);
    begin=OP_MAX(begin-chunk_size,0);
    ret=op_seek_helper(_of,begin);
    if(OP_UNLIKELY(ret<0))return ret;
    search_start=begin;
    while(_of->offset<end){
      opus_int64   llret;
      ogg_uint32_t serialno;
      llret=op_get_next_page(_of,&og,end);
      if(OP_UNLIKELY(llret<OP_FALSE))return (int)llret;
      else if(llret==OP_FALSE)break;
      serialno=ogg_page_serialno(&og);

      _sr->search_start=search_start;
      _sr->offset=_offset=llret;
      _sr->serialno=serialno;
      OP_ASSERT(_of->offset-_offset>=0);
      OP_ASSERT(_of->offset-_offset<=OP_PAGE_SIZE_MAX);
      _sr->size=(opus_int32)(_of->offset-_offset);
      _sr->gp=ogg_page_granulepos(&og);

      if(serialno==_serialno){
        preferred_found=1;
        *&preferred_sr=*_sr;
      }
      if(!op_lookup_serialno(serialno,_serialnos,_nserialnos)){
        preferred_found=0;
      }
      search_start=llret+1;
    }

    if(OP_UNLIKELY(!begin)&&OP_UNLIKELY(_offset<0))return OP_EBADLINK;

    chunk_size=OP_MIN(2*chunk_size,OP_CHUNK_SIZE_MAX);

    end=OP_MIN(begin+OP_PAGE_SIZE_MAX-1,original_end);
  }
  while(_offset<0);
  if(preferred_found)*_sr=*&preferred_sr;
  return 0;
}

static opus_int64 op_get_last_page(OggOpusFile *_of,ogg_int64_t *_gp,
 opus_int64 _offset,ogg_uint32_t _serialno,
 const ogg_uint32_t *_serialnos,int _nserialnos){
  ogg_page    og;
  ogg_int64_t gp;
  opus_int64  begin;
  opus_int64  end;
  opus_int64  original_end;
  opus_int32  chunk_size;

  OP_ASSERT(op_lookup_serialno(_serialno,_serialnos,_nserialnos));
  original_end=end=begin=_offset;
  _offset=-1;

  gp=-1;
  chunk_size=OP_CHUNK_SIZE;
  do{
    int left_link;
    int ret;
    OP_ASSERT(chunk_size>=OP_PAGE_SIZE_MAX);
    begin=OP_MAX(begin-chunk_size,0);
    ret=op_seek_helper(_of,begin);
    if(OP_UNLIKELY(ret<0))return ret;
    left_link=0;
    while(_of->offset<end){
      opus_int64   llret;
      ogg_uint32_t serialno;
      llret=op_get_next_page(_of,&og,end);
      if(OP_UNLIKELY(llret<OP_FALSE))return llret;
      else if(llret==OP_FALSE)break;
      serialno=ogg_page_serialno(&og);
      if(serialno==_serialno){
        ogg_int64_t page_gp;

        page_gp=ogg_page_granulepos(&og);
        if(page_gp!=-1){
          _offset=llret;
          gp=page_gp;
        }
      }
      else if(OP_UNLIKELY(!op_lookup_serialno(serialno,
       _serialnos,_nserialnos))){
        left_link=1;
      }
    }

    if((OP_UNLIKELY(left_link)||OP_UNLIKELY(!begin))&&OP_UNLIKELY(_offset<0)){
      return OP_EBADLINK;
    }

    chunk_size=OP_MIN(2*chunk_size,OP_CHUNK_SIZE_MAX);

    end=OP_MIN(begin+OP_PAGE_SIZE_MAX-1,original_end);
  }
  while(_offset<0);
  *_gp=gp;
  return _offset;
}

static int op_fetch_headers_impl(OggOpusFile *_of,OpusHead *_head,
 OpusTags *_tags,ogg_uint32_t **_serialnos,int *_nserialnos,
 int *_cserialnos,ogg_page *_og){
  ogg_packet op;
  int        ret;
  if(_serialnos!=NULL)*_nserialnos=0;

  while(ogg_page_bos(_og)){
    if(_serialnos!=NULL){
      if(OP_UNLIKELY(op_lookup_page_serialno(_og,*_serialnos,*_nserialnos))){
        return OP_EBADHEADER;
      }
      ret=op_add_serialno(_og,_serialnos,_nserialnos,_cserialnos);
      if(OP_UNLIKELY(ret<0))return ret;
    }
    if(_of->ready_state<OP_STREAMSET){
      ogg_stream_reset_serialno(&_of->os,ogg_page_serialno(_og));
      ogg_stream_pagein(&_of->os,_og);
      if(OP_LIKELY(ogg_stream_packetout(&_of->os,&op)>0)){
        ret=opus_head_parse(_head,op.packet,op.bytes);

        if(ret==OP_ENOTFORMAT)continue;

        if(OP_UNLIKELY(ret<0))return ret;

        _of->ready_state=OP_STREAMSET;
      }
    }

    if(OP_UNLIKELY(op_get_next_page(_of,_og,
     OP_ADV_OFFSET(_of->offset,OP_CHUNK_SIZE))<0)){
      return OP_ENOTFORMAT;
    }

    if(_of->ready_state==OP_STREAMSET
     &&_of->os.serialno==ogg_page_serialno(_og)){
      ogg_stream_pagein(&_of->os,_og);
      break;
    }
  }
  if(OP_UNLIKELY(_of->ready_state!=OP_STREAMSET))return OP_ENOTFORMAT;

  for(;;){
    switch(ogg_stream_packetout(&_of->os,&op)){
      case 0:{
        for(;;){
          if(OP_UNLIKELY(op_get_next_page(_of,_og,
           OP_ADV_OFFSET(_of->offset,OP_CHUNK_SIZE))<0)){
            return OP_EBADHEADER;
          }

          if(_of->os.serialno==ogg_page_serialno(_og)){
            ogg_stream_pagein(&_of->os,_og);
            break;
          }

          if(OP_UNLIKELY(ogg_page_bos(_og)))return OP_EBADHEADER;

        }
      }break;

      case -1:return OP_EBADHEADER;
      default:{
        ret=opus_tags_parse(_tags,op.packet,op.bytes);
        if(OP_UNLIKELY(ret<0))return ret;

        ret=ogg_stream_packetout(&_of->os,&op);
        if(OP_UNLIKELY(ret!=0)
         ||OP_UNLIKELY(_og->header[_og->header_len-1]==255)){
          opus_tags_clear(_tags);
          return OP_EBADHEADER;
        }
        return 0;
      }
    }
  }
}

static int op_fetch_headers(OggOpusFile *_of,OpusHead *_head,
 OpusTags *_tags,ogg_uint32_t **_serialnos,int *_nserialnos,
 int *_cserialnos,ogg_page *_og){
  ogg_page og;
  int      ret;
  if(!_og){
    if(OP_UNLIKELY(op_get_next_page(_of,&og,
     OP_ADV_OFFSET(_of->offset,OP_CHUNK_SIZE))<0)){
      return OP_ENOTFORMAT;
    }
    _og=&og;
  }
  _of->ready_state=OP_OPENED;
  ret=op_fetch_headers_impl(_of,_head,_tags,_serialnos,_nserialnos,
   _cserialnos,_og);

  if(OP_UNLIKELY(ret<0))_of->ready_state=OP_OPENED;
  return ret;
}

static int op_granpos_add(ogg_int64_t *_dst_gp,ogg_int64_t _src_gp,
 opus_int32 _delta){
  OP_ASSERT(_src_gp!=-1);
  if(_delta>0){
    if(OP_UNLIKELY(_src_gp<0)&&OP_UNLIKELY(_src_gp>=-1-_delta))return OP_EINVAL;
    if(OP_UNLIKELY(_src_gp>OP_INT64_MAX-_delta)){
      _delta-=(opus_int32)(OP_INT64_MAX-_src_gp)+1;
      _src_gp=OP_INT64_MIN;
    }
  }
  else if(_delta<0){
    if(_src_gp>=0&&OP_UNLIKELY(_src_gp<-_delta))return OP_EINVAL;
    if(OP_UNLIKELY(_src_gp<OP_INT64_MIN-_delta)){
      _delta+=(opus_int32)(_src_gp-OP_INT64_MIN)+1;
      _src_gp=OP_INT64_MAX;
    }
  }
  *_dst_gp=_src_gp+_delta;
  return 0;
}

static int op_granpos_diff(ogg_int64_t *_delta,
 ogg_int64_t _gp_a,ogg_int64_t _gp_b){
  int gp_a_negative;
  int gp_b_negative;

  OP_ASSERT(_gp_a!=-1);
  OP_ASSERT(_gp_b!=-1);
  gp_a_negative=OP_UNLIKELY(_gp_a<0);
  gp_b_negative=OP_UNLIKELY(_gp_b<0);
  if(OP_UNLIKELY(gp_a_negative^gp_b_negative)){
    ogg_int64_t da;
    ogg_int64_t db;
    if(gp_a_negative){
      da=(OP_INT64_MIN-_gp_a)-1;

      db=OP_INT64_MAX-_gp_b;

      if(OP_UNLIKELY(OP_INT64_MAX+da<db))return OP_EINVAL;
      *_delta=db-da;
    }
    else{
      da=_gp_a+OP_INT64_MIN;

      db=OP_INT64_MIN-_gp_b;

      if(OP_UNLIKELY(da<OP_INT64_MIN-db))return OP_EINVAL;
      *_delta=da+db;
    }
  }
  else *_delta=_gp_a-_gp_b;
  return 0;
}

static int op_granpos_cmp(ogg_int64_t _gp_a,ogg_int64_t _gp_b){
  OP_ASSERT(_gp_a!=-1);
  OP_ASSERT(_gp_b!=-1);

  if(OP_UNLIKELY(_gp_a<0)){
    if(_gp_b>=0)return 1;

  }
  else if(OP_UNLIKELY(_gp_b<0))return -1;

  return (_gp_a>_gp_b)-(_gp_b>_gp_a);
}

static int op_get_packet_duration(const unsigned char *_data,int _len){
  int nframes;
  int frame_size;
  int nsamples;
  nframes=opus_packet_get_nb_frames(_data,_len);
  if(OP_UNLIKELY(nframes<0))return OP_EBADPACKET;
  frame_size=opus_packet_get_samples_per_frame(_data,48000);
  nsamples=nframes*frame_size;
  if(OP_UNLIKELY(nsamples>120*48))return OP_EBADPACKET;
  return nsamples;
}

ogg_int64_t opus_granule_sample(const OpusHead *_head,ogg_int64_t _gp){
  opus_int32 pre_skip;
  pre_skip=_head->pre_skip;
  if(_gp!=-1&&op_granpos_add(&_gp,_gp,-pre_skip))_gp=-1;
  return _gp;
}

static opus_int32 op_collect_audio_packets(OggOpusFile *_of,
 int _durations[255]){
  opus_int32 total_duration;
  int        op_count;

  op_count=0;
  total_duration=0;
  for(;;){
    int ret;

    ret=ogg_stream_packetout(&_of->os,_of->op+op_count);
    if(!ret)break;
    if(OP_UNLIKELY(ret<0)){
      OP_ASSERT(op_count==0);

      total_duration=OP_HOLE;
      break;
    }

    OP_ASSERT(op_count<255);
    _durations[op_count]=op_get_packet_duration(_of->op[op_count].packet,
     _of->op[op_count].bytes);
    if(OP_LIKELY(_durations[op_count]>0)){
      total_duration+=_durations[op_count++];
    }

    else if(op_count>0){
      _of->op[op_count-1].granulepos=_of->op[op_count].granulepos;
    }
  }
  _of->op_pos=0;
  _of->op_count=op_count;
  return total_duration;
}

static int op_find_initial_pcm_offset(OggOpusFile *_of,
 OggOpusLink *_link,ogg_page *_og){
  ogg_page     og;
  ogg_int64_t  pcm_start;
  ogg_int64_t  prev_packet_gp;
  ogg_int64_t  cur_page_gp;
  ogg_uint32_t serialno;
  opus_int32   total_duration;
  int          durations[255];
  int          cur_page_eos;
  int          op_count;
  int          pi;
  if(_og==NULL)_og=&og;
  serialno=_of->os.serialno;
  op_count=0;

  total_duration=0;
  do{
    opus_int64 llret;
    llret=op_get_next_page(_of,_og,_of->end);

    if(OP_UNLIKELY(llret<0)){
      if(llret<OP_FALSE)return (int)llret;

      if(_link->head.pre_skip>0)return OP_EBADTIMESTAMP;

      _link->pcm_start=_link->pcm_end=0;
      _link->end_offset=_link->data_offset;
      return 0;
    }

    if(OP_UNLIKELY(ogg_page_bos(_og))){
      if(_link->head.pre_skip>0)return OP_EBADTIMESTAMP;

      _link->pcm_end=_link->pcm_start=0;
      _link->end_offset=_link->data_offset;

      return 1;
    }

    if(serialno!=(ogg_uint32_t)ogg_page_serialno(_og))continue;
    ogg_stream_pagein(&_of->os,_og);

    _of->bytes_tracked+=_og->header_len;

    do total_duration=op_collect_audio_packets(_of,durations);

    while(OP_UNLIKELY(total_duration<0));
    op_count=_of->op_count;
  }
  while(op_count<=0);

  cur_page_gp=_of->op[op_count-1].granulepos;

  if(cur_page_gp==-1)return OP_EBADTIMESTAMP;
  cur_page_eos=_of->op[op_count-1].e_o_s;
  if(OP_LIKELY(!cur_page_eos)){
    if(OP_UNLIKELY(op_granpos_add(&pcm_start,cur_page_gp,-total_duration)<0)){
      return OP_EBADTIMESTAMP;
    }
  }
  else{
    if(OP_LIKELY(op_granpos_add(&pcm_start,cur_page_gp,-total_duration)<0)){
      pcm_start=0;

      if(OP_UNLIKELY(op_granpos_cmp(cur_page_gp,_link->head.pre_skip)<0)){
        return OP_EBADTIMESTAMP;
      }
    }
  }

  prev_packet_gp=pcm_start;
  for(pi=0;pi<op_count;pi++){
    if(cur_page_eos){
      ogg_int64_t diff;
      OP_ALWAYS_TRUE(!op_granpos_diff(&diff,cur_page_gp,prev_packet_gp));
      diff=durations[pi]-diff;

      if(diff>0){
        if(OP_UNLIKELY(diff>durations[pi]))break;
        _of->op[pi].granulepos=prev_packet_gp=cur_page_gp;

        _of->op[pi].e_o_s=1;
        continue;
      }
    }

    OP_ALWAYS_TRUE(!op_granpos_add(&_of->op[pi].granulepos,
     prev_packet_gp,durations[pi]));
    prev_packet_gp=_of->op[pi].granulepos;
  }

  _of->op_count=pi;
  _of->cur_discard_count=_link->head.pre_skip;
  _of->prev_packet_gp=_link->pcm_start=pcm_start;
  return 0;
}

static int op_find_final_pcm_offset(OggOpusFile *_of,
 const ogg_uint32_t *_serialnos,int _nserialnos,OggOpusLink *_link,
 opus_int64 _offset,ogg_uint32_t _end_serialno,ogg_int64_t _end_gp,
 ogg_int64_t *_total_duration){
  ogg_int64_t  total_duration;
  ogg_int64_t  duration;
  ogg_uint32_t cur_serialno;

  cur_serialno=_link->serialno;
  if(_end_serialno!=cur_serialno||_end_gp==-1){
    _offset=op_get_last_page(_of,&_end_gp,_offset,
     cur_serialno,_serialnos,_nserialnos);
    if(OP_UNLIKELY(_offset<0))return (int)_offset;
  }

  if(OP_UNLIKELY(_offset<_link->data_offset))return OP_EBADLINK;

  if(OP_UNLIKELY(op_granpos_diff(&duration,_end_gp,_link->pcm_start)<0)
   ||OP_UNLIKELY(duration<_link->head.pre_skip)){
    return OP_EBADTIMESTAMP;
  }

  duration-=_link->head.pre_skip;
  total_duration=*_total_duration;
  if(OP_UNLIKELY(OP_INT64_MAX-duration<total_duration))return OP_EBADTIMESTAMP;
  *_total_duration=total_duration+duration;
  _link->pcm_end=_end_gp;
  _link->end_offset=_offset;
  return 0;
}

static opus_int64 op_rescale64(opus_int64 _x,opus_int64 _from,opus_int64 _to){
  opus_int64 frac;
  opus_int64 ret;
  int        i;
  if(_x>=_from)return _to;
  if(_x<=0)return 0;
  frac=0;
  for(i=0;i<63;i++){
    frac<<=1;
    OP_ASSERT(_x<=_from);
    if(_x>=_from>>1){
      _x-=_from-_x;
      frac|=1;
    }
    else _x<<=1;
  }
  ret=0;
  for(i=0;i<63;i++){
    if(frac&1)ret=(ret&_to&1)+(ret>>1)+(_to>>1);
    else ret>>=1;
    frac>>=1;
  }
  return ret;
}

#define OP_GP_SPACING_MIN (48000)

static opus_int64 op_predict_link_start(const OpusSeekRecord *_sr,int _nsr,
 opus_int64 _searched,opus_int64 _end_searched,opus_int32 _bias){
  opus_int64 bisect;
  int        sri;
  int        srj;

  _end_searched-=OP_CHUNK_SIZE;
  if(_searched>=_end_searched)return -1;
  bisect=_end_searched;
  for(sri=0;sri<_nsr;sri++){
    ogg_int64_t  gp1;
    ogg_int64_t  gp2_min;
    ogg_uint32_t serialno1;
    opus_int64   offset1;

    gp1=_sr[sri].gp;
    if(gp1<0)continue;

    if(OP_UNLIKELY(op_granpos_add(&gp2_min,gp1,OP_GP_SPACING_MIN)<0)){
      continue;
    }
    offset1=_sr[sri].offset;
    serialno1=_sr[sri].serialno;
    for(srj=sri;srj-->0;){
      ogg_int64_t gp2;
      opus_int64  offset2;
      opus_int64  num;
      ogg_int64_t den;
      ogg_int64_t ipart;
      gp2=_sr[srj].gp;
      if(gp2<gp2_min)continue;

      if(_sr[srj].serialno!=serialno1)continue;
      offset2=_sr[srj].offset;

      den=gp2-gp1;
      ipart=gp2/den;
      num=offset2-offset1;
      OP_ASSERT(num>0);
      if(ipart>0&&(offset2-_searched)/ipart<num)continue;
      offset2-=ipart*num;
      gp2-=ipart*den;
      offset2-=op_rescale64(gp2,den,num)-_bias;
      if(offset2<_searched)continue;
      bisect=OP_MIN(bisect,offset2);
      break;
    }
  }
  return bisect>=_end_searched?-1:bisect;
}

static int op_bisect_forward_serialno(OggOpusFile *_of,
 opus_int64 _searched,OpusSeekRecord *_sr,int _csr,
 ogg_uint32_t **_serialnos,int *_nserialnos,int *_cserialnos){
  ogg_page      og;
  OggOpusLink  *links;
  int           nlinks;
  int           clinks;
  ogg_uint32_t *serialnos;
  int           nserialnos;
  ogg_int64_t   total_duration;
  int           nsr;
  int           ret;
  links=_of->links;
  nlinks=clinks=_of->nlinks;
  total_duration=0;

  nsr=1;
  for(;;){
    opus_int64  end_searched;
    opus_int64  bisect;
    opus_int64  next;
    opus_int64  last;
    ogg_int64_t end_offset;
    ogg_int64_t end_gp;
    int         sri;
    serialnos=*_serialnos;
    nserialnos=*_nserialnos;
    if(OP_UNLIKELY(nlinks>=clinks)){
      if(OP_UNLIKELY(clinks>INT_MAX-1>>1))return OP_EFAULT;
      clinks=2*clinks+1;
      OP_ASSERT(nlinks<clinks);
      links=(OggOpusLink *)_ogg_realloc(links,sizeof(*links)*clinks);
      if(OP_UNLIKELY(links==NULL))return OP_EFAULT;
      _of->links=links;
    }

    for(sri=0;sri<nsr;sri++){
      if(op_lookup_serialno(_sr[sri].serialno,serialnos,nserialnos))break;
    }

    if(sri<=0)break;

    last=-1;
    end_searched=_sr[sri-1].search_start;
    next=_sr[sri-1].offset;
    end_gp=-1;
    if(sri<nsr){
      _searched=_sr[sri].offset+_sr[sri].size;
      if(_sr[sri].serialno==links[nlinks-1].serialno){
        end_gp=_sr[sri].gp;
        end_offset=_sr[sri].offset;
      }
    }
    nsr=sri;
    bisect=-1;

    if(nlinks>1){
      opus_int64 last_offset;
      opus_int64 avg_link_size;
      opus_int64 upper_limit;
      last_offset=links[nlinks-1].offset;
      avg_link_size=last_offset/(nlinks-1);
      upper_limit=end_searched-OP_CHUNK_SIZE-avg_link_size;
      if(OP_LIKELY(last_offset>_searched-avg_link_size)
       &&OP_LIKELY(last_offset<upper_limit)){
        bisect=last_offset+avg_link_size;
        if(OP_LIKELY(bisect<upper_limit))bisect+=avg_link_size;
      }
    }

    while(_searched<end_searched){
      opus_int32 next_bias;

      if(bisect==-1)bisect=_searched+(end_searched-_searched>>1);

      if(bisect-_searched<OP_CHUNK_SIZE)bisect=_searched;

      else end_gp=-1;
      ret=op_seek_helper(_of,bisect);
      if(OP_UNLIKELY(ret<0))return ret;
      last=op_get_next_page(_of,&og,_sr[nsr-1].offset);
      if(OP_UNLIKELY(last<OP_FALSE))return (int)last;
      next_bias=0;
      if(last==OP_FALSE)end_searched=bisect;
      else{
        ogg_uint32_t serialno;
        ogg_int64_t  gp;
        serialno=ogg_page_serialno(&og);
        gp=ogg_page_granulepos(&og);
        if(!op_lookup_serialno(serialno,serialnos,nserialnos)){
          end_searched=bisect;
          next=last;

          if(OP_LIKELY(nsr<_csr)){
            _sr[nsr].search_start=bisect;
            _sr[nsr].offset=last;
            OP_ASSERT(_of->offset-last>=0);
            OP_ASSERT(_of->offset-last<=OP_PAGE_SIZE_MAX);
            _sr[nsr].size=(opus_int32)(_of->offset-last);
            _sr[nsr].serialno=serialno;
            _sr[nsr].gp=gp;
            nsr++;
          }
        }
        else{
          _searched=_of->offset;
          next_bias=OP_CHUNK_SIZE;
          if(serialno==links[nlinks-1].serialno){
            end_gp=gp;
            end_offset=last;
          }
        }
      }
      bisect=op_predict_link_start(_sr,nsr,_searched,end_searched,next_bias);
    }

    if(OP_LIKELY(links[nlinks-1].pcm_end==-1)){
      if(end_gp==-1){
        end_offset=next;

        last=-1;
      }
      ret=op_find_final_pcm_offset(_of,serialnos,nserialnos,
       links+nlinks-1,end_offset,links[nlinks-1].serialno,end_gp,
       &total_duration);
      if(OP_UNLIKELY(ret<0))return ret;
    }
    if(last!=next){
      ret=op_seek_helper(_of,next);
      if(OP_UNLIKELY(ret<0))return ret;
    }
    ret=op_fetch_headers(_of,&links[nlinks].head,&links[nlinks].tags,
     _serialnos,_nserialnos,_cserialnos,last!=next?NULL:&og);
    if(OP_UNLIKELY(ret<0))return ret;
    links[nlinks].offset=next;
    links[nlinks].data_offset=_of->offset;
    links[nlinks].serialno=_of->os.serialno;
    links[nlinks].pcm_end=-1;

    ret=op_find_initial_pcm_offset(_of,links+nlinks,NULL);
    if(OP_UNLIKELY(ret<0))return ret;
    _searched=_of->offset;

    _of->nlinks=++nlinks;
  }

  if(OP_LIKELY(links[nlinks-1].pcm_end==-1)){
    ret=op_find_final_pcm_offset(_of,serialnos,nserialnos,
     links+nlinks-1,_sr[0].offset,_sr[0].serialno,_sr[0].gp,&total_duration);
    if(OP_UNLIKELY(ret<0))return ret;
  }

  links=(OggOpusLink *)_ogg_realloc(links,sizeof(*links)*nlinks);
  if(OP_LIKELY(links!=NULL))_of->links=links;

  _ogg_free(*_serialnos);
  *_serialnos=NULL;
  *_cserialnos=*_nserialnos=0;
  return 0;
}

static void op_update_gain(OggOpusFile *_of){
  OpusHead   *head;
  opus_int32  gain_q8;
  int         li;

  if(_of->ready_state<OP_INITSET)return;
  gain_q8=_of->gain_offset_q8;
  li=_of->seekable?_of->cur_link:0;
  head=&_of->links[li].head;

  switch(_of->gain_type){
    case OP_TRACK_GAIN:{
      int track_gain_q8;
      track_gain_q8=0;
      opus_tags_get_track_gain(&_of->links[li].tags,&track_gain_q8);
      gain_q8+=track_gain_q8;
    }

    case OP_HEADER_GAIN:gain_q8+=head->output_gain;break;
    case OP_ABSOLUTE_GAIN:break;
    default:OP_ASSERT(0);
  }
  gain_q8=OP_CLAMP(-32768,gain_q8,32767);
  OP_ASSERT(_of->od!=NULL);
#if defined(OPUS_SET_GAIN)
  opus_multistream_decoder_ctl(_of->od,OPUS_SET_GAIN(gain_q8));
#else

# error "libopus 1.0.1 or later required"
#endif
}

static int op_make_decode_ready(OggOpusFile *_of){
  const OpusHead *head;
  int             li;
  int             stream_count;
  int             coupled_count;
  int             channel_count;
  if(_of->ready_state>OP_STREAMSET)return 0;
  if(OP_UNLIKELY(_of->ready_state<OP_STREAMSET))return OP_EFAULT;
  li=_of->seekable?_of->cur_link:0;
  head=&_of->links[li].head;
  stream_count=head->stream_count;
  coupled_count=head->coupled_count;
  channel_count=head->channel_count;

  if(_of->od!=NULL&&_of->od_stream_count==stream_count
   &&_of->od_coupled_count==coupled_count&&_of->od_channel_count==channel_count
   &&memcmp(_of->od_mapping,head->mapping,
   sizeof(*head->mapping)*channel_count)==0){
    opus_multistream_decoder_ctl(_of->od,OPUS_RESET_STATE);
  }
  else{
    int err;
    opus_multistream_decoder_destroy(_of->od);
    _of->od=opus_multistream_decoder_create(48000,channel_count,
     stream_count,coupled_count,head->mapping,&err);
    if(_of->od==NULL)return OP_EFAULT;
    _of->od_stream_count=stream_count;
    _of->od_coupled_count=coupled_count;
    _of->od_channel_count=channel_count;
    memcpy(_of->od_mapping,head->mapping,sizeof(*head->mapping)*channel_count);
  }
  _of->ready_state=OP_INITSET;
  _of->bytes_tracked=0;
  _of->samples_tracked=0;
#if !defined(OP_FIXED_POINT)
  _of->state_channel_count=0;

  _of->dither_seed=_of->links[li].serialno;
#endif
  op_update_gain(_of);
  return 0;
}

static int op_open_seekable2_impl(OggOpusFile *_of){
  OpusSeekRecord sr[64];
  opus_int64     data_offset;
  int            ret;

  (*_of->callbacks.seek)(_of->source,0,SEEK_END);
  _of->offset=_of->end=(*_of->callbacks.tell)(_of->source);
  if(OP_UNLIKELY(_of->end<0))return OP_EREAD;
  data_offset=_of->links[0].data_offset;
  if(OP_UNLIKELY(_of->end<data_offset))return OP_EBADLINK;

  ret=op_get_prev_page_serial(_of,sr,_of->end,
   _of->links[0].serialno,_of->serialnos,_of->nserialnos);
  if(OP_UNLIKELY(ret<0))return ret;

  _of->end=sr[0].offset+sr[0].size;
  if(OP_UNLIKELY(_of->end<data_offset))return OP_EBADLINK;

  return op_bisect_forward_serialno(_of,data_offset,sr,sizeof(sr)/sizeof(*sr),
   &_of->serialnos,&_of->nserialnos,&_of->cserialnos);
}

static int op_open_seekable2(OggOpusFile *_of){
  ogg_sync_state    oy_start;
  ogg_stream_state  os_start;
  ogg_packet       *op_start;
  opus_int64        start_offset;
  int               start_op_count;
  int               ret;

  start_op_count=_of->op_count;

  op_start=(ogg_packet *)_ogg_malloc(sizeof(*op_start)*start_op_count);
  if(op_start==NULL)return OP_EFAULT;
  *&oy_start=_of->oy;
  *&os_start=_of->os;
  start_offset=_of->offset;
  memcpy(op_start,_of->op,sizeof(*op_start)*start_op_count);
  OP_ASSERT((*_of->callbacks.tell)(_of->source)==op_position(_of));
  ogg_sync_init(&_of->oy);
  ogg_stream_init(&_of->os,-1);
  ret=op_open_seekable2_impl(_of);

  ogg_stream_clear(&_of->os);
  ogg_sync_clear(&_of->oy);
  *&_of->oy=*&oy_start;
  *&_of->os=*&os_start;
  _of->offset=start_offset;
  _of->op_count=start_op_count;
  memcpy(_of->op,op_start,sizeof(*_of->op)*start_op_count);
  _ogg_free(op_start);
  _of->prev_packet_gp=_of->links[0].pcm_start;
  _of->cur_discard_count=_of->links[0].head.pre_skip;
  if(OP_UNLIKELY(ret<0))return ret;

  ret=(*_of->callbacks.seek)(_of->source,op_position(_of),SEEK_SET);
  return OP_UNLIKELY(ret<0)?OP_EREAD:0;
}

static void op_decode_clear(OggOpusFile *_of){
  _of->op_count=0;
  _of->od_buffer_size=0;
  _of->prev_packet_gp=-1;
  if(!_of->seekable){
    OP_ASSERT(_of->ready_state>=OP_INITSET);
    opus_tags_clear(&_of->links[0].tags);
  }
  _of->ready_state=OP_OPENED;
}

static void op_clear(OggOpusFile *_of){
  OggOpusLink *links;
  _ogg_free(_of->od_buffer);
  if(_of->od!=NULL)opus_multistream_decoder_destroy(_of->od);
  links=_of->links;
  if(!_of->seekable){
    if(_of->ready_state>OP_OPENED||_of->ready_state==OP_PARTOPEN){
      opus_tags_clear(&links[0].tags);
    }
  }
  else if(OP_LIKELY(links!=NULL)){
    int nlinks;
    int link;
    nlinks=_of->nlinks;
    for(link=0;link<nlinks;link++)opus_tags_clear(&links[link].tags);
  }
  _ogg_free(links);
  _ogg_free(_of->serialnos);
  ogg_stream_clear(&_of->os);
  ogg_sync_clear(&_of->oy);
  if(_of->callbacks.close!=NULL)(*_of->callbacks.close)(_of->source);
}

static int op_open1(OggOpusFile *_of,
 void *_source,const OpusFileCallbacks *_cb,
 const unsigned char *_initial_data,size_t _initial_bytes){
  ogg_page  og;
  ogg_page *pog;
  int       seekable;
  int       ret;
  memset(_of,0,sizeof(*_of));
  _of->end=-1;
  _of->source=_source;
  *&_of->callbacks=*_cb;

  if(OP_UNLIKELY(_of->callbacks.read==NULL))return OP_EREAD;

  ogg_sync_init(&_of->oy);

  if(_initial_bytes>0){
    char *buffer;
    buffer=ogg_sync_buffer(&_of->oy,_initial_bytes);
    memcpy(buffer,_initial_data,_initial_bytes*sizeof(*buffer));
    ogg_sync_wrote(&_of->oy,_initial_bytes);
  }

  seekable=_cb->seek!=NULL&&(*_cb->seek)(_source,0,SEEK_CUR)!=-1;

  if(seekable){
    opus_int64 pos;
    if(OP_UNLIKELY(_of->callbacks.tell==NULL))return OP_EINVAL;
    pos=(*_of->callbacks.tell)(_of->source);

    if(OP_UNLIKELY(pos!=(opus_int64)_initial_bytes))return OP_EINVAL;
  }
  _of->seekable=seekable;

  _of->links=(OggOpusLink *)_ogg_malloc(sizeof(*_of->links));

  ogg_stream_init(&_of->os,-1);
  pog=NULL;
  for(;;){
    ret=op_fetch_headers(_of,&_of->links[0].head,&_of->links[0].tags,
     &_of->serialnos,&_of->nserialnos,&_of->cserialnos,pog);
    if(OP_UNLIKELY(ret<0))break;
    _of->nlinks=1;
    _of->links[0].offset=0;
    _of->links[0].data_offset=_of->offset;
    _of->links[0].pcm_end=-1;
    _of->links[0].serialno=_of->os.serialno;

    ret=op_find_initial_pcm_offset(_of,_of->links,&og);
    if(seekable||OP_LIKELY(ret<=0))break;

    opus_tags_clear(&_of->links[0].tags);
    _of->nlinks=0;
    if(!seekable)_of->cur_link++;
    pog=&og;
  }
  if(OP_LIKELY(ret>=0))_of->ready_state=OP_PARTOPEN;
  return ret;
}

static int op_open2(OggOpusFile *_of){
  int ret;
  OP_ASSERT(_of->ready_state==OP_PARTOPEN);
  if(_of->seekable){
    _of->ready_state=OP_OPENED;
    ret=op_open_seekable2(_of);
  }
  else ret=0;
  if(OP_LIKELY(ret>=0)){
    _of->ready_state=OP_STREAMSET;
    ret=op_make_decode_ready(_of);
    if(OP_LIKELY(ret>=0))return 0;
  }

  _of->callbacks.close=NULL;
  op_clear(_of);
  return ret;
}

OggOpusFile *op_test_callbacks(void *_source,const OpusFileCallbacks *_cb,
 const unsigned char *_initial_data,size_t _initial_bytes,int *_error){
  OggOpusFile *of;
  int          ret;
  of=(OggOpusFile *)_ogg_malloc(sizeof(*of));
  ret=OP_EFAULT;
  if(OP_LIKELY(of!=NULL)){
    ret=op_open1(of,_source,_cb,_initial_data,_initial_bytes);
    if(OP_LIKELY(ret>=0)){
      if(_error!=NULL)*_error=0;
      return of;
    }

    of->callbacks.close=NULL;
    op_clear(of);
    _ogg_free(of);
  }
  if(_error!=NULL)*_error=ret;
  return NULL;
}

OggOpusFile *op_open_callbacks(void *_source,const OpusFileCallbacks *_cb,
 const unsigned char *_initial_data,size_t _initial_bytes,int *_error){
  OggOpusFile *of;
  of=op_test_callbacks(_source,_cb,_initial_data,_initial_bytes,_error);
  if(OP_LIKELY(of!=NULL)){
    int ret;
    ret=op_open2(of);
    if(OP_LIKELY(ret>=0))return of;
    if(_error!=NULL)*_error=ret;
    _ogg_free(of);
  }
  return NULL;
}

static OggOpusFile *op_open_close_on_failure(void *_source,
 const OpusFileCallbacks *_cb,int *_error){
  OggOpusFile *of;
  if(OP_UNLIKELY(_source==NULL)){
    if(_error!=NULL)*_error=OP_EFAULT;
    return NULL;
  }
  of=op_open_callbacks(_source,_cb,NULL,0,_error);
  if(OP_UNLIKELY(of==NULL))(*_cb->close)(_source);
  return of;
}

OggOpusFile *op_open_file(const char *_path,int *_error){
  OpusFileCallbacks cb;
  return op_open_close_on_failure(op_fopen(&cb,_path,"rb"),&cb,_error);
}

OggOpusFile *op_open_memory(const unsigned char *_data,size_t _size,
 int *_error){
  OpusFileCallbacks cb;
  return op_open_close_on_failure(op_mem_stream_create(&cb,_data,_size),&cb,
   _error);
}

static OggOpusFile *op_test_close_on_failure(void *_source,
 const OpusFileCallbacks *_cb,int *_error){
  OggOpusFile *of;
  if(OP_UNLIKELY(_source==NULL)){
    if(_error!=NULL)*_error=OP_EFAULT;
    return NULL;
  }
  of=op_test_callbacks(_source,_cb,NULL,0,_error);
  if(OP_UNLIKELY(of==NULL))(*_cb->close)(_source);
  return of;
}

OggOpusFile *op_test_file(const char *_path,int *_error){
  OpusFileCallbacks cb;
  return op_test_close_on_failure(op_fopen(&cb,_path,"rb"),&cb,_error);
}

OggOpusFile *op_test_memory(const unsigned char *_data,size_t _size,
 int *_error){
  OpusFileCallbacks cb;
  return op_test_close_on_failure(op_mem_stream_create(&cb,_data,_size),&cb,
   _error);
}

int op_test_open(OggOpusFile *_of){
  int ret;
  if(OP_UNLIKELY(_of->ready_state!=OP_PARTOPEN))return OP_EINVAL;
  ret=op_open2(_of);

  if(OP_UNLIKELY(ret<0))memset(_of,0,sizeof(*_of));
  return ret;
}

void op_free(OggOpusFile *_of){
  if(OP_LIKELY(_of!=NULL)){
    op_clear(_of);
    _ogg_free(_of);
  }
}

int op_seekable(const OggOpusFile *_of){
  return _of->seekable;
}

int op_link_count(const OggOpusFile *_of){
  return _of->nlinks;
}

ogg_uint32_t op_serialno(const OggOpusFile *_of,int _li){
  if(OP_UNLIKELY(_li>=_of->nlinks))_li=_of->nlinks-1;
  if(!_of->seekable)_li=0;
  return _of->links[_li<0?_of->cur_link:_li].serialno;
}

int op_channel_count(const OggOpusFile *_of,int _li){
  return op_head(_of,_li)->channel_count;
}

opus_int64 op_raw_total(const OggOpusFile *_of,int _li){
  if(OP_UNLIKELY(_of->ready_state<OP_OPENED)
   ||OP_UNLIKELY(!_of->seekable)
   ||OP_UNLIKELY(_li>=_of->nlinks)){
    return OP_EINVAL;
  }
  if(_li<0)return _of->end-_of->links[0].offset;
  return (_li+1>=_of->nlinks?_of->end:_of->links[_li+1].offset)
   -_of->links[_li].offset;
}

ogg_int64_t op_pcm_total(const OggOpusFile *_of,int _li){
  OggOpusLink *links;
  ogg_int64_t  diff;
  int          nlinks;
  nlinks=_of->nlinks;
  if(OP_UNLIKELY(_of->ready_state<OP_OPENED)
   ||OP_UNLIKELY(!_of->seekable)
   ||OP_UNLIKELY(_li>=nlinks)){
    return OP_EINVAL;
  }
  links=_of->links;

  if(_li<0){
    ogg_int64_t pcm_total;
    int         li;
    pcm_total=0;
    for(li=0;li<nlinks;li++){
      OP_ALWAYS_TRUE(!op_granpos_diff(&diff,
       links[li].pcm_end,links[li].pcm_start));
      pcm_total+=diff-links[li].head.pre_skip;
    }
    return pcm_total;
  }
  OP_ALWAYS_TRUE(!op_granpos_diff(&diff,
   links[_li].pcm_end,links[_li].pcm_start));
  return diff-links[_li].head.pre_skip;
}

const OpusHead *op_head(const OggOpusFile *_of,int _li){
  if(OP_UNLIKELY(_li>=_of->nlinks))_li=_of->nlinks-1;
  if(!_of->seekable)_li=0;
  return &_of->links[_li<0?_of->cur_link:_li].head;
}

const OpusTags *op_tags(const OggOpusFile *_of,int _li){
  if(OP_UNLIKELY(_li>=_of->nlinks))_li=_of->nlinks-1;
  if(!_of->seekable){
    if(_of->ready_state<OP_STREAMSET&&_of->ready_state!=OP_PARTOPEN){
      return NULL;
    }
    _li=0;
  }
  else if(_li<0)_li=_of->ready_state>=OP_STREAMSET?_of->cur_link:0;
  return &_of->links[_li].tags;
}

int op_current_link(const OggOpusFile *_of){
  if(OP_UNLIKELY(_of->ready_state<OP_OPENED))return OP_EINVAL;
  return _of->cur_link;
}

static opus_int32 op_calc_bitrate(opus_int64 _bytes,ogg_int64_t _samples){
  if(OP_UNLIKELY(_bytes>(OP_INT64_MAX-(_samples>>1))/(48000*8))){
    ogg_int64_t den;
    if(OP_UNLIKELY(_bytes/(OP_INT32_MAX/(48000*8))>=_samples)){
      return OP_INT32_MAX;
    }
    den=_samples/(48000*8);
    return (opus_int32)((_bytes+(den>>1))/den);
  }
  if(OP_UNLIKELY(_samples<=0))return OP_INT32_MAX;

  return (opus_int32)OP_MIN((_bytes*48000*8+(_samples>>1))/_samples,
   OP_INT32_MAX);
}

opus_int32 op_bitrate(const OggOpusFile *_of,int _li){
  if(OP_UNLIKELY(_of->ready_state<OP_OPENED)||OP_UNLIKELY(!_of->seekable)
   ||OP_UNLIKELY(_li>=_of->nlinks)){
    return OP_EINVAL;
  }
  return op_calc_bitrate(op_raw_total(_of,_li),op_pcm_total(_of,_li));
}

opus_int32 op_bitrate_instant(OggOpusFile *_of){
  ogg_int64_t samples_tracked;
  opus_int32  ret;
  if(OP_UNLIKELY(_of->ready_state<OP_OPENED))return OP_EINVAL;
  samples_tracked=_of->samples_tracked;
  if(OP_UNLIKELY(samples_tracked==0))return OP_FALSE;
  ret=op_calc_bitrate(_of->bytes_tracked,samples_tracked);
  _of->bytes_tracked=0;
  _of->samples_tracked=0;
  return ret;
}

static int op_fetch_and_process_page(OggOpusFile *_of,
 ogg_page *_og,opus_int64 _page_pos,int _readp,int _spanp,int _ignore_holes){
  OggOpusLink  *links;
  ogg_uint32_t  cur_serialno;
  int           seekable;
  int           cur_link;
  int           ret;

  OP_ASSERT(_of->ready_state<OP_INITSET||_of->op_pos>=_of->op_count);
  if(!_readp)return 0;
  seekable=_of->seekable;
  links=_of->links;
  cur_link=seekable?_of->cur_link:0;
  cur_serialno=links[cur_link].serialno;

  for(;;){
    ogg_page og;
    OP_ASSERT(_of->ready_state>=OP_OPENED);

    do{
      if(_og!=NULL){
        *&og=*_og;
        _og=NULL;
      }

      else _page_pos=op_get_next_page(_of,&og,_of->end);

      if(_page_pos<0)return _page_pos<OP_FALSE?(int)_page_pos:OP_EOF;
      if(OP_LIKELY(_of->ready_state>=OP_STREAMSET)){
        if(cur_serialno!=(ogg_uint32_t)ogg_page_serialno(&og)){
          if(OP_LIKELY(!ogg_page_bos(&og)))continue;

          if(!_spanp)return OP_EOF;
          if(OP_LIKELY(_of->ready_state>=OP_INITSET))op_decode_clear(_of);
          break;
        }
      }

      _of->bytes_tracked+=og.header_len;
    }
    while(0);

    if(OP_UNLIKELY(_of->ready_state<OP_STREAMSET)){
      if(seekable){
        ogg_uint32_t serialno;
        int          nlinks;
        int          li;
        serialno=ogg_page_serialno(&og);

        nlinks=_of->nlinks;
        for(li=0;li<nlinks&&links[li].serialno!=serialno;li++);

        if(li>=nlinks)continue;
        cur_serialno=serialno;
        _of->cur_link=cur_link=li;
        ogg_stream_reset_serialno(&_of->os,serialno);
        _of->ready_state=OP_STREAMSET;

        if(_page_pos<=links[cur_link].data_offset){
          _of->prev_packet_gp=links[cur_link].pcm_start;
          _of->cur_discard_count=links[cur_link].head.pre_skip;

          _ignore_holes=1;
        }
      }
      else{
        do{
          ret=op_fetch_headers(_of,&links[0].head,&links[0].tags,
           NULL,NULL,NULL,&og);
          if(OP_UNLIKELY(ret<0))return ret;

          ret=op_find_initial_pcm_offset(_of,links,&og);
          if(OP_UNLIKELY(ret<0))return ret;
          _of->links[0].serialno=cur_serialno=_of->os.serialno;
          _of->cur_link++;
        }

        while(OP_UNLIKELY(ret>0));

        if(_of->op_count<=0)continue;

        ret=op_make_decode_ready(_of);
        if(OP_UNLIKELY(ret<0))return ret;
        return 1;
      }
    }

    if(OP_UNLIKELY(_of->ready_state==OP_STREAMSET)){
      ret=op_make_decode_ready(_of);
      if(OP_UNLIKELY(ret<0))return ret;
    }

    ogg_stream_pagein(&_of->os,&og);
    if(OP_LIKELY(_of->ready_state>=OP_INITSET)){
      opus_int32 total_duration;
      int        durations[255];
      int        op_count;
      total_duration=op_collect_audio_packets(_of,durations);
      if(OP_UNLIKELY(total_duration<0)){
        total_duration=op_collect_audio_packets(_of,durations);
        OP_ASSERT(total_duration>=0);

        if(!_ignore_holes)return OP_HOLE;
      }
      op_count=_of->op_count;

      if(op_count>0){
        ogg_int64_t diff;
        ogg_int64_t prev_packet_gp;
        ogg_int64_t cur_packet_gp;
        ogg_int64_t cur_page_gp;
        int         cur_page_eos;
        int         pi;
        cur_page_gp=_of->op[op_count-1].granulepos;
        cur_page_eos=_of->op[op_count-1].e_o_s;
        prev_packet_gp=_of->prev_packet_gp;
        if(OP_UNLIKELY(prev_packet_gp==-1)){
          opus_int32 cur_discard_count;

          OP_ASSERT(seekable);
          if(OP_UNLIKELY(cur_page_eos)){
            _of->op_count=0;
            continue;
          }

          cur_discard_count=80*48;
          cur_page_gp=_of->op[op_count-1].granulepos;

          prev_packet_gp=links[cur_link].pcm_start;
          if(OP_LIKELY(cur_page_gp!=-1)){
            op_granpos_add(&prev_packet_gp,cur_page_gp,-total_duration);
          }
          if(OP_LIKELY(!op_granpos_diff(&diff,
           prev_packet_gp,links[cur_link].pcm_start))){
            opus_int32 pre_skip;

            pre_skip=links[cur_link].head.pre_skip;
            if(diff>=0&&diff<=OP_MAX(0,pre_skip-80*48)){
              cur_discard_count=pre_skip-(int)diff;
            }
          }
          _of->cur_discard_count=cur_discard_count;
        }
        if(OP_UNLIKELY(cur_page_gp==-1)){
          if(op_granpos_add(&cur_page_gp,prev_packet_gp,total_duration)<0){
            cur_page_gp=links[cur_link].pcm_end;
          }
        }

        if(OP_UNLIKELY(cur_page_eos)
         &&OP_LIKELY(!op_granpos_diff(&diff,cur_page_gp,prev_packet_gp))
         &&OP_LIKELY(diff<total_duration)){
          cur_packet_gp=prev_packet_gp;
          for(pi=0;pi<op_count;pi++){
            diff=durations[pi]-diff;

            if(diff>0){
              if(OP_UNLIKELY(diff>durations[pi]))break;
              cur_packet_gp=cur_page_gp;

              _of->op[pi].e_o_s=1;
            }
            else{
              OP_ALWAYS_TRUE(!op_granpos_add(&cur_packet_gp,
               cur_packet_gp,durations[pi]));
            }
            _of->op[pi].granulepos=cur_packet_gp;
            OP_ALWAYS_TRUE(!op_granpos_diff(&diff,cur_page_gp,cur_packet_gp));
          }
        }
        else{
          if(OP_UNLIKELY(op_granpos_add(&prev_packet_gp,
           cur_page_gp,-total_duration)<0)){
            prev_packet_gp=0;
          }
          for(pi=0;pi<op_count;pi++){
            if(OP_UNLIKELY(op_granpos_add(&cur_packet_gp,
             cur_page_gp,-total_duration)<0)){
              cur_packet_gp=0;
            }
            total_duration-=durations[pi];
            OP_ASSERT(total_duration>=0);
            OP_ALWAYS_TRUE(!op_granpos_add(&cur_packet_gp,
             cur_packet_gp,durations[pi]));
            _of->op[pi].granulepos=cur_packet_gp;
          }
          OP_ASSERT(total_duration==0);
        }
        _of->prev_packet_gp=prev_packet_gp;
        _of->op_count=pi;

        if(OP_LIKELY(pi>0))return 1;
      }
    }
  }
}

int op_raw_seek(OggOpusFile *_of,opus_int64 _pos){
  int ret;
  if(OP_UNLIKELY(_of->ready_state<OP_OPENED))return OP_EINVAL;

  if(OP_UNLIKELY(!_of->seekable))return OP_ENOSEEK;
  if(OP_UNLIKELY(_pos<0)||OP_UNLIKELY(_pos>_of->end))return OP_EINVAL;

  op_decode_clear(_of);
  _of->bytes_tracked=0;
  _of->samples_tracked=0;
  ret=op_seek_helper(_of,_pos);
  if(OP_UNLIKELY(ret<0))return OP_EREAD;
  ret=op_fetch_and_process_page(_of,NULL,-1,1,1,1);

  if(ret==OP_EOF){
    int cur_link;
    op_decode_clear(_of);
    cur_link=_of->nlinks-1;
    _of->cur_link=cur_link;
    _of->prev_packet_gp=_of->links[cur_link].pcm_end;
    _of->cur_discard_count=0;
    ret=0;
  }
  else if(ret>0)ret=0;
  return ret;
}

static ogg_int64_t op_get_granulepos(const OggOpusFile *_of,
 ogg_int64_t _pcm_offset,int *_li){
  const OggOpusLink *links;
  ogg_int64_t        duration;
  int                nlinks;
  int                li;
  OP_ASSERT(_pcm_offset>=0);
  nlinks=_of->nlinks;
  links=_of->links;
  for(li=0;OP_LIKELY(li<nlinks);li++){
    ogg_int64_t pcm_start;
    opus_int32  pre_skip;
    pcm_start=links[li].pcm_start;
    pre_skip=links[li].head.pre_skip;
    OP_ALWAYS_TRUE(!op_granpos_diff(&duration,links[li].pcm_end,pcm_start));
    duration-=pre_skip;
    if(_pcm_offset<duration){
      _pcm_offset+=pre_skip;
      if(OP_UNLIKELY(pcm_start>OP_INT64_MAX-_pcm_offset)){
        _pcm_offset-=OP_INT64_MAX-pcm_start+1;
        pcm_start=OP_INT64_MIN;
      }
      pcm_start+=_pcm_offset;
      *_li=li;
      return pcm_start;
    }
    _pcm_offset-=duration;
  }
  return -1;
}

#define OP_CUR_TIME_THRESH (120*48*(opus_int32)1000)

static int op_pcm_seek_page(OggOpusFile *_of,
 ogg_int64_t _target_gp,int _li){
  const OggOpusLink *link;
  ogg_page           og;
  ogg_int64_t        pcm_pre_skip;
  ogg_int64_t        pcm_start;
  ogg_int64_t        pcm_end;
  ogg_int64_t        best_gp;
  ogg_int64_t        diff;
  ogg_uint32_t       serialno;
  opus_int32         pre_skip;
  opus_int64         begin;
  opus_int64         end;
  opus_int64         boundary;
  opus_int64         best;
  opus_int64         page_offset;
  opus_int64         d0;
  opus_int64         d1;
  opus_int64         d2;
  int                force_bisect;
  int                ret;
  _of->bytes_tracked=0;
  _of->samples_tracked=0;
  link=_of->links+_li;
  best_gp=pcm_start=link->pcm_start;
  pcm_end=link->pcm_end;
  serialno=link->serialno;
  best=begin=link->data_offset;
  page_offset=-1;

  if(OP_UNLIKELY(op_granpos_add(&_target_gp,_target_gp,-80*48)<0)
   ||OP_UNLIKELY(op_granpos_cmp(_target_gp,pcm_start)<0)){
    _target_gp=pcm_start;
  }

  pre_skip=link->head.pre_skip;
  OP_ALWAYS_TRUE(!op_granpos_add(&pcm_pre_skip,pcm_start,pre_skip));
  if(op_granpos_cmp(_target_gp,pcm_pre_skip)<0)end=boundary=begin;
  else{
    end=boundary=link->end_offset;
#if !defined(OP_SMALL_FOOTPRINT)

    if(_li==_of->cur_link&&_of->ready_state>=OP_INITSET){
      opus_int64 offset;
      int        op_count;
      op_count=_of->op_count;

      offset=_of->offset;
      if(op_count>0&&OP_LIKELY(offset<=end)){
        ogg_int64_t gp;

        gp=_of->op[op_count-1].granulepos;
        if(OP_LIKELY(gp!=-1)&&OP_LIKELY(op_granpos_cmp(pcm_start,gp)<0)
         &&OP_LIKELY(op_granpos_cmp(pcm_end,gp)>0)){
          OP_ALWAYS_TRUE(!op_granpos_diff(&diff,gp,_target_gp));

          if(diff<0){
            OP_ASSERT(offset>=begin);
            if(offset-begin>=end-begin>>1||diff>-OP_CUR_TIME_THRESH){
              best=begin=offset;
              best_gp=pcm_start=gp;
            }
          }
          else{
            ogg_int64_t prev_page_gp;

            OP_ALWAYS_TRUE(!op_granpos_add(&prev_page_gp,_of->op[0].granulepos,
             op_get_packet_duration(_of->op[0].packet,_of->op[0].bytes)));
            if(op_granpos_cmp(prev_page_gp,_target_gp)<=0){
              _of->op_pos=0;
              _of->od_buffer_size=0;
              _of->prev_packet_gp=prev_page_gp;
              _of->ready_state=OP_STREAMSET;
              return op_make_decode_ready(_of);
            }

            if(offset-begin<=end-begin>>1||diff<OP_CUR_TIME_THRESH){
              end=boundary=offset;
              pcm_end=gp;
            }
          }
        }
      }
    }
#endif
  }

  op_decode_clear(_of);

  d2=d1=d0=end-begin;
  force_bisect=0;
  while(begin<end){
    opus_int64 bisect;
    opus_int64 next_boundary;
    opus_int32 chunk_size;
    if(end-begin<OP_CHUNK_SIZE)bisect=begin;
    else{
      d0=d1>>1;
      d1=d2>>1;
      d2=end-begin>>1;
      if(force_bisect)bisect=begin+(end-begin>>1);
      else{
        ogg_int64_t diff2;
        OP_ALWAYS_TRUE(!op_granpos_diff(&diff,_target_gp,pcm_start));
        OP_ALWAYS_TRUE(!op_granpos_diff(&diff2,pcm_end,pcm_start));

        bisect=begin+op_rescale64(diff,diff2,end-begin)-OP_CHUNK_SIZE;
      }
      if(bisect-OP_CHUNK_SIZE<begin)bisect=begin;
      force_bisect=0;
    }
    if(bisect!=_of->offset){
      page_offset=-1;
      ret=op_seek_helper(_of,bisect);
      if(OP_UNLIKELY(ret<0))return ret;
    }
    chunk_size=OP_CHUNK_SIZE;
    next_boundary=boundary;
    while(begin<end){
      page_offset=op_get_next_page(_of,&og,boundary);
      if(page_offset<0){
        if(page_offset<OP_FALSE)return (int)page_offset;

        if(bisect<=begin+1)end=begin;
        else{
          bisect=OP_MAX(bisect-chunk_size,begin);
          ret=op_seek_helper(_of,bisect);
          if(OP_UNLIKELY(ret<0))return ret;

          chunk_size=OP_MIN(2*chunk_size,OP_CHUNK_SIZE_MAX);

          boundary=next_boundary;
        }
      }
      else{
        ogg_int64_t gp;

        next_boundary=OP_MIN(page_offset,next_boundary);
        if(serialno!=(ogg_uint32_t)ogg_page_serialno(&og))continue;
        gp=ogg_page_granulepos(&og);
        if(gp==-1)continue;
        if(op_granpos_cmp(gp,_target_gp)<0){
          begin=_of->offset;
          if(OP_UNLIKELY(op_granpos_cmp(pcm_start,gp)>0)
           ||OP_UNLIKELY(op_granpos_cmp(pcm_end,gp)<0)){
            break;
          }

          best=begin;
          best_gp=pcm_start=gp;
          OP_ALWAYS_TRUE(!op_granpos_diff(&diff,_target_gp,pcm_start));

          if(diff>48000)break;

          bisect=begin;
        }
        else{
          if(bisect<=begin+1)end=begin;
          else{
            end=bisect;

            boundary=next_boundary;

            force_bisect=end-begin>d0*2;

            if(OP_LIKELY(op_granpos_cmp(pcm_end,gp)>0)
             &&OP_LIKELY(op_granpos_cmp(pcm_start,gp)<=0)){
              pcm_end=gp;
            }
            break;
          }
        }
      }
    }
  }

  if(best!=page_offset){
    page_offset=-1;
    ret=op_seek_helper(_of,best);
    if(OP_UNLIKELY(ret<0))return ret;
  }
  OP_ASSERT(op_granpos_cmp(best_gp,pcm_start)>=0);
  _of->cur_link=_li;
  _of->ready_state=OP_STREAMSET;
  _of->prev_packet_gp=best_gp;
  ogg_stream_reset_serialno(&_of->os,serialno);
  ret=op_fetch_and_process_page(_of,page_offset<0?NULL:&og,page_offset,1,0,1);
  if(OP_UNLIKELY(ret<=0))return OP_EBADLINK;

  if(OP_UNLIKELY(op_granpos_cmp(_of->prev_packet_gp,_target_gp)>0)){
    return OP_EBADLINK;
  }
  return 0;
}

int op_pcm_seek(OggOpusFile *_of,ogg_int64_t _pcm_offset){
  const OggOpusLink *link;
  ogg_int64_t        pcm_start;
  ogg_int64_t        target_gp;
  ogg_int64_t        prev_packet_gp;
  ogg_int64_t        skip;
  ogg_int64_t        diff;
  int                op_count;
  int                op_pos;
  int                ret;
  int                li;
  if(OP_UNLIKELY(_of->ready_state<OP_OPENED))return OP_EINVAL;
  if(OP_UNLIKELY(!_of->seekable))return OP_ENOSEEK;
  if(OP_UNLIKELY(_pcm_offset<0))return OP_EINVAL;
  target_gp=op_get_granulepos(_of,_pcm_offset,&li);
  if(OP_UNLIKELY(target_gp==-1))return OP_EINVAL;
  link=_of->links+li;
  pcm_start=link->pcm_start;
  OP_ALWAYS_TRUE(!op_granpos_diff(&_pcm_offset,target_gp,pcm_start));
#if !defined(OP_SMALL_FOOTPRINT)

  if(li==_of->cur_link&&_of->ready_state>=OP_INITSET){
    ogg_int64_t gp;
    gp=_of->prev_packet_gp;
    if(OP_LIKELY(gp!=-1)){
      int nbuffered;
      nbuffered=OP_MAX(_of->od_buffer_size-_of->od_buffer_pos,0);
      OP_ALWAYS_TRUE(!op_granpos_add(&gp,gp,-nbuffered));

      if(OP_LIKELY(!op_granpos_diff(&diff,gp,pcm_start))){
        ogg_int64_t discard_count;
        discard_count=_pcm_offset-diff;

        if(discard_count>=0&&OP_UNLIKELY(discard_count<90*48)){
          _of->cur_discard_count=(opus_int32)discard_count;
          return 0;
        }
      }
    }
  }
#endif
  ret=op_pcm_seek_page(_of,target_gp,li);
  if(OP_UNLIKELY(ret<0))return ret;

  if(_pcm_offset<=link->head.pre_skip)skip=0;
  else skip=OP_MAX(_pcm_offset-80*48,0);
  OP_ASSERT(_pcm_offset-skip>=0);
  OP_ASSERT(_pcm_offset-skip<OP_INT32_MAX-120*48);

  for(;;){
    op_count=_of->op_count;
    prev_packet_gp=_of->prev_packet_gp;
    for(op_pos=_of->op_pos;op_pos<op_count;op_pos++){
      ogg_int64_t cur_packet_gp;
      cur_packet_gp=_of->op[op_pos].granulepos;
      if(OP_LIKELY(!op_granpos_diff(&diff,cur_packet_gp,pcm_start))
       &&diff>skip){
        break;
      }
      prev_packet_gp=cur_packet_gp;
    }
    _of->prev_packet_gp=prev_packet_gp;
    _of->op_pos=op_pos;
    if(op_pos<op_count)break;

    ret=op_fetch_and_process_page(_of,NULL,-1,1,0,1);
    if(OP_UNLIKELY(ret<=0))return OP_EBADLINK;
  }
  OP_ALWAYS_TRUE(!op_granpos_diff(&diff,prev_packet_gp,pcm_start));

  if(diff>skip)return OP_EBADLINK;
  OP_ASSERT(_pcm_offset-diff<OP_INT32_MAX);

  _of->cur_discard_count=(opus_int32)(_pcm_offset-diff);
  return 0;
}

opus_int64 op_raw_tell(const OggOpusFile *_of){
  if(OP_UNLIKELY(_of->ready_state<OP_OPENED))return OP_EINVAL;
  return _of->offset;
}

static ogg_int64_t op_get_pcm_offset(const OggOpusFile *_of,
 ogg_int64_t _gp,int _li){
  const OggOpusLink *links;
  ogg_int64_t        pcm_offset;
  ogg_int64_t        delta;
  int                li;
  links=_of->links;
  pcm_offset=0;
  OP_ASSERT(_li<_of->nlinks);
  for(li=0;li<_li;li++){
    OP_ALWAYS_TRUE(!op_granpos_diff(&delta,
     links[li].pcm_end,links[li].pcm_start));
    delta-=links[li].head.pre_skip;
    pcm_offset+=delta;
  }
  OP_ASSERT(_li>=0);
  if(_of->seekable&&OP_UNLIKELY(op_granpos_cmp(_gp,links[_li].pcm_end)>0)){
    _gp=links[_li].pcm_end;
  }
  if(OP_LIKELY(op_granpos_cmp(_gp,links[_li].pcm_start)>0)){
    if(OP_UNLIKELY(op_granpos_diff(&delta,_gp,links[_li].pcm_start)<0)){
      OP_ASSERT(!_of->seekable);
      return OP_INT64_MAX;
    }
    if(delta<links[_li].head.pre_skip)delta=0;
    else delta-=links[_li].head.pre_skip;

    OP_ASSERT(pcm_offset<=OP_INT64_MAX-delta);
    pcm_offset+=delta;
  }
  return pcm_offset;
}

ogg_int64_t op_pcm_tell(const OggOpusFile *_of){
  ogg_int64_t gp;
  int         nbuffered;
  int         li;
  if(OP_UNLIKELY(_of->ready_state<OP_OPENED))return OP_EINVAL;
  gp=_of->prev_packet_gp;
  if(gp==-1)return 0;
  nbuffered=OP_MAX(_of->od_buffer_size-_of->od_buffer_pos,0);
  OP_ALWAYS_TRUE(!op_granpos_add(&gp,gp,-nbuffered));
  li=_of->seekable?_of->cur_link:0;
  if(op_granpos_add(&gp,gp,_of->cur_discard_count)<0){
    gp=_of->links[li].pcm_end;
  }
  return op_get_pcm_offset(_of,gp,li);
}

void op_set_decode_callback(OggOpusFile *_of,
 op_decode_cb_func _decode_cb,void *_ctx){
  _of->decode_cb=_decode_cb;
  _of->decode_cb_ctx=_ctx;
}

int op_set_gain_offset(OggOpusFile *_of,
 int _gain_type,opus_int32 _gain_offset_q8){
  if(_gain_type!=OP_HEADER_GAIN&&_gain_type!=OP_TRACK_GAIN
   &&_gain_type!=OP_ABSOLUTE_GAIN){
    return OP_EINVAL;
  }
  _of->gain_type=_gain_type;

  _of->gain_offset_q8=OP_CLAMP(-98302,_gain_offset_q8,98303);
  op_update_gain(_of);
  return 0;
}

void op_set_dither_enabled(OggOpusFile *_of,int _enabled){
#if !defined(OP_FIXED_POINT)
  _of->dither_disabled=!_enabled;
  if(!_enabled)_of->dither_mute=65;
#endif
}

static int op_init_buffer(OggOpusFile *_of){
  int nchannels_max;
  if(_of->seekable){
    const OggOpusLink *links;
    int                nlinks;
    int                li;
    links=_of->links;
    nlinks=_of->nlinks;
    nchannels_max=1;
    for(li=0;li<nlinks;li++){
      nchannels_max=OP_MAX(nchannels_max,links[li].head.channel_count);
    }
  }
  else nchannels_max=OP_NCHANNELS_MAX;
  _of->od_buffer=(op_sample *)_ogg_malloc(
   sizeof(*_of->od_buffer)*nchannels_max*120*48);
  if(_of->od_buffer==NULL)return OP_EFAULT;
  return 0;
}

static int op_decode(OggOpusFile *_of,op_sample *_pcm,
 const ogg_packet *_op,int _nsamples,int _nchannels){
  int ret;

  if(_of->decode_cb!=NULL){
#if defined(OP_FIXED_POINT)
    ret=(*_of->decode_cb)(_of->decode_cb_ctx,_of->od,_pcm,_op,
     _nsamples,_nchannels,OP_DEC_FORMAT_SHORT,_of->cur_link);
#else
    ret=(*_of->decode_cb)(_of->decode_cb_ctx,_of->od,_pcm,_op,
     _nsamples,_nchannels,OP_DEC_FORMAT_FLOAT,_of->cur_link);
#endif
  }
  else ret=OP_DEC_USE_DEFAULT;

  if(ret==OP_DEC_USE_DEFAULT){
#if defined(OP_FIXED_POINT)
    ret=opus_multistream_decode(_of->od,
     _op->packet,_op->bytes,_pcm,_nsamples,0);
#else
    ret=opus_multistream_decode_float(_of->od,
     _op->packet,_op->bytes,_pcm,_nsamples,0);
#endif
    OP_ASSERT(ret<0||ret==_nsamples);
  }

  else if(OP_UNLIKELY(ret>0))return OP_EBADPACKET;
  if(OP_UNLIKELY(ret<0))return OP_EBADPACKET;
  return ret;
}

static int op_read_native(OggOpusFile *_of,
 op_sample *_pcm,int _buf_size,int *_li){
  if(OP_UNLIKELY(_of->ready_state<OP_OPENED))return OP_EINVAL;
  for(;;){
    int ret;
    if(OP_LIKELY(_of->ready_state>=OP_INITSET)){
      int nchannels;
      int od_buffer_pos;
      int nsamples;
      int op_pos;
      nchannels=_of->links[_of->seekable?_of->cur_link:0].head.channel_count;
      od_buffer_pos=_of->od_buffer_pos;
      nsamples=_of->od_buffer_size-od_buffer_pos;

      if(nsamples>0){
        if(nsamples*nchannels>_buf_size)nsamples=_buf_size/nchannels;
        memcpy(_pcm,_of->od_buffer+nchannels*od_buffer_pos,
         sizeof(*_pcm)*nchannels*nsamples);
        od_buffer_pos+=nsamples;
        _of->od_buffer_pos=od_buffer_pos;
        if(_li!=NULL)*_li=_of->cur_link;
        return nsamples;
      }

      op_pos=_of->op_pos;
      if(OP_LIKELY(op_pos<_of->op_count)){
        const ogg_packet *pop;
        ogg_int64_t       diff;
        opus_int32        cur_discard_count;
        int               duration;
        int               trimmed_duration;
        pop=_of->op+op_pos++;
        _of->op_pos=op_pos;
        cur_discard_count=_of->cur_discard_count;
        duration=op_get_packet_duration(pop->packet,pop->bytes);

        OP_ASSERT(duration>0);
        trimmed_duration=duration;

        if(OP_UNLIKELY(pop->e_o_s)){
          if(OP_UNLIKELY(op_granpos_cmp(pop->granulepos,
           _of->prev_packet_gp)<=0)){
            trimmed_duration=0;
          }
          else if(OP_LIKELY(!op_granpos_diff(&diff,
           pop->granulepos,_of->prev_packet_gp))){
            trimmed_duration=(int)OP_MIN(diff,trimmed_duration);
          }
        }
        _of->prev_packet_gp=pop->granulepos;
        if(OP_UNLIKELY(duration*nchannels>_buf_size)){
          op_sample *buf;

          buf=_of->od_buffer;
          if(OP_UNLIKELY(buf==NULL)){
            ret=op_init_buffer(_of);
            if(OP_UNLIKELY(ret<0))return ret;
            buf=_of->od_buffer;
          }
          ret=op_decode(_of,buf,pop,duration,nchannels);
          if(OP_UNLIKELY(ret<0))return ret;

          od_buffer_pos=(int)OP_MIN(trimmed_duration,cur_discard_count);
          cur_discard_count-=od_buffer_pos;
          _of->cur_discard_count=cur_discard_count;
          _of->od_buffer_pos=od_buffer_pos;
          _of->od_buffer_size=trimmed_duration;

          _of->bytes_tracked+=pop->bytes;
          _of->samples_tracked+=trimmed_duration-od_buffer_pos;
        }
        else{
          ret=op_decode(_of,_pcm,pop,duration,nchannels);
          if(OP_UNLIKELY(ret<0))return ret;
          if(OP_LIKELY(trimmed_duration>0)){
            od_buffer_pos=(int)OP_MIN(trimmed_duration,cur_discard_count);
            cur_discard_count-=od_buffer_pos;
            _of->cur_discard_count=cur_discard_count;
            trimmed_duration-=od_buffer_pos;
            if(OP_LIKELY(trimmed_duration>0)
             &&OP_UNLIKELY(od_buffer_pos>0)){
              memmove(_pcm,_pcm+od_buffer_pos*nchannels,
               sizeof(*_pcm)*trimmed_duration*nchannels);
            }

            _of->bytes_tracked+=pop->bytes;
            _of->samples_tracked+=trimmed_duration;
            if(OP_LIKELY(trimmed_duration>0)){
              if(_li!=NULL)*_li=_of->cur_link;
              return trimmed_duration;
            }
          }
        }

        continue;
      }
    }

    ret=op_fetch_and_process_page(_of,NULL,-1,1,1,0);
    if(OP_UNLIKELY(ret==OP_EOF)){
      if(_li!=NULL)*_li=_of->cur_link;
      return 0;
    }
    if(OP_UNLIKELY(ret<0))return ret;
  }
}

typedef int (*op_read_filter_func)(OggOpusFile *_of,void *_dst,int _dst_sz,
 op_sample *_src,int _nsamples,int _nchannels);

static int op_filter_read_native(OggOpusFile *_of,void *_dst,int _dst_sz,
 op_read_filter_func _filter,int *_li){
  int ret;

  ret=op_read_native(_of,NULL,0,_li);

  if(OP_LIKELY(ret>=0)&&OP_LIKELY(_of->ready_state>=OP_INITSET)){
    int od_buffer_pos;
    od_buffer_pos=_of->od_buffer_pos;
    ret=_of->od_buffer_size-od_buffer_pos;
    if(OP_LIKELY(ret>0)){
      int nchannels;
      nchannels=_of->links[_of->seekable?_of->cur_link:0].head.channel_count;
      ret=(*_filter)(_of,_dst,_dst_sz,
       _of->od_buffer+nchannels*od_buffer_pos,ret,nchannels);
      OP_ASSERT(ret>=0);
      OP_ASSERT(ret<=_of->od_buffer_size-od_buffer_pos);
      od_buffer_pos+=ret;
      _of->od_buffer_pos=od_buffer_pos;
    }
  }
  return ret;
}

#if !defined(OP_FIXED_POINT)||!defined(OP_DISABLE_FLOAT_API)

static const float OP_STEREO_DOWNMIX[OP_NCHANNELS_MAX-2][OP_NCHANNELS_MAX][2]={
  {
    {0.5858F,0.0F},{0.4142F,0.4142F},{0.0F,0.5858F}
  },

  {
    {0.4226F,0.0F},{0.0F,0.4226F},{0.366F,0.2114F},{0.2114F,0.336F}
  },

  {
    {0.651F,0.0F},{0.46F,0.46F},{0.0F,0.651F},{0.5636F,0.3254F},
    {0.3254F,0.5636F}
  },

  {
    {0.529F,0.0F},{0.3741F,0.3741F},{0.0F,0.529F},{0.4582F,0.2645F},
    {0.2645F,0.4582F},{0.3741F,0.3741F}
  },

  {
    {0.4553F,0.0F},{0.322F,0.322F},{0.0F,0.4553F},{0.3943F,0.2277F},
    {0.2277F,0.3943F},{0.2788F,0.2788F},{0.322F,0.322F}
  },

  {
    {0.3886F,0.0F},{0.2748F,0.2748F},{0.0F,0.3886F},{0.3366F,0.1943F},
    {0.1943F,0.3366F},{0.3366F,0.1943F},{0.1943F,0.3366F},{0.2748F,0.2748F}
  }
};

#endif

#if defined(OP_FIXED_POINT)

static const opus_int16 OP_STEREO_DOWNMIX_Q14
 [OP_NCHANNELS_MAX-2][OP_NCHANNELS_MAX][2]={
  {
    {9598,0},{6786,6786},{0,9598}
  },

  {
    {6924,0},{0,6924},{5996,3464},{3464,5996}
  },

  {
    {10666,0},{7537,7537},{0,10666},{9234,5331},{5331,9234}
  },

  {
    {8668,0},{6129,6129},{0,8668},{7507,4335},{4335,7507},{6129,6129}
  },

  {
    {7459,0},{5275,5275},{0,7459},{6460,3731},{3731,6460},{4568,4568},
    {5275,5275}
  },

  {
    {6368,0},{4502,4502},{0,6368},{5515,3183},{3183,5515},{5515,3183},
    {3183,5515},{4502,4502}
  }
};

int op_read(OggOpusFile *_of,opus_int16 *_pcm,int _buf_size,int *_li){
  return op_read_native(_of,_pcm,_buf_size,_li);
}

static int op_stereo_filter(OggOpusFile *_of,void *_dst,int _dst_sz,
 op_sample *_src,int _nsamples,int _nchannels){
  (void)_of;
  _nsamples=OP_MIN(_nsamples,_dst_sz>>1);
  if(_nchannels==2)memcpy(_dst,_src,_nsamples*2*sizeof(*_src));
  else{
    opus_int16 *dst;
    int         i;
    dst=(opus_int16 *)_dst;
    if(_nchannels==1){
      for(i=0;i<_nsamples;i++)dst[2*i+0]=dst[2*i+1]=_src[i];
    }
    else{
      for(i=0;i<_nsamples;i++){
        opus_int32 l;
        opus_int32 r;
        int        ci;
        l=r=0;
        for(ci=0;ci<_nchannels;ci++){
          opus_int32 s;
          s=_src[_nchannels*i+ci];
          l+=OP_STEREO_DOWNMIX_Q14[_nchannels-3][ci][0]*s;
          r+=OP_STEREO_DOWNMIX_Q14[_nchannels-3][ci][1]*s;
        }

        dst[2*i+0]=(opus_int16)OP_CLAMP(-32768,l+8192>>14,32767);
        dst[2*i+1]=(opus_int16)OP_CLAMP(-32768,r+8192>>14,32767);
      }
    }
  }
  return _nsamples;
}

int op_read_stereo(OggOpusFile *_of,opus_int16 *_pcm,int _buf_size){
  return op_filter_read_native(_of,_pcm,_buf_size,op_stereo_filter,NULL);
}

# if !defined(OP_DISABLE_FLOAT_API)

static int op_short2float_filter(OggOpusFile *_of,void *_dst,int _dst_sz,
 op_sample *_src,int _nsamples,int _nchannels){
  float *dst;
  int    i;
  (void)_of;
  dst=(float *)_dst;
  if(OP_UNLIKELY(_nsamples*_nchannels>_dst_sz))_nsamples=_dst_sz/_nchannels;
  _dst_sz=_nsamples*_nchannels;
  for(i=0;i<_dst_sz;i++)dst[i]=(1.0F/32768)*_src[i];
  return _nsamples;
}

int op_read_float(OggOpusFile *_of,float *_pcm,int _buf_size,int *_li){
  return op_filter_read_native(_of,_pcm,_buf_size,op_short2float_filter,_li);
}

static int op_short2float_stereo_filter(OggOpusFile *_of,
 void *_dst,int _dst_sz,op_sample *_src,int _nsamples,int _nchannels){
  float *dst;
  int    i;
  dst=(float *)_dst;
  _nsamples=OP_MIN(_nsamples,_dst_sz>>1);
  if(_nchannels==1){
    _nsamples=op_short2float_filter(_of,dst,_nsamples,_src,_nsamples,1);
    for(i=_nsamples;i-->0;)dst[2*i+0]=dst[2*i+1]=dst[i];
  }
  else if(_nchannels<5){
    if(_nchannels>2){
      _nsamples=op_stereo_filter(_of,_src,_nsamples*2,
       _src,_nsamples,_nchannels);
    }
    return op_short2float_filter(_of,dst,_dst_sz,_src,_nsamples,2);
  }
  else{
    for(i=0;i<_nsamples;i++){
      float l;
      float r;
      int   ci;
      l=r=0;
      for(ci=0;ci<_nchannels;ci++){
        float s;
        s=(1.0F/32768)*_src[_nchannels*i+ci];
        l+=OP_STEREO_DOWNMIX[_nchannels-3][ci][0]*s;
        r+=OP_STEREO_DOWNMIX[_nchannels-3][ci][1]*s;
      }
      dst[2*i+0]=l;
      dst[2*i+1]=r;
    }
  }
  return _nsamples;
}

int op_read_float_stereo(OggOpusFile *_of,float *_pcm,int _buf_size){
  return op_filter_read_native(_of,_pcm,_buf_size,
   op_short2float_stereo_filter,NULL);
}

# endif

#else

# if defined(OP_HAVE_LRINTF)
#  include <math.h>
#  define op_float2int(_x) (lrintf(_x))
# else
#  define op_float2int(_x) ((int)((_x)+((_x)<0?-0.5F:0.5F)))
# endif

static opus_uint32 op_rand(opus_uint32 _seed){
  return _seed*96314165+907633515&0xFFFFFFFFU;
}

# define OP_GAIN (32753.0F)

# define OP_PRNG_GAIN (1.0F/0xFFFFFFFF)

static const float OP_FCOEF_B[4]={
  2.2374F,-0.7339F,-0.1251F,-0.6033F
};

static const float OP_FCOEF_A[4]={
  0.9030F,0.0116F,-0.5853F,-0.2571F
};

static int op_float2short_filter(OggOpusFile *_of,void *_dst,int _dst_sz,
 float *_src,int _nsamples,int _nchannels){
  opus_int16 *dst;
  int         ci;
  int         i;
  dst=(opus_int16 *)_dst;
  if(OP_UNLIKELY(_nsamples*_nchannels>_dst_sz))_nsamples=_dst_sz/_nchannels;
# if defined(OP_SOFT_CLIP)
  if(_of->state_channel_count!=_nchannels){
    for(ci=0;ci<_nchannels;ci++)_of->clip_state[ci]=0;
  }
  opus_pcm_soft_clip(_src,_nsamples,_nchannels,_of->clip_state);
# endif
  if(_of->dither_disabled){
    for(i=0;i<_nchannels*_nsamples;i++){
      dst[i]=op_float2int(OP_CLAMP(-32768,32768.0F*_src[i],32767));
    }
  }
  else{
    opus_uint32 seed;
    int         mute;
    seed=_of->dither_seed;
    mute=_of->dither_mute;
    if(_of->state_channel_count!=_nchannels)mute=65;

    if(mute>64)memset(_of->dither_a,0,sizeof(*_of->dither_a)*4*_nchannels);
    for(i=0;i<_nsamples;i++){
      int silent;
      silent=1;
      for(ci=0;ci<_nchannels;ci++){
        float r;
        float s;
        float err;
        int   si;
        int   j;
        s=_src[_nchannels*i+ci];
        silent&=s==0;
        s*=OP_GAIN;
        err=0;
        for(j=0;j<4;j++){
          err+=OP_FCOEF_B[j]*_of->dither_b[ci*4+j]
           -OP_FCOEF_A[j]*_of->dither_a[ci*4+j];
        }
        for(j=3;j-->0;)_of->dither_a[ci*4+j+1]=_of->dither_a[ci*4+j];
        for(j=3;j-->0;)_of->dither_b[ci*4+j+1]=_of->dither_b[ci*4+j];
        _of->dither_a[ci*4]=err;
        s-=err;
        if(mute>16)r=0;
        else{
          seed=op_rand(seed);
          r=seed*OP_PRNG_GAIN;
          seed=op_rand(seed);
          r-=seed*OP_PRNG_GAIN;
        }

        si=op_float2int(OP_CLAMP(-32768,s+r,32767));
        dst[_nchannels*i+ci]=(opus_int16)si;

        _of->dither_b[ci*4]=mute>16?0:OP_CLAMP(-1.5F,si-s,1.5F);
      }
      mute++;
      if(!silent)mute=0;
    }
    _of->dither_mute=OP_MIN(mute,65);
    _of->dither_seed=seed;
  }
  _of->state_channel_count=_nchannels;
  return _nsamples;
}

int op_read(OggOpusFile *_of,opus_int16 *_pcm,int _buf_size,int *_li){
  return op_filter_read_native(_of,_pcm,_buf_size,op_float2short_filter,_li);
}

int op_read_float(OggOpusFile *_of,float *_pcm,int _buf_size,int *_li){
  _of->state_channel_count=0;
  return op_read_native(_of,_pcm,_buf_size,_li);
}

static int op_stereo_filter(OggOpusFile *_of,void *_dst,int _dst_sz,
 op_sample *_src,int _nsamples,int _nchannels){
  (void)_of;
  _nsamples=OP_MIN(_nsamples,_dst_sz>>1);
  if(_nchannels==2)memcpy(_dst,_src,_nsamples*2*sizeof(*_src));
  else{
    float *dst;
    int    i;
    dst=(float *)_dst;
    if(_nchannels==1){
      for(i=0;i<_nsamples;i++)dst[2*i+0]=dst[2*i+1]=_src[i];
    }
    else{
      for(i=0;i<_nsamples;i++){
        float l;
        float r;
        int   ci;
        l=r=0;
        for(ci=0;ci<_nchannels;ci++){
          l+=OP_STEREO_DOWNMIX[_nchannels-3][ci][0]*_src[_nchannels*i+ci];
          r+=OP_STEREO_DOWNMIX[_nchannels-3][ci][1]*_src[_nchannels*i+ci];
        }
        dst[2*i+0]=l;
        dst[2*i+1]=r;
      }
    }
  }
  return _nsamples;
}

static int op_float2short_stereo_filter(OggOpusFile *_of,
 void *_dst,int _dst_sz,op_sample *_src,int _nsamples,int _nchannels){
  opus_int16 *dst;
  dst=(opus_int16 *)_dst;
  if(_nchannels==1){
    int i;
    _nsamples=op_float2short_filter(_of,dst,_dst_sz>>1,_src,_nsamples,1);
    for(i=_nsamples;i-->0;)dst[2*i+0]=dst[2*i+1]=dst[i];
  }
  else{
    if(_nchannels>2){
      _nsamples=OP_MIN(_nsamples,_dst_sz>>1);
      _nsamples=op_stereo_filter(_of,_src,_nsamples*2,
       _src,_nsamples,_nchannels);
    }
    _nsamples=op_float2short_filter(_of,dst,_dst_sz,_src,_nsamples,2);
  }
  return _nsamples;
}

int op_read_stereo(OggOpusFile *_of,opus_int16 *_pcm,int _buf_size){
  return op_filter_read_native(_of,_pcm,_buf_size,
   op_float2short_stereo_filter,NULL);
}

int op_read_float_stereo(OggOpusFile *_of,float *_pcm,int _buf_size){
  _of->state_channel_count=0;
  return op_filter_read_native(_of,_pcm,_buf_size,op_stereo_filter,NULL);
}

#endif
