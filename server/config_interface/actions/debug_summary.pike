/*
 * $Id: debug_summary.pike,v 1.1 2002/03/27 15:06:11 js Exp $
 */
#include <stat.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("admin_tasks",X,Y)

constant action = "debug_info";

LocaleString name= LOCALE(0,"Debug Summary");
LocaleString doc = LOCALE(0,
		    "Shows a text file containing a configuration summary, suitable "
		    "for support purposes.");

int creation_date = time();

int no_reload()
{
  return creation_date > file_stat( __FILE__ )[ST_MTIME];
}

string get_cvs_versions(string dir)
{
  string res="";
  foreach(sort(get_dir(dir)), string fn)
  {
    if(file_stat(dir+"/"+fn)->isdir && fn!="CVS")
      res+=get_cvs_versions(dir+"/"+fn);
    else
      res+=replace(dir+"/"+fn,
		   ({"//", "\\\\"}),
		   ({"/", "\\"}))+"\n";
  }
  return res;
}

string indent(string text, int level)
{
  array a=text/"\n";
  for(int i=0; i<sizeof(a); i++)
    if(sizeof(a[i]))
      a[i]="  "*level+a[i];
  return a*"\n";
}

string describe_var(mixed value)
{
  if(arrayp(value))
    return "{"+map(value, describe_var)*", "+"}";
  else 
    return sprintf("%O", value);
}

string make_headline(string title)
{
  return sprintf("%s:\n%s\n", title, "-"*(sizeof(title)+1));
}

string make_environment_summary()
{
  string res = make_headline("Environment");
  res+=sprintf("  %-30s %s\n", "Version:", roxen_version());
  res+=sprintf("  %-30s %s", "Time:", ctime(time()));
  res+=sprintf("  %-30s %s\n", "Host:", gethostname());
#ifdef __NT__
  res+=sprintf("  %-30s %s\n", "Platform:", "NT");
#else
  res+=sprintf("  %-30s %s %s %s\n", "Platform:",
	       uname()->sysname||"",
	       uname()->release||"",
	       uname()->machine);
#endif

  res += "\n";
  res += make_headline("Local environment variables");
  res += indent(Stdio.read_file("../local/environment"), 1);  

  res += "\n";
  res += make_headline("System environment variables");
  foreach(sort(indices(getenv())), string envvar)
    res+=sprintf("  %-30s %s\n", envvar+":", getenv(envvar));
  
  return res;
}

string make_variables_summary(mapping vars)
{
  string res="";
  foreach(sort(indices(vars)), string varname)
    res+=sprintf("%s%-30s %s\n",
		 vars[varname]->is_defaulted()?"  ":" *",
		 varname+":",
		 describe_var(vars[varname]->query()));
  return res;
}

string make_extra_module_info(RoxenModule module)
{
  if(module->debug_summary && functionp(module->debug_summary))
  {
    string res="\n"+make_headline("Extra info");
    mixed err=catch(res += indent(module->debug_summary(), 1));
    if(err)
      res+=describe_backtrace(err);
    return res;
  }
  return "";
}

string make_configuration_summary(string configuration)
{
  mixed c=roxen->find_configuration(configuration);
  mapping vars = c->getvars();
  string res = make_headline("Globals");
  res += make_variables_summary(c->getvars())+"\n\n";
  foreach(values(c->modules), mixed modulecopies)
    foreach(values(modulecopies->copies), RoxenModule module)
      res += sprintf("%s%s%s\n\n",
		     make_headline(module->module_identifier()),
		     make_variables_summary(module->getvars()),
		     indent(make_extra_module_info(module),1));
  return res;
}

mixed parse( RequestID id )
{
  string res=make_headline("Debug summary")+"\n";

  res += make_environment_summary()+"\n";

//    res +=make_headline("CVS file versions");
//    res +=indent(get_cvs_versions(getcwd()), 1);

  foreach(roxen->list_all_configurations(), string configuration)
  {
    res+=make_headline("Configuration: "+configuration)+"\n";
    res+=indent(make_configuration_summary(configuration),1);
  }

  return "<pre>"+Roxen.html_encode_string(res)+"</pre>";
}
