#include <roxen.h>
LOCALE_PROJECT(config_interface);
#define LOCALE(X,Y)	_DEF_LOCALE(X,Y)

array pages =
({
  ({ LOCALE("", "Startpage"),     "",                0,               0             }),
  ({ LOCALE("", "Update"),        "update.html",     0,               0             }),
  ({ LOCALE("", "Your Settings"), "settings.html",   0,               0             }),
  ({ LOCALE("", "Users"),         "users.html",      "Edit Users",    0             }),
});

string parse(object id)
{
  string q="";
  while( id->misc->orig )  id = id->misc->orig;
  sscanf( id->not_query, "/%*s/%s", q );
  if( q == "index.html" )
    q = "";
  if( q == "whatsnew.html" )
    q = "";
  string res="";
  foreach( pages, array page )
  {
    string tpost = "";
    if( page[2] )
    {
      res += "<cf-perm perm='"+page[2]+"'>";
      tpost = "</cf-perm>"+tpost;
    }
    if( page[3] )
    {
      res += "<cf-userwants option='"+page[3]+"'>";
      tpost = "</cf-userwants>"+tpost;
    }

    string ea="";
    if( page == pages[0] )       ea = "first ";
    if( page == pages[-1] )      ea = "last=30 ";

    res += "<tab "+ea+"href='"+page[1]+"'"+((page[1] == q)?" selected='1'":"")+">" +
      page[0]+"</tab>" + tpost;
  }

  return res;
}
