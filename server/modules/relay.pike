#include "module.h"

inherit "module";
inherit "roxenlib";
inherit "socket";

#define CONN_REFUSED "\
505 Connection Refused by relay server\r\n\
Content-type: text/html\r\n\
\r\n\
<title>Connection refused by remote server</title>\
\
<h1 align=center>Connection refused by remote server</h1>\
<hr noshade>\
<font size=+2>Please try again later.</font>\
<i>Sorry</i>\
<hr noshade>"

/* Simply relay a request to another server if the data was not found. */

mixed *register_module()
{
  return ({ 
    MODULE_LAST | MODULE_FIRST,
    "HTTP-Relay", 
    "Relays HTTP requests, unknown to this server.",
    });
}

void create()
{
  defvar("pri", "Last", "Module priority", TYPE_STRING_LIST,
	 "If last, first try to find the file in a normal way, otherways, "
	 "first try redirection.",
	 ({ "Last", "First" }));

  defvar("relayh", "", "Relay host", TYPE_STRING,
	 "The ip-number of the host to relay to");

  defvar("relayp", 80, "Relay port", TYPE_INT,
	 "The port-number of the host to relay to");
  
  defvar("always", "", "Always redirect", TYPE_TEXT_FIELD,
	 "Always relay these, even if the URL match the 'Don't-list'.");

  defvar("anti", "", "Don`t redirect", TYPE_TEXT_FIELD,
	 "Never relay these, unless the URL match the 'Always-list'.");
}

string comment()
{
  return "http://"+query("relayh")+":"+query("relayp")+"/";
}

void nope(object hmm)
{
  if(hmm)
  {
    hmm->my_fd->write(CONN_REFUSED);
    hmm->end();
  }
}

void connected(object to, object id)
{
  if(!to) 
    return nope(id);
  to->write(replace(id->raw, "\n", "\r\n"));
  async_pipe(id->my_fd, to);
  id->do_not_disconnect = 0;
  id->disconnect();
}

array (string) always_list=({ });

array (string) anti_list = ({ });

void start()
{
  always_list=(QUERY(always)-"\r")/"\n";
  anti_list=(QUERY(anti)-"\r")/"\n";
}

#define match(s,b) do_match(b,s)

int is_in_anti_list(string s)
{
  int i;
  for(i=0; i<sizeof(anti_list); i++) 
    if(match(anti_list[i], s))  return 1;
}

int is_in_always_list(string s)
{
  int i;
  for(i=0; i<sizeof(always_list); i++) 
    if(match(always_list[i], s)) return 1;
}

mapping relay(object fid)
{
  if(!is_in_always_list(fid["not_query"]) &&
     is_in_anti_list(fid["not_query"]))
    return 0;
  
  fid -> do_not_disconnect = 1;
  
  async_connect(QUERY(relayh), QUERY(relayp), connected, fid );
  return http_pipe_in_progress();
}

mapping last_resort(object fid)
{
  if(QUERY(pri) != "Last")  return 0;
  return relay(fid);
}

mapping first_try(object fid)
{
  if(QUERY(pri) == "Last") return 0;
  return relay(fid);
}
