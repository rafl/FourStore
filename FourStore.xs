#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "xs_object_magic.h"

#include "4store.h"

MODULE = FourStore  PACKAGE = FourStore::Link  PREFIX = fsp_link_

void
new (class, const char *name, char *pw, int readonly=0)
  PREINIT:
    fsp_link *link;
    SV *obj, *self;
  PPCODE:
    if (!(link = fsp_open_link(name, pw, readonly))) {
      croak("foo");
    }

    obj = (SV *)newHV();
    self = newRV_noinc(obj);
    sv_bless(self, gv_stashpvs("FourStore::Link", 0));
    xs_object_magic_attach_struct(aTHX_ obj, link);
    XPUSHs(self);

void
DESTROY (fsp_link *link)
    CODE:
      fsp_close_link(link);

int
fsp_link_segments (fsp_link *link)

const char *
fsp_link_features (fsp_link *link)
