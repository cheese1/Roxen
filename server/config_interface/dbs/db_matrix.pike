#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)



string get_conf_name( string c )
{
  Configuration cfg = roxen.find_configuration( c );
  return cfg->query_name();
}

string|mapping parse( RequestID id )
{
  if( id->variables->db )
  {
    if( id->variables->set_read )
      DBManager.set_permission( id->variables->db,
                                roxen.find_configuration(id->variables->set_read),
                                DBManager.READ );
    if( id->variables->set_write )
      DBManager.set_permission( id->variables->db,
                                roxen.find_configuration(id->variables->set_write),
                                DBManager.WRITE );
    if( id->variables->set_none )
      DBManager.set_permission( id->variables->db,
                                roxen.find_configuration(id->variables->set_none),
                                DBManager.NONE );
  }

  array colors = ({
    ({
      "&usr.matrix11;",
      "&usr.matrix21;",
    }),
    ({
      "&usr.matrix12;",
      "&usr.matrix22;",
    }),
  });
  
  mapping q = DBManager.get_permission_map( );
  if( !sizeof( q ) )
    return "No defined datbases\n";
  string res = "<br /><table border='0' cellpadding='4' cellspacing='0'>\n";
  int x, y;
  int i = 1;
  int tc = sizeof( roxen->configurations )+2;
  if( tc < 8 )
  {
    foreach( sort(roxen->configurations->name), string conf )
    {
      res += "<tr>";
      for( int j = 0; j<i; j++ )
      {
        if( j )
        {
          string ct = colors[0][j%sizeof(colors)];
          res += "<td bgcolor='"+ct+"'>&nbsp;</td>";
        }
        else
          res += "<td></td>";
      }
      string ct = colors[0][i%sizeof(colors)];
      res += "<td bgcolor='"+ct+"' colspan='"+(tc-i)+"'>"+
	get_conf_name(conf)+"</td>";
      res += "</tr>\n";
      i++;
    }
    res += "<tr>";
    for( int j = 0; j<i; j++ )
    {
      if( j )
      {
        string ct = colors[0][j%sizeof(colors)];
        res += "<td bgcolor='"+ct+"'>"
            "<img src='/internal-roxen-unit' alt='' width='1' height='5' /></td>";
      }
      else
        res += "<td></td>";
    }
    res += "</tr>";
  }
  else
  {
    res += "<tr><td>&nbsp;</td>";
    foreach( sort(roxen->configurations->name), string conf )
    {
      x++;
      string ct = colors[0][x%sizeof(colors)];
      res += "<td bgcolor='"+ct+"'valign=bottom><gtext scale='0.4' bgcolor='"+ct+"' rotate='90'>"+
          get_conf_name(conf)+"</gtext></td>";
    }
    res += "</tr>\n";
  }


  mapping rres = ([]);
  foreach( sort(indices(q)), string db )
  {
    mapping p = q[db];
    y++;
    x=0;
    if( !rres[ DBManager.db_group(db) ] )
    {
      y=0;
      rres[ DBManager.db_group(db) ]="";
    }
    string ct = colors[y%sizeof(colors)][0];
    int ii = DBManager.is_internal( db );
    rres[DBManager.db_group(db)] +=
        "<tr><td bgcolor='"+ct+"'>"
        "<nobr>"
        +"&nbsp; &nbsp;<a href='browser.pike?db="+db+"'>"+
        "<cimg border='0' format='gif'"
        "      src='&usr.database-small;' alt='' max-height='12'/>"
        "&nbsp;&nbsp;"+db+"</a>"+
        "</nobr>"
        "</td>";
    foreach( sort(roxen->configurations->name), string conf )
    {
      x++;
      string col = colors[y%sizeof(colors)][x%sizeof(colors[0])];
      string bgc = col;
      rres[DBManager.db_group(db)] += "<td bgcolor='"+col+"' width='1%'><nobr>";

#define PERM(P,T,L)\
     rres[DBManager.db_group(db)] += sprintf("<a href='?set_"+L+"=%s&db=%s'>"+\
		     "<gtext  fontsize=13 "+\
		     ">"+((p[conf]==DBManager.P)?(DBManager.P!=DBManager.NONE?"&nbsp;":"")+T:(DBManager.P!=DBManager.NONE?"&nbsp;-":"-"))+"</gtext>"\
		     "</a>", Roxen.http_encode_string(conf),\
		     Roxen.http_encode_string(db))

      PERM(NONE,_(0,"N"),"none");
      PERM(READ,_(0,"R"),"read");
      PERM(WRITE,_(0,"W"),"write");
      rres[DBManager.db_group(db)] += "</nobr></td>";
    }

    string format_stats( mapping s, string url )
    {
      if( !url )
        url = "internal";
      else
      {
	if( catch( DBManager.cached_get( db )->query("select 1") ) )
	  url="<font color='&usr.warncolor;'>"+
	    _(381,"Failed to connect")+"</font>";
	else
	  url = "remote";
      }
      if( !s )
        return url;
      return sprintf( "%s %.1fMb", url, s->size/1024.0/1024.0 );
    };

    array e;
    if( mixed e = catch {
      rres[DBManager.db_group(db)] += "<td align=right width='60%' >"+
	format_stats( DBManager.db_stats( db ),
		      DBManager.db_url( db ) )+"</td>";
    } )
    {
      string em = describe_error(e);
      sscanf( em, "%*sreconnect to SQL-server%s", em);
      rres[DBManager.db_group(db)] +=
	"<td width='60%'>"+DBManager.db_url( db )+"<br />"
	"<font color='&usr.warncolor;'>"+em+"</font></td>";
    }
    rres[DBManager.db_group(db)] += "</tr>\n";
  }

  array cats = ({});
  foreach( indices(rres), string c )
    if( c != "internal" )
      cats += ({ ({DBManager.get_group(c)->lname, c}) });
    else
      cats = ({ ({DBManager.get_group(c)->lname, c}) }) + cats;

  foreach( cats[0..0]+sort(cats[1..]), array q )
  {
    res += "<tr><td>\n";
    res += "<b><a href='edit_group.pike?group="+q[1]+"'>"+
      q[0]+"</a></b></td>";
    for( i = 0; i<sizeof( roxen->configurations ); i++ )
      res += "<td bgcolor='"+colors[(i+1)%sizeof(colors)][0]+
	"'>&nbsp;</td>";
    res += "<td></td></tr>\n";
    res += rres[ q[1] ];
  }
  return Roxen.http_string_answer(res+"</table>");
}
