// This file is part of Roxen Webserver.
// Copyright � 1996 - 2000, Roxen IS.
// $Id: module.pike,v 1.97 2000/09/05 15:06:30 per Exp $

#include <module_constants.h>
#include <module.h>
#include <request_trace.h>

inherit "basic_defvar";
mapping(string:array(int)) error_log=([]);

constant is_module = 1;
constant module_type   = MODULE_ZERO;
constant module_name   = "Unnamed module";
constant module_doc    = "Undocumented";
constant module_unique = 1;


private string _module_identifier;
private Configuration _my_configuration;
static mapping _api_functions = ([]);

string|array(string) module_creator;
string module_url;
RXML.TagSet module_tag_set;

/* These functions exists in here because otherwise the messages in
 * the event log does not always end up in the correct
 * module/configuration.  And the reason for that is that if the
 * messages are logged from subclasses in the module, the DWIM in
 * roxenlib.pike cannot see that they are logged from a module. This
 * solution is not really all that beatiful, but it works. :-)
 */
void report_fatal( mixed ... args )  { predef::report_fatal( @args );  }
void report_error( mixed ... args )  { predef::report_error( @args );  }
void report_notice( mixed ... args ) { predef::report_notice( @args ); }
void report_debug( mixed ... args )  { predef::report_debug( @args );  }


string module_identifier()
{
  if (!_module_identifier) {
    string|mapping name = register_module()[1];
    if (mappingp (name)) name = name->standard;
    string cname = sprintf ("%O", my_configuration());
    if (sscanf (cname, "Configuration(%s", cname) == 1 &&
	sizeof (cname) && cname[-1] == ')')
      cname = cname[..sizeof (cname) - 2];
    _module_identifier = sprintf ("%s,%s", name || module_name, cname);
  }
  return _module_identifier;
}

string _sprintf()
{
  return "RoxenModule(" +
    (Roxen.get_modname (this_object()) || module_identifier()) + ")";
}

array register_module()
{
  return ({
    module_type,
    module_name,
    module_doc,
    0,
    module_unique,
  });
}

string fix_cvs(string from)
{
  from = replace(from, ({ "$", "Id: "," Exp $" }), ({"","",""}));
  sscanf(from, "%*s,v %s", from);
  return replace(from,"/","-");
}

int module_dependencies(Configuration configuration,
                        array (string) modules,
                        int|void now)
//! If your module depends on other modules present in the server,
//! calling <pi>module_dependencies()</pi>, supplying an array of
//! module identifiers (the filename minus extension, more or less).
{
  if(configuration || my_configuration() ) 
    (configuration||my_configuration())->add_modules( modules, now );
  return 1;
}

string file_name_and_stuff()
{
  return ("<b>Loaded from:</b> "+(roxen->filename(this_object()))+"<br>"+
	  (this_object()->cvs_version?
           "<b>CVS Version: </b>"+
           fix_cvs(this_object()->cvs_version)+"\n":""));
}


Configuration my_configuration()
//! Returns the Configuration object of the virtual server the module
//! belongs to.
{
  if(_my_configuration)
    return _my_configuration;
  Configuration conf;
  foreach(roxen->configurations, conf)
    if(conf->otomod[this_object()])
      return _my_configuration = conf;
  return 0;
}

nomask void set_configuration(Configuration c)
{
  if(_my_configuration && _my_configuration != c)
    error("set_configuration() called twice.\n");
  _my_configuration = c;
}

void set_module_creator(string|array(string) c)
//! Set the name and optionally email address of the author of the
//! module. Names on the format "author name <author_email>" will
//! end up as links on the module's information page in the admin
//! interface. In the case of multiple authors, an array of such
//! strings can be passed.
{
  module_creator = c;
}

void set_module_url(string to)
//! A common way of referring to a location where you maintain
//! information about your module or similar. The URL will turn up
//! on the module's information page in the admin interface,
//! referred to as the module's home page.
{
  module_url = to;
}

