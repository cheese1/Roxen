#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";
inherit "modules/filesystems/filesystem.pike" : filesystem;

constant cvs_version="$Id: autositefs.pike,v 1.2 1998/07/16 12:44:55 js Exp $";

mapping host_to_id;

array register_module()
{
  return ({ MODULE_LOCATION|MODULE_PARSER,
	    "AutoSite Filesystem",
	    "" });
}

string get_host(object id)
{
  return "www.idonex.se";
  if(id->misc->host)
    return (id->misc->host / ":")[0];
  else
    return 0;
}
  
void update_host_cache(object id)
{
  object db=id->conf->call_provider("sql","sql_object",id);
  array a=db->query("select * from dns where rr_type='CNAME'");
  mapping new_host_to_id=([]);
  if(!catch {
    Array.map(a,lambda(mapping entry, mapping m)
		{
		  m[entry->rr_value]=entry->id;
		},new_host_to_id);
  })
    host_to_id=new_host_to_id;
}

string file_from_host(object id, string file)
{
  string prefix,dir;
  if(prefix=host_to_id[get_host(id)])
    dir = "/" + prefix + "/";
  else
  {
    string host,rest="";
    sscanf(file,"%s/%s",host,rest);
    if(prefix=host_to_id[host])
    {
      dir="/" + prefix + "/";
      if(rest)
	file=rest;
    }
    else
      return 0; // No such host
  }
  dir = replace(dir, "//", "/");
  werror("file_from_host: %O\n",dir+file);
  return dir+file;
}

mixed find_file(string f, object id)
{
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  if(!file)
  {
    string s="";
    s+=
      "<h1>Foobar Gazonk AB</h1>"
      "You seem to be using a browser that doesn't send host header. "
      "Please upgrade your browser, or access the site you want to from the "
      "list below:<p><ul>";
    foreach(indices(host_to_id), string host)
      s+="<li><a href='/"+host+"/'>"+host+"</a>";
    return http_string_answer(parse_rxml(s,id),"text/html");
  }

  mixed res = filesystem::find_file(file, id);
  if(objectp(res))
  {
    if(roxen->type_from_filename( f, 0 ) == "text/html")
    {
      string d = res->read( );
      d="<template><content>"+d+"</content></template>";
      res=http_string_answer(parse_rxml(d,id),"text/html");
    }
  }
  return res;
}


string real_file(string f, mixed id)
{
  if(!sizeof(f) || f=="/")
    return 0;
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  if(!file)
    return 0; // FIXME, return a helpful page
  array(int) fs;

  // Use the inherited stat_file
  fs = filesystem::stat_file( file,id );

  if (fs && ((fs[1] >= 0) || (fs[1] == -2)))
    return f;
  return 0;
}

array find_dir(string f, object id)
{
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  if(!file)
    return 0; // FIXME, return got->conf->userlist(id);
  else
    return filesystem::find_dir(file, id);
}

mixed stat_file(mixed f, mixed id)
{
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  if(!file)
    return 0; // FIXME, return a helpful page
  else
    return filesystem::stat_file( file,id );
}
