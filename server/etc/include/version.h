// Version information
// $Id: version.h,v 1.264 2001/05/30 09:31:49 distmaker Exp $
// 
// Note that version information (major and minor) is also
// present in module.h.
constant __roxen_version__ = "2.2";
constant __roxen_build__ = "74";

#ifdef __NT__
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+" NT";
#else
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__;
#endif
