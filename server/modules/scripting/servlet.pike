#include <module.h>

string cvs_version = "$Id: servlet.pike,v 1.5 1999/08/26 16:50:53 js Exp $";
int thread_safe=1;

inherit "module";
inherit "roxenlib";
static inherit "http";

/* Doesn't work on NT yet */
#ifndef __NT__
#if constant(Java)

object servlet;

string status_info="";

array register_module()
{
  return ({
    MODULE_LOCATION, "Java Servlet bridge",
    "An interface to Java <a href=\"http://jserv.javasoft.com/"
    "products/java-server/servlets/index.html\">Servlets</a>.",
    0
  });
}

void stop()
{
  if(servlet) {
    destruct(servlet);
    servlet = 0;
  }
}

static mapping(string:string) make_initparam_mapping()
{
  mapping(string:string) p = ([]);
  string n, v;
  foreach(QUERY(parameters)/"\n", string s)
    if(2==sscanf(s, "%[^=]=%s", n, v))
      p[n]=v;
  return p;
}

void start(int x, object conf)
{
  if(x == 2)
    stop();
  else if(x != 0)
    return;

  mixed exc = catch(servlet = Servlet.servlet(QUERY(classname),
					      QUERY(codebase)));
  status_info="";
  if(exc)
  {
    werror(exc[0]);
    status_info=sprintf("<pre>%s</pre>",exc[0]);
  }
  else
    if(servlet)
      servlet->init(Servlet.conf_context(conf), make_initparam_mapping());
}

string status()
{
  return (servlet?
	  servlet->info() || "<i>No servlet information available</i>" :
	  "<font color=red>Servlet not loaded</font>"+"<br>"+
	  status_info);
}

string query_location()
{
  return QUERY(mountpoint);
}

string query_name()
{
  return sprintf("<i>%s</i> mounted on <i>%s</i>", query("classname"),
		 query("mountpoint"));
}

void create()
{
  defvar("mountpoint", "/servlet/NONE", "Servlet location", TYPE_LOCATION,
	 "This is where the servlet will be inserted in the "
	 "namespace of your server.");

  defvar("codebase", "servlets", "Code directory", TYPE_DIR,
	 "This is the base directory for the servlet class files.");

  defvar("classname", "NONE", "Class name", TYPE_STRING,
	 "The name of the servlet class to use.");

  defvar("parameters", "", "Parameters", TYPE_TEXT,
	 "Parameters for the servlet on the form "
	 "<tt><i>name</i>=<i>value</i></tt>, one per line.");
  defvar("debugmode", "Log", "Error messages", TYPE_STRING_LIST | VAR_MORE,
	 "How to report errors (e.g. backtraces generated by the Pike code):\n"
	 "\n"
	 "<p><ul>\n"
	 "<li><i>Off</i> - Silent.\n"
	 "<li><i>Log</i> - System debug log.\n"
	 "<li><i>HTML comment</i> - Include in the generated page as an HTML comment.\n"
	 "<li><i>HTML text</i> - Include in the generated page as normal text.\n"
	 "</ul>\n",
	 ({"Off", "Log", "HTML comment", "HTML text"}));

}

string reporterr (string header, string dump)
{
  if (QUERY (debugmode) == "Off") return "";

  report_error (header + dump + "\n");

  switch (QUERY (debugmode)) {
    case "HTML comment":
      return "\n<!-- " + header + dump + "\n-->\n";
    case "HTML text":
      return "\n<br><font color=red><b>" + html_encode_string (header) +
	"</b></font><pre>\n" + html_encode_string (dump) + "</pre><br>\n";
    default:
      return "";
  }
}

mixed find_file( string f, object id )
{
  if(!servlet)
    return http_string_answer(reporterr("Servlet loading failed",status_info));
  
  id->my_fd->set_read_callback(0);
  id->my_fd->set_close_callback(0);
  id->my_fd->set_blocking();
  id->misc->path_info = f;
  id->misc->mountpoint = QUERY(mountpoint);
  servlet->service(id);

  return http_pipe_in_progress();
}

#endif
#end