void free_some_sockets_please(){}

void start(void|int num, void|Configuration conf) {}

string status() {}

string info(Configuration conf)
{
 return (this_object()->register_module()[2]);
}

void save_me()
{
  my_configuration()->save_one( this_object() );
}

void save()
{
  save_me();
}

string comment()
{
  return "";
}

string query_internal_location()
//! Returns the internal mountpoint, where <ref>find_internal()</ref>
//! is mounted.
{
  if(!_my_configuration)
    error("Please do not call this function from create()!\n");
  return _my_configuration->query_internal_location(this_object());
}

string query_location()
{
  string s;
  catch{s = query("location");};
  return s;
}

array(string) location_urls()
//! Returns an array of all locations where the module is mounted.
//! The first is the canonical one built with MyWorldLocation.
{
  string loc = query_location();
  if (!loc) return ({});
  if(!_my_configuration)
    error("Please do not call this function from create()!\n");
  string world_url = _my_configuration->query("MyWorldLocation");
  if (world_url == "") world_url = 0;
  array(string) urls = copy_value(_my_configuration->query("URLs"));
  string hostname = gethostname();
  for (int i = 0; i < sizeof (urls); i++) {
    if (world_url && glob (urls[i], world_url)) urls[i] = 0;
    else if (sizeof (urls[i]/"*") == 2)
      urls[i] = replace(urls[i], "*", hostname);
  }
  if (world_url) urls = ({world_url}) | (urls - ({0}));
  return map (urls, `+, loc[1..]);
}

/* By default, provide nothing. */
string query_provides() { return 0; }

/*
 * Parse and return a parsed version of the security levels for this module
 *
 */

class IP_with_mask 
{
  int net;
  int mask;
  static private int ip_to_int(string ip)
  {
    int res;
    foreach(((ip/".") + ({ "0", "0", "0" }))[..3], string num) {
      res = res*256 + (int)num;
    }
    return(res);
  }
  void create(string _ip, string|int _mask)
  {
    net = ip_to_int(_ip);
    if (intp(_mask)) {
      if (_mask > 32) {
	report_error(sprintf("Bad netmask: %s/%d\n"
			     "Using %s/32\n", _ip, _mask, _ip));
	_mask = 32;
      }
      mask = ~0<<(32-_mask);
    } else {
      mask = ip_to_int(_mask);
    }
    if (net & ~mask) {
      report_error(sprintf("Bad netmask: %s for network %s\n"
			   "Ignoring node-specific bits\n", _ip, _mask));
      net &= mask;
    }
  }
  int `()(string ip)
  {
    return((ip_to_int(ip) & mask) == net);
  }
};

array query_seclevels()
{
  array patterns=({ });

  if(catch(query("_seclevels")) || (query("_seclevels") == 0))
    return patterns;

  foreach(replace(query("_seclevels"),
		  ({" ","\t","\\\n"}),
		  ({"","",""}))/"\n", string sl) {
    if(!strlen(sl) || sl[0]=='#')
      continue;

    string type, value;
    if(sscanf(sl, "%s=%s", type, value)==2)
    {
      array(string|int) arr;
      switch(lower_case(type))
      {
      case "allowip":
	if (sizeof(arr = (value/"/")) == 2) {
	  // IP/bits
	  arr[1] = (int)arr[1];
	  patterns += ({ ({ MOD_ALLOW, IP_with_mask(@arr) }) });
	} else if ((sizeof(arr = (value/":")) == 2) ||
		   (sizeof(arr = (value/",")) > 1)) {
	  // IP:mask or IP,mask
	  patterns += ({ ({ MOD_ALLOW, IP_with_mask(@arr) }) });
	} else {
	  // Pattern
	  value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
	  patterns += ({ ({ MOD_ALLOW, Regexp(value)->match, }) });
	}
	break;

      case "acceptip":
	// Short-circuit version of allow ip.
	if (sizeof(arr = (value/"/")) == 2) {
	  // IP/bits
	  arr[1] = (int)arr[1];
	  patterns += ({ ({ MOD_ACCEPT, IP_with_mask(@arr) }) });
	} else if ((sizeof(arr = (value/":")) == 2) ||
		   (sizeof(arr = (value/",")) > 1)) {
	  // IP:mask or IP,mask
	  patterns += ({ ({ MOD_ACCEPT, IP_with_mask(@arr) }) });
	} else {
	  // Pattern
	  value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
	  patterns += ({ ({ MOD_ACCEPT, Regexp(value)->match, }) });
	}
	break;

      case "denyip":
	if (sizeof(arr = (value/"/")) == 2) {
	  // IP/bits
	  arr[1] = (int)arr[1];
	  patterns += ({ ({ MOD_DENY, IP_with_mask(@arr) }) });
	} else if ((sizeof(arr = (value/":")) == 2) ||
		   (sizeof(arr = (value/",")) > 1)) {
	  // IP:mask or IP,mask
	  patterns += ({ ({ MOD_DENY, IP_with_mask(@arr) }) });
	} else {
	  // Pattern
	  value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
	  patterns += ({ ({ MOD_DENY, Regexp(value)->match, }) });
	}
	break;

      case "allowuser":
	value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
	array(string) users = (value/"," - ({""}));
	int i;

	for(i=0; i < sizeof(users); i++) {
	  if (lower_case(users[i]) == "any") {
	    if(this_object()->register_module()[0] & MODULE_PROXY)
	      patterns += ({ ({ MOD_PROXY_USER, lambda(){ return 1; } }) });
	    else
	      patterns += ({ ({ MOD_USER, lambda(){ return 1; } }) });
	    break;
	  } else {
	    users[i & 0x0f] = "(^"+users[i]+"$)";
	  }
	  if ((i & 0x0f) == 0x0f) {
	    value = users[0..0x0f]*"|";
	    if(this_object()->register_module()[0] & MODULE_PROXY) {
	      patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
	    } else {
	      patterns += ({ ({ MOD_USER, Regexp(value)->match, }) });
	    }
	  }
	}
	if (i & 0x0f) {
	  value = users[0..(i-1)&0x0f]*"|";
	  if(this_object()->register_module()[0] & MODULE_PROXY) {
	    patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
	  } else {
	    patterns += ({ ({ MOD_USER, Regexp(value)->match, }) });
	  }
	}
	break;

      case "acceptuser":
	// Short-circuit version of allow user.
	// NOTE: MOD_PROXY_USER is already short-circuit.
	value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
        users = (value/"," - ({""}));

	for(i=0; i < sizeof(users); i++) {
	  if (lower_case(users[i]) == "any") {
	    if(this_object()->register_module()[0] & MODULE_PROXY)
	      patterns += ({ ({ MOD_PROXY_USER, lambda(){ return 1; } }) });
	    else
	      patterns += ({ ({ MOD_ACCEPT_USER, lambda(){ return 1; } }) });
	    break;
	  } else {
	    users[i & 0x0f] = "(^"+users[i]+"$)";
	  }
	  if ((i & 0x0f) == 0x0f) {
	    value = users[0..0x0f]*"|";
	    if(this_object()->register_module()[0] & MODULE_PROXY) {
	      patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
	    } else {
	      patterns += ({ ({ MOD_ACCEPT_USER, Regexp(value)->match, }) });
	    }
	  }
	}
	if (i & 0x0f) {
	  value = users[0..(i-1)&0x0f]*"|";
	  if(this_object()->register_module()[0] & MODULE_PROXY) {
	    patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
	  } else {
	    patterns += ({ ({ MOD_ACCEPT_USER, Regexp(value)->match, }) });
	  }
	}
	break;

      default:
	report_error(sprintf("Unknown Security:Patterns directive: "
			     "type=\"%s\"\n", type));
	break;
      }
    } else {
      report_error(sprintf("Syntax error in Security:Patterns directive: "
			   "line=\"%s\"\n", sl));
    }
  }
  return patterns;
}

Stat stat_file(string f, RequestID id){}
array(string) find_dir(string f, RequestID id){}
mapping(string:Stat) find_dir_stat(string f, RequestID id)
{
  TRACE_ENTER("find_dir_stat(): \""+f+"\"", 0);

  array(string) files = find_dir(f, id);
  mapping(string:Stat) res = ([]);

  foreach(files || ({}), string fname) {
    TRACE_ENTER("stat()'ing "+ f + "/" + fname, 0);
    Stat st = stat_file(f + "/" + fname, id);
    if (st) {
      res[fname] = st;
      TRACE_LEAVE("OK");
    } else {
      TRACE_LEAVE("No stat info");
    }
  }

  TRACE_LEAVE("");
  return(res);
}

string real_file(string f, RequestID id){}

void add_api_function( string name, function f, void|array(string) types)
{
  _api_functions[name] = ({ f, types });
}

mapping api_functions()
{
  return _api_functions;
}

mapping(string:function) query_tag_callers()
//! Compat
{
  mapping(string:function) m = ([]);
  foreach(glob("tag_*", indices( this_object())), string q)
    if(functionp( this_object()[q] ))
      m[replace(q[4..], "_", "-")] = this_object()[q];
  return m;
}

mapping(string:function) query_container_callers()
//! Compat
{
  mapping(string:function) m = ([]);
  foreach(glob("container_*", indices( this_object())), string q)
    if(functionp( this_object()[q] ))
      m[replace(q[10..], "_", "-")] = this_object()[q];
  return m;
}

mapping(string:array(int|function)) query_simpletag_callers()
{
  mapping(string:array(int|function)) m = ([]);
  foreach(glob("simpletag_*", indices(this_object())), string q)
    if(functionp(this_object()[q]))
      m[replace(q[10..],"_","-")] =
	({ intp (this_object()[q + "_flags"]) && this_object()[q + "_flags"],
	   this_object()[q] });
  return m;
}

mapping(string:array(int|function)) query_simple_pi_tag_callers()
{
  mapping(string:array(int|function)) m = ([]);
  foreach (glob ("simple_pi_tag_*", indices (this_object())), string q)
    if (functionp (this_object()[q]))
      m[replace (q[sizeof ("simple_pi_tag_")..], "_", "-")] =
	({(intp (this_object()[q + "_flags"]) && this_object()[q + "_flags"]) |
	  RXML.FLAG_PROC_INSTR, this_object()[q]});
  return m;
}

RXML.TagSet query_tag_set()
{
  if (!module_tag_set) {
    array(function|program|object) tags =
      filter (rows (this_object(),
		    glob ("Tag*", indices (this_object()))),
	      functionp);
    for (int i = 0; i < sizeof (tags); i++)
      if (programp (tags[i]))
	if (!tags[i]->is_RXML_Tag) tags[i] = 0;
	else tags[i] = tags[i]();
      else {
	tags[i] = tags[i]();
	// Bogosity: The check is really a little too late here..
	if (!tags[i]->is_RXML_Tag) tags[i] = 0;
      }
    tags -= ({0});
    module_tag_set =
      (this_object()->ModuleTagSet || RXML.TagSet) (module_identifier(), tags);
  }
  return module_tag_set;
}

mixed get_value_from_file(string path, string index, void|string pre)
{
  Stdio.File file=Stdio.File();
  if(!file->open(path,"r")) return 0;
  if(index[sizeof(index)-2..sizeof(index)-1]=="()") {
    return compile_string((pre||"")+file->read())[index[..sizeof(index)-3]]();
  }
  return compile_string((pre||"")+file->read())[index];
}
