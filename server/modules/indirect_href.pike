// This is a virtual "file-system".
// It will be located somewhere in the name-space of the server.
#include <module.h>

inherit "module";
inherit "roxenlib";

mapping hrefs;
string tagname;

void create()
{
  defvar( "hrefs", "", "Indirect hrefs", TYPE_TEXT_FIELD, 
	 "Syntax:\n"
	 + "[name] = [URL]\n" );
  defvar( "tagname", "newa", "Tagname", TYPE_STRING, 
	 "Name of the tag\n"
	 + "&lt;tag name=[name]&gt;foo&lt;/tag&gt; will be replaced with\n"
	 + "&lt;a href=[URL]&gt;foo&lt;/a&gt;" );
}

mixed *register_module()
{
  return ({ 
    MODULE_PARSER,
    "Indirect href", 
    ("Indirect href")
    });
}

void start()
{
  string *lines, line;
  string variable, value, *foo;
  string dir = "";
  mapping all = ([ ]);

  hrefs = ([ ]);
  if (lines = query( "hrefs" ) /"\n")
    foreach (lines, line)
      if (sscanf( line, "%s=%s", variable, value ) >= 2)
	hrefs[ variable - " " - "\t" ] = value - " " - "\t";
  tagname = query( "tagname" );
}

string tag_newa( string tag, mapping m, string q, mapping got )
{
  if (m[ "name" ] && hrefs[ m[ "name" ] ])
    return "<a href=" + hrefs[ m[ "name" ] ] + ">" + q + "</a>";
  else if (m[ "random" ])
    return "<a href=" + values( hrefs )[ random( sizeof( hrefs ) ) ] + ">"
      + q + "</a>";
  else
    return q;
}

mapping query_container_callers()
{
  return ([ tagname : tag_newa ]);
}

