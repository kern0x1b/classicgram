#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "opus_header.h"
#include <string.h>
#include <stdio.h>

typedef struct {
   unsigned char *data;
   int maxlen;
   int pos;
} Packet;

typedef struct {
   const unsigned char *data;
   int maxlen;
   int pos;
} ROPacket;

static int write_uint32(Packet *p, ogg_uint32_t val)
{
   if (p->pos>p->maxlen-4)
      return 0;
   p->data[p->pos  ] = (val    ) & 0xFF;
   p->data[p->pos+1] = (val>> 8) & 0xFF;
   p->data[p->pos+2] = (val>>16) & 0xFF;
   p->data[p->pos+3] = (val>>24) & 0xFF;
   p->pos += 4;
   return 1;
}

static int write_uint16(Packet *p, ogg_uint16_t val)
{
   if (p->pos>p->maxlen-2)
      return 0;
   p->data[p->pos  ] = (val    ) & 0xFF;
   p->data[p->pos+1] = (val>> 8) & 0xFF;
   p->pos += 2;
   return 1;
}

static int write_chars(Packet *p, const unsigned char *str, int nb_chars)
{
   int i;
   if (p->pos>p->maxlen-nb_chars)
      return 0;
   for (i=0;i<nb_chars;i++)
      p->data[p->pos++] = str[i];
   return 1;
}

static int read_uint32(ROPacket *p, ogg_uint32_t *val)
{
   if (p->pos>p->maxlen-4)
      return 0;
   *val =  (ogg_uint32_t)p->data[p->pos  ];
   *val |= (ogg_uint32_t)p->data[p->pos+1]<< 8;
   *val |= (ogg_uint32_t)p->data[p->pos+2]<<16;
   *val |= (ogg_uint32_t)p->data[p->pos+3]<<24;
   p->pos += 4;
   return 1;
}

static int read_uint16(ROPacket *p, ogg_uint16_t *val)
{
   if (p->pos>p->maxlen-2)
      return 0;
   *val =  (ogg_uint16_t)p->data[p->pos  ];
   *val |= (ogg_uint16_t)p->data[p->pos+1]<<8;
   p->pos += 2;
   return 1;
}

static int read_chars(ROPacket *p, unsigned char *str, int nb_chars)
{
   int i;
   if (p->pos>p->maxlen-nb_chars)
      return 0;
   for (i=0;i<nb_chars;i++)
      str[i] = p->data[p->pos++];
   return 1;
}

int opus_header_parse(const unsigned char *packet, int len, OpusHeader *h)
{
   int i;
   char str[9];
   ROPacket p;
   unsigned char ch;
   ogg_uint16_t shortval;

   p.data = packet;
   p.maxlen = len;
   p.pos = 0;
   str[8] = 0;
   if (len<19)return 0;
   read_chars(&p, (unsigned char*)str, 8);
   if (memcmp(str, "OpusHead", 8)!=0)
      return 0;

   if (!read_chars(&p, &ch, 1))
      return 0;
   h->version = ch;
   if((h->version&240) != 0)
      return 0;

   if (!read_chars(&p, &ch, 1))
      return 0;
   h->channels = ch;
   if (h->channels == 0)
      return 0;

   if (!read_uint16(&p, &shortval))
      return 0;
   h->preskip = shortval;

   if (!read_uint32(&p, &h->input_sample_rate))
      return 0;

   if (!read_uint16(&p, &shortval))
      return 0;
   h->gain = (short)shortval;

   if (!read_chars(&p, &ch, 1))
      return 0;
   h->channel_mapping = ch;

   if (h->channel_mapping != 0)
   {
      if (!read_chars(&p, &ch, 1))
         return 0;

      if (ch<1)
         return 0;
      h->nb_streams = ch;

      if (!read_chars(&p, &ch, 1))
         return 0;

      if (ch>h->nb_streams || (ch+h->nb_streams)>255)
         return 0;
      h->nb_coupled = ch;

      for (i=0;i<h->channels;i++)
      {
         if (!read_chars(&p, &h->stream_map[i], 1))
            return 0;
         if (h->stream_map[i]>(h->nb_streams+h->nb_coupled) && h->stream_map[i]!=255)
            return 0;
      }
   } else {
      if(h->channels>2)
         return 0;
      h->nb_streams = 1;
      h->nb_coupled = h->channels>1;
      h->stream_map[0]=0;
      h->stream_map[1]=1;
   }

   if ((h->version==0 || h->version==1) && p.pos != len)
      return 0;
   return 1;
}

int opus_header_to_packet(const OpusHeader *h, unsigned char *packet, int len)
{
   int i;
   Packet p;
   unsigned char ch;

   p.data = packet;
   p.maxlen = len;
   p.pos = 0;
   if (len<19)return 0;
   if (!write_chars(&p, (const unsigned char*)"OpusHead", 8))
      return 0;

   ch = 1;
   if (!write_chars(&p, &ch, 1))
      return 0;

   ch = h->channels;
   if (!write_chars(&p, &ch, 1))
      return 0;

   if (!write_uint16(&p, h->preskip))
      return 0;

   if (!write_uint32(&p, h->input_sample_rate))
      return 0;

   if (!write_uint16(&p, h->gain))
      return 0;

   ch = h->channel_mapping;
   if (!write_chars(&p, &ch, 1))
      return 0;

   if (h->channel_mapping != 0)
   {
      ch = h->nb_streams;
      if (!write_chars(&p, &ch, 1))
         return 0;

      ch = h->nb_coupled;
      if (!write_chars(&p, &ch, 1))
         return 0;

      for (i=0;i<h->channels;i++)
      {
         if (!write_chars(&p, &h->stream_map[i], 1))
            return 0;
      }
   }

   return p.pos;
}

const int wav_permute_matrix[8][8] =
{
  {0},
  {0,1},
  {0,2,1},
  {0,1,2,3},
  {0,2,1,3,4},
  {0,2,1,4,5,3},
  {0,2,1,5,6,4,3},
  {0,2,1,6,7,4,5,3}
};
