XS(XS_Internals_PAR_BOOT) {
    GV* tmpgv;
    AV* tmpav;
    SV** svp;
    int i;
    int ok = 0;
    char *buf;

    TAINT;

    if (!(buf = par_getenv("PAR_INITIALIZED")) || buf[0] != '1' || buf[1] != '\0') {
        par_init_env();
    }

    if ((tmpgv = gv_fetchpv("\030",TRUE, SVt_PV))) {/* $^X */
#ifdef WIN32
        sv_setpv(GvSV(tmpgv),"perl.exe");
#else
        sv_setpv(GvSV(tmpgv),"perl");
#endif
        SvSETMAGIC(GvSV(tmpgv));
    }

    if ((tmpgv = gv_fetchpv("0", TRUE, SVt_PV))) {/* $0 */
    	char *prog = NULL;
        if ( ( prog = par_getenv("PAR_PROGNAME") ) ) {
            sv_setpv(GvSV(tmpgv), prog);
        }
        else {
#ifdef HAS_PROCSELFEXE
            S_procself_val(aTHX_ GvSV(tmpgv), fakeargv[0]);
#else
#ifdef OS2
            sv_setpv(GvSV(tmpgv), os2_execname(aTHX));
#else
            prog = par_current_exec();

            if( prog != NULL ) {
                sv_setpv( GvSV(tmpgv), prog );
                free( prog );
            }
            else {
                sv_setpv(GvSV(tmpgv), fakeargv[0]);
            }
#endif
#endif
        }
    }

    /* PAR::Packer isn't included in a packed executable, but we provide
     * this scalar so that a packed script may refer to the version
     * of PAR::Packer it was built with.
     */
    sv_setpv(get_sv("PAR::Packer::VERSION", GV_ADD), stringify(PAR_PACKER_VERSION));

    TAINT_NOT;

    /* create temporary PAR directory */
    stmpdir = par_getenv("PAR_TEMP");
    if ( !stmpdir ) {
        stmpdir = par_mktmpdir( fakeargv );
        if ( !stmpdir )
            croak("Unable to create cache directory");
    }
    i = PerlDir_mkdir(stmpdir, 0700);
    if ( (i != 0) && (i != EEXIST) && (i != -1) ) {
        croak("%s: creation of private cache subdirectory %s failed (errno=%i)\n",
              fakeargv[0], stmpdir, i);
    }
}

static void par_xs_init(pTHX)
{
    xs_init(aTHX);
    newXSproto("Internals::PAR::BOOT", XS_Internals_PAR_BOOT, "", "");
}
