#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "xs_object_magic.h"

#include "4store.h"

static SV *
S_new_instance (pTHX_ HV *klass)
{
  SV *obj, *self;

  obj = (SV *)newHV();
  self = newRV_noinc(obj);
  sv_bless(self, klass);

  return self;
}

static SV *
S_attach_struct (pTHX_ SV *obj, void *ptr)
{
  xs_object_magic_attach_struct(aTHX_ SvRV(obj), ptr);
  return obj;
}

#define new_instance(klass)  S_new_instance(aTHX_ klass)
#define attach_struct(obj, ptr)  S_attach_struct(aTHX_ obj, ptr)

#define EXPORT_FLAG(flag)  newCONSTSUB(stash, #flag, newSVuv(flag))

MODULE = FourStore  PACKAGE = FourStore::Link  PREFIX = fsp_link_

PROTOTYPES: DISABLE

BOOT:
{
  HV *stash = gv_stashpvs("FourStore", 0);

  EXPORT_FLAG(FS_RID_NULL);
  EXPORT_FLAG(FS_RID_GONE);

  EXPORT_FLAG(FS_BIND_MODEL);
  EXPORT_FLAG(FS_BIND_SUBJECT);
  EXPORT_FLAG(FS_BIND_PREDICATE);
  EXPORT_FLAG(FS_BIND_OBJECT);
  EXPORT_FLAG(FS_BIND_DISTINCT);
  EXPORT_FLAG(FS_BIND_OPTIONAL);
  EXPORT_FLAG(FS_BIND_UNION);
  EXPORT_FLAG(FS_QUERY_CONSOLE_OUTPUT);

  EXPORT_FLAG(FS_BIND_SAME_MASK);
  EXPORT_FLAG(FS_BIND_SAME_XXXX);
  EXPORT_FLAG(FS_BIND_SAME_XXAA);
  EXPORT_FLAG(FS_BIND_SAME_XAXA);
  EXPORT_FLAG(FS_BIND_SAME_XAAX);
  EXPORT_FLAG(FS_BIND_SAME_XAAA);
  EXPORT_FLAG(FS_BIND_SAME_AXXA);
  EXPORT_FLAG(FS_BIND_SAME_AXAX);
  EXPORT_FLAG(FS_BIND_SAME_AXAA);
  EXPORT_FLAG(FS_BIND_SAME_AAXX);
  EXPORT_FLAG(FS_BIND_SAME_AAXA);
  EXPORT_FLAG(FS_BIND_SAME_AAAX);
  EXPORT_FLAG(FS_BIND_SAME_AAAA);
  EXPORT_FLAG(FS_BIND_SAME_AABB);
  EXPORT_FLAG(FS_BIND_SAME_ABAB);
  EXPORT_FLAG(FS_BIND_SAME_ABBA);

  EXPORT_FLAG(FS_QUERY_RESTRICTED);

  EXPORT_FLAG(FS_BIND_BY_SUBJECT);
  EXPORT_FLAG(FS_BIND_BY_OBJECT);
  EXPORT_FLAG(FS_BIND_END);
  EXPORT_FLAG(FS_BIND_PRICE);
  EXPORT_FLAG(FS_QUERY_EXPLAIN);
  EXPORT_FLAG(FS_QUERY_COUNT);
  EXPORT_FLAG(FS_QUERY_DEFAULT_GRAPH);
}


void
new (klass, const char *name, char *pw, int readonly=0)
    SV *klass
  PREINIT:
    fsp_link *link;
  PPCODE:
    if (!(link = fsp_open_link(name, pw, readonly))) {
      croak("foo");
    }

    XPUSHs(attach_struct(new_instance(gv_stashsv(klass, 0)), link));

void
DESTROY (fsp_link *link)
    CODE:
      fsp_close_link(link);

int
fsp_link_segments (fsp_link *link)

const char *
fsp_link_features (fsp_link *link)

#int
#fsp_bind_limit (fsp_link *link, fs_segment segment, int flags, fs_rid_vector *mrids, fs_rid_vector *srids, fs_rid_vector *prids, fs_rid_vector *orids, fs_rid_vector ***result, int offset, int limit)

void
bind_limit_all (link, flags, mrids, srids, prids, orids, offset, limit)
    fsp_link *link
    int flags
    fs_rid_vector *mrids
    fs_rid_vector *srids
    fs_rid_vector *prids
    fs_rid_vector *orids
    int offset
    int limit
  PREINIT:
    fs_rid_vector **result;
    int k, cols = 0;
  PPCODE:
    if (fsp_bind_limit_all (link, flags, mrids, srids, prids, orids, &result, offset, limit))
      croak("moo");

    if (!result)
      XSRETURN_EMPTY;

    for (k = 0; k < 4; ++k) {
      if (flags & (1 << k)) {
        XPUSHs(sv_2mortal(attach_struct(new_instance(gv_stashpvs("FourStore::RidVector", 0)), result[cols])));
        cols++;
      }
    }

MODULE = FourStore  PACKAGE = FourStore::RidVector  PREFIX = fs_rid_vector_

void
new (class, length=0)
    SV *class
    int length
  PREINIT:
    fs_rid_vector *vec;
  PPCODE:
    vec = fs_rid_vector_new(length);
    XPUSHs(attach_struct(new_instance(gv_stashsv(class, 0)), vec));

void
fs_rid_vector_append (vec, ...)
    fs_rid_vector *vec
  PREINIT:
    int i;
  CODE:
    for (i = 0; i < items; i++) {
      fs_rid_vector_append(vec, SvUV(ST(i)));
    }

void
fs_rid_vector_append_vector (vec, ...)
    fs_rid_vector *vec
  PREINIT:
    int i;
  CODE:
    for (i = 0; i < items; i++) {
      fs_rid_vector_append_vector(vec, (fs_rid_vector *)xs_object_magic_get_struct_rv_pretty(aTHX_ ST(i), "$var"));
    }

SV *
fs_rid_vector_copy(fs_rid_vector *v)
  CODE:
    RETVAL = attach_struct(new_instance(SvSTASH(SvRV(ST(0)))), fs_rid_vector_copy(v));
  OUTPUT:
    RETVAL

U32
fs_rid_vector_length (fs_rid_vector *v)

AV *
data (fs_rid_vector *v)
  PREINIT:
    int i, len;
  CODE:
    len = fs_rid_vector_length(v);
    RETVAL = newAV();
    for (i = 0; i < len; i++)
      av_push(RETVAL, newSVuv(v->data[i]));
  OUTPUT:
    RETVAL

void
DESTROY (fs_rid_vector *v)
  CODE:
    fs_rid_vector_free(v);

#int fsp_bind_limit_many (fsp_link *link,
#                         int flags,
#                         fs_rid_vector *mrids,
#                         fs_rid_vector *srids,
#                         fs_rid_vector *prids,
#                         fs_rid_vector *orids,
#                         fs_rid_vector ***result,
#                         int offset,
#                         int limit);

#int fsp_bind_limit_all (fsp_link *link,
#                  int flags,
#                  fs_rid_vector *mrids,
#                  fs_rid_vector *srids,
#                  fs_rid_vector *prids,
#                  fs_rid_vector *orids,
#                  fs_rid_vector ***result,
#                  int offset,
#                  int limit);
