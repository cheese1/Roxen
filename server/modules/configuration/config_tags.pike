// This is a roxen module. Copyright � 1999 - 2000, Roxen IS.
//
inherit "module";
inherit "html";
inherit "roxenlib";
#include <roxen.h>
#include <stat.h>
#include <config_interface.h>
#include <config.h>

//<locale-token project="config_interface">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("config_interface",X,Y)

#define CU_AUTH id->misc->config_user->auth

constant module_type = MODULE_PARSER|MODULE_CONFIG;
constant module_name = "Administration interface RXML tags";

/* Not exactly true, but the config filesystem forbids parallell
 * accesses anyway so there is no need for an extra lock here..
 */
constant thread_safe = 1;

#ifdef OLD_RXML_COMPAT
void start(int num, Configuration conf)
{
  if (!num) conf->old_rxml_compat++;
}

void stop()
{
  my_configuration()->old_rxml_compat--;
}
#endif

void create()
{
  query_tag_set()->prepare_context=set_entities;
}

class Scope_locale
{
  inherit RXML.Scope;
  mixed `[]  (string var, void|RXML.Context c, void|string scope)
  {
    function(void:string)|string val;
    // DEBUG
    val = LOCALE(var,var);
    //    if( !(val = LOCALE[ var ]) )
    //      val = LOW_LOCALE[ var ];

    if(!val)
      return "Unknown locale field: "+var;
    if( functionp( val ) )
      return val( );
    return val;
  }
}

class Scope_cf
{
  inherit RXML.Scope;
  mixed `[]  (string var, void|RXML.Context c, void|string scope)
  {
    object id = c->id;
    while( id->misc->orig ) id = id->misc->orig;
    switch( var )
    {
     case "num-dotdots":
       int depth = sizeof( (id->not_query+(id->misc->path_info||"") )/"/" )-3;
       string dotodots = depth>0?(({ "../" })*depth)*"":"./";
       return dotodots;

     case "current-url":
       return (id->not_query+(id->misc->path_info||""));
    }
  }
}

class Scope_usr
{
  inherit RXML.Scope;

#define ALIAS( X ) `[](X,c,scope)
#define QALIAS( X ) (`[](X,c,scope)?"\""+roxen_encode(`[](X,c,scope), "html")+"\"":0)
  mixed `[]  (string var, void|RXML.Context c, void|string scope)
  {
    object id = c->id;

    if( id->misc->cf_theme &&
        id->misc->cf_theme[ var ] )
      return id->misc->cf_theme[ var ];

    object c1;

    switch( var )
    {
      string q, res;
      /* composite */
     case "count-0": return "/internal-roxen-count_0";
     case "count-1": return "/internal-roxen-count_1";
     case "count-2": return "/internal-roxen-count_3";
     case "count-3": return "/internal-roxen-count_2";

     case "logo-html":
       return "<img border=\"0\" src="+QALIAS("logo")+" />";

     case "toptabs-args":
       res = "frame-image="+QALIAS("toptabs-frame");
       res += " bgcolor="+QALIAS("toptabs-bgcolor" );
       res += " font="+QALIAS("toptabs-font" );
       res += " dimcolor="+QALIAS("toptabs-dimcolor" );
       res += " textcolor="+QALIAS("toptabs-textcolor" );
       res += " dimtextcolor="+QALIAS("toptabs-dimtextcolor" );
       res += " selcolor="+QALIAS("toptabs-selcolor" );
       if( stringp( q = ALIAS("toptabs-extraargs" ) ) )
         res += " "+q;
       return res;

     case "subtabs-args":
       res ="frame-image="+QALIAS("subtabs-frame")+
           " bgcolor="+QALIAS("subtabs-bgcolor")+
           " font="+QALIAS("subtabs-font")+
           " textcolor="+QALIAS("subtabs-dimtextcolor")+
           " dimcolor="+QALIAS("subtabs-dimcolor")+
           " seltextcolor="+QALIAS("subtabs-seltextcolor")+
           " selcolor="+QALIAS("subtabs-selcolor");
       if( stringp( q = ALIAS("subtabs-extraargs" ) ) )
         res += " "+q;
       return res;

     case "body-args":
       res = "link="+QALIAS("linkcolor")+" vlink="+QALIAS("linkcolor")+
             " alink="+QALIAS("fade2")+" bgcolor="+QALIAS("bgcolor")+
             " text="+QALIAS("fgcolor");
       if( stringp(q = QALIAS( "background" )) && strlen( q ) )
         res += " background="+q;
       return res;

     case "top-tableargs":
       if( ALIAS("top-bgcolor") != "none" )
         res = "bgcolor="+QALIAS("top-bgcolor");
       else
         res="";
       if( stringp(q = QALIAS( "top-background" )) && strlen( q ) )
         res += " background="+q;
       return res;

     case "toptabs-tableargs":
       string res = "";
       if( ALIAS("toptabs-bgcolor") != "none" )
         res = "bgcolor="+QALIAS("toptabs-bgcolor");
       if( stringp(q = QALIAS( "toptabs-background" )) && strlen( q ) )
         res += " background="+q;
       if( stringp(q = QALIAS( "toptabs-align" )) && strlen( q ) )
         res += " align="+q;
       else
         res += " align=\"left\"";
       return res;

     case "subtabs-tableargs":
       res = "valign=\"bottom\" bgcolor="+QALIAS("subtabs-bgcolor");
       if( stringp(q = QALIAS( "subtabs-background" )) && strlen( q ) )
         res += " background="+q;
       if( stringp(q = QALIAS( "subtabs-align" )) && strlen( q ) )
         res += " align="+q;
       else
         res += " align=\"left\"";
       return res;

     case "left-tableargs":
       string res = "valign=\"top\" width=\"150\"";
       if( stringp(q = QALIAS( "left-background" )) && strlen( q ) )
         res += " background="+q;
       return res;

     case "content-tableargs":
       string res = " width=\"100%\" valign=\"top\"";
       if( stringp(q = QALIAS( "content-background" )) && strlen( q ) )
         res += " background="+q;
       return res;


      /* standalone, nothing is based on these. */
     case "warncolor":           return "darkred";
     case "content-toptableargs": return "";
     case "left-image":           return "/internal-roxen-unit";
     case "selected-indicator":   return "/internal-roxen-next";
     case "item-indicator":       return "/internal-roxen-dot";
     case "logo":                 return "/internal-roxen-roxen";
     case "err-1":                return "/internal-roxen-err_1";
     case "err-2":                return "/internal-roxen-err_2";
     case "err-3":                return "/internal-roxen-err_3";
     case "obox-titlefont":       return "helvetica,arial";
     case "obox-border":          return "black";


      /* 1-st level */
     case "tab-frame-image":      return "/internal-roxen-tabframe";
     case "gbutton-frame-image":  return "/internal-roxen-gbutton";

    /* also: font, bgcolor, fgcolor */

  /* 2nd level */
     case "content-titlebg":      return ALIAS( "bgcolor" );
     case "content-titlefg":      return ALIAS( "fgcolor" );
     case "gbutton-font":         return ALIAS( "font" );
     case "left-buttonframe":     return ALIAS( "gbutton-frame-image" );
     case "obox-bodybg":          return ALIAS( "bgcolor" );
     case "obox-bodyfg":          return ALIAS( "fgcolor" );
     case "obox-titlefg":         return ALIAS( "bgcolor" );
     case "subtabs-bgcolor":      return ALIAS( "bgcolor" );
     case "subtabs-dimtextcolor": return ALIAS( "bgcolor" );
     case "subtabs-frame":        return ALIAS( "tab-frame-image" );
     case "subtabs-seltextcolor": return ALIAS( "fgcolor" );
     case "tabs-font":            return ALIAS( "font" );
     case "toptabs-frame":        return ALIAS( "tab-frame-image" );
     case "toptabs-dimtextcolor": return ALIAS( "bgcolor" );
     case "toptabs-selcolor":     return ALIAS( "bgcolor" );
     case "toptabs-seltextcolor": return ALIAS( "fgcolor" );

    /* also: fade1 - fade4 */

    /* 3rd level */

     case "content-bg":           return ALIAS( "fade1" );
     case "left-buttonbg":        return ALIAS( "fade1" );
     case "left-selbuttonbg":     return ALIAS( "fade3" );
     case "obox-titlebg":         return ALIAS( "fade2" );
     case "subtabs-dimcolor":     return ALIAS( "fade2" );
     case "subtabs-font":         return ALIAS( "tabs-font" );
     case "subtabs-selcolor":     return ALIAS( "fade1" );
     case "top-bgcolor":          return ALIAS( "fade3" );
     case "top-fgcolor":          return ALIAS( "fade4" );
     case "toptabs-bgcolor":      return ALIAS( "fade3" );
     case "toptabs-dimcolor":     return ALIAS( "fade2" );
     case "toptabs-font":         return ALIAS( "tabs-font" );
    }


    if( var != "bgcolor" )
    {
      c1 = Image.Color( ALIAS("bgcolor") );
      if(!c1)
        c1 = Image.Color.black;
    }

#undef ALIAS
#undef QALIAS

    switch( var )
    {
     case "fade1":
       if( `+(0,@(array)c1) < 200 )
         return (string)Image.Color(@map(map((array)c1, `+, 0x21 ),min,255));
       return (string)Image.Color(@map(map( (array)c1, `-, 0x11 ),max,0) );

     case "fade2":
       if( `+(0,@(array)c1) < 200 )
         return (string)Image.Color( @map(map((array)c1, `+, 0x61 ),min,255));
       return (string)Image.Color( @map(map( (array)c1, `-, 0x51 ),max,0) );

     case "fade3":
       array sub = ({ 0x26, 0x21, 0x18 });
       array add = ({ 0x18, 0x21, 0x26 });
       array a =  (array)c1;
       if( `+(0,@(array)c1) < 200 )
       {
         a[0] += add[0];
         a[1] += add[1];
         a[2] += add[2];
       } else {
         a[0] -= sub[0];
         a[1] -= sub[1];
         a[2] -= sub[2];
       }
       return (string)Image.Color( @map(map(a,max,0),min,255) );

     case "fade4":
       array sub = ({ 0x87, 0x7b, 0x63 });
       array add = ({ 0x63, 0x7b, 0x87 });
       array a =  (array)c1;
       if( `+(0,@(array)c1) < 200 )
       {
         a[0] += add[0];
         a[1] += add[1];
         a[2] += add[2];
       } else {
         a[0] -= sub[0];
         a[1] -= sub[1];
         a[2] -= sub[2];
       }
       return (string)Image.Color( @map(map(a,max,0),min,255) );
    }
    return config_setting( var );
  }

  string _sprintf() { return "RXML.Scope(usr)"; }
}

RXML.Scope usr_scope=Scope_usr();
RXML.Scope locale_scope=Scope_locale();
RXML.Scope cf_scope=Scope_cf();

void set_entities(RXML.Context c)
{
  c->extend_scope("usr", usr_scope);
  c->extend_scope("locale", locale_scope);
  c->extend_scope("cf", cf_scope);
}

string get_var_form( string s, object var, object mod, object id,
                     int noset )
{
  int view_mode;

  if( mod == roxen )
  {
    if( !CU_AUTH( "Edit Global Variables" ) )
      view_mode = 1;
  } 
  else if( mod->register_module ) 
  {
    if( !CU_AUTH( "Edit Module Variables" ) )
      view_mode = 1;
  } 
  else if( mod->find_module && mod->Priority ) 
  {
    if( !CU_AUTH( "Edit Site Variables" ) )
      view_mode = 1;
  }

  if( !var->path() )
  {
    string path = "";
    if( mod->my_configuration )
      path = (mod->my_configuration()->name + "/"+
            replace(mod->my_configuration()->otomod[ mod ], "#", "!")+
            "/"+s);
    else if( mod->name )
      path = (mod->name+"/"+s);
    else
      path = s;
    var->set_path( sprintf("%x", Gmp.mpz(path, 256 ) ) );
  }
  if( !view_mode && !noset )
    var->set_from_form( id );

  string pre = var->get_warnings();

  if( pre )
    pre = "<font size='+1' color='&usr.warncolor;'><pre>"+
        html_encode_string( pre )+
        "</pre></font>";
  else
    pre = "";
  
  if( !var->check_visibility( id,
                              !!config_setting2("more_mode"),
                              !!config_setting2("expert_mode"),
                              !config_setting2("devel_mode"),
                              !!(int)id->variables->initial ) )
    return 0;

  string tmp;
  if( mod->check_variable &&
      (tmp = mod->check_variable( s, var->query() ) ))
    pre += 
        "<font size='+1' color='&usr.warncolor;'><pre>"
        + html_encode_string( tmp )
        + "</pre></font>";
  
  if( !view_mode )
    return pre + var->render_form( id );
  return pre + var->render_view( id );
}

mapping get_variable_map( string s, object mod, object id, int noset )
{
  object var = mod->variables[ s ];

  return 
  ([
    "sname":s,
    "rname": (string)var->name(),
    "doc":  (config_setting2( "docs" )?(string)var->doc():""),
    "name": (var->name()/":")[-1],
    "value":var->query(),
    "type": var->type,
    "type_hint":(config_setting2( "docs" )?var->type_hint( ):""),
    "form": get_var_form( s, var, mod, id, noset ),
  ]);
}

int var_configurable( Variable.Variable var, object id )
{
  return var->check_visibility( id,
                                config_setting2("more_mode"),
                                config_setting2("expert_mode"),
                                config_setting2("devel_mode"),
                                (int)id->variables->initial);
}

mapping get_variable_section( string s, object mod, object id )
{
  Variable.Variable var = mod->variables[ s ];

  if( !var_configurable( var,id ) )
    return 0;

  s = (string)var->name();
  if( !s ) return 0;

  if( sscanf( s, "%s:%*s", s ) )
    return ([
      "section":s,
      "selected":(id->variables->section==s?"selected":"")
    ]);
  else
    return ([
      "section":"Settings",
      "selected":
      ((id->variables->section=="Settings"||!id->variables->section)?
       "selected":""),
    ]);
  return 0;
}

array get_variable_maps( object mod, 
                         mapping m, 
                         RequestID id, 
                         int fnset )
{
  while( id->misc->orig )
    id = id->misc->orig;
  array variables = map( indices(mod->query()),
                         get_variable_map,
                         mod,
                         id,
                         fnset );

  variables = filter( variables,
                      lambda( mapping q ) {
                        return q->form && strlen(q->sname);
                      } );
  map( variables, lambda( mapping q ) {
                    if( search( q->form, "<" ) != -1 )
                      q->form=("<font size=-1>"+q->form+"</font>");
                  } );

  if( m->section && (m->section != "_all"))
  {
    if( !strlen( m->section ) || (search( m->section, "Settings" ) != -1 ))
      variables = filter( variables,
                          lambda( mapping q )
                          {
                            return search( q->rname, ":" ) == -1;
                          } );
    else
      variables = filter( variables,
                       lambda( mapping q )
                       {
                         return search( q->rname, m->section )!=-1;
                       } );
  }
  sort( variables->name, variables );

  if( !fnset )
    if( id->variables["save.x"] )
    {
      remove_call_out( mod->save );
      call_out( mod->save, 5 );
    }
  return variables;
}

array get_variable_sections( object mod, mapping m, object id )
{
  mapping w = ([]);
  array variables = map(indices(mod->variables),get_variable_section,mod,id);
  variables = Array.filter( variables-({0}),
                       lambda( mapping q ) {
                         return !w[ q->section ]++;
                       });
  sort( variables->section, variables );
  return variables;
}

object(Configuration) find_config_or_error(string config)
{
  object(Configuration) conf = roxen->find_configuration(config);
  if (!conf)
    error("Unknown configuration %O\n", config);
  return conf;
}

mapping get_port_map( object p )
{
  return ([
    "port":p->get_key(),
    "name":p->name+"://"+(p->ip||"*")+":"+p->port+"/",
  ]);
}

mapping get_url_map( string u, mapping ub )
{
  return ([
    "url":u,
    "conf":replace(ub[u]->conf->name, " ", "-" ),
    "confname":ub[u]->conf->query_name(),
  ]);
}

string container_configif_output(string t, mapping m, string c, object id)
{
  array(mapping) variables;
  switch( m->source )
  {
   case "config-settings":
     variables = get_variable_maps( id->misc->config_settings, m, id,
                                    !!m->noset);
     break;

   case "locales":
#if constant(Locale.list_languages)
     array(string) langs=Locale.list_languages("config_interface");
#else
     array(string) langs=RoxenLocale.list_languages("config_interface");
#endif
     variables = map( sort(langs),
                      lambda( string l )
                      {
                        string q = id->not_query;
                        string tmp;
                        sscanf( q, "/%[^/]/%s", tmp, q );
                        string active = roxen.locale->get();

                        return ([
                          "name":l,
                          "latin1-name":
#if constant(Standards.ISO639_2)
			  Standards.ISO639_2.get_language(l),
#else
			  RoxenLocale.ISO639_2.get_language(l),
#endif
                          "path":fix_relative( "/"+l+"/"+ q +
					       (id->misc->path_info?
						id->misc->path_info:"")+
					       (id->query&&sizeof(id->query)?
						"?" +id->query:""),
					       id),
			  "selected":( l==active ? "selected": "" ),
			  "-selected":( l==active ? "-selected": "" ),
			  "selected-int":( l==active ? "1": "0" ),
                        ]);
                      } ) - ({ 0 });
     break;

   case "global-modules":
     break;

   case "config-modules":
     object conf = find_config_or_error( m->configuration );

     variables = ({ });
     foreach( values(conf->otomod), string q )
     {
       object mi = roxen->find_module((q/"#")[0]);
       variables +=
       ({
         ([
           "sname":replace(q, "#", "!"),
           "name":mi->get_name()+((int)reverse(q)?" # "+ (q/"#")[1]:""),
           "doc":mi->get_description(),
         ]),
       });
     }
     sort( variables->name, variables );
     break;

   case "config-variables":
     object conf = find_config_or_error( m->configuration );

     variables = get_variable_maps( conf, m, id, !!m->noset);
     break;

   case "ports":
     array pos = roxen->all_ports();
     sort( pos->get_key(), pos );
     variables = map( pos, get_port_map );
     int sel;
     foreach( variables, mapping v )
       if( v->port == id->variables->port )
       {
         v->selected = "selected";
         sel=1;
       }
     break;

   case "port-variables":
     catch {
       variables = get_variable_maps( roxen->find_port( m->port ), ([]), id,
                                      !!m->noset);
     };
     break;

   case "port-urls":
     mapping u = roxen->find_port( m->port )->urls;
     variables = map(indices(u),get_url_map,u);
     break;

   case "config-variables-sections":
     object conf = find_config_or_error( m->configuration );

     variables = get_variable_sections( conf, m, id );
     break;

   case "urls":
     break;

   case "module-variables":
     object conf = find_config_or_error( m->configuration );

     object mod = conf->find_module( replace( m->module, "!", "#" ) );
     if( !mod )
       error("Unknown module "+ m->module +"\n");
     variables = get_variable_maps( mod, m, id, !!m->noset);
     break;

   case "module-variables-sections":
     object conf = find_config_or_error( m->configuration );
     object mod = conf->find_module( replace( m->module, "!", "#" ) );
     if( !mod )
       error("Unknown module "+ m->module +"\n");
     variables =get_variable_sections( mod, m, id )|  ({ ([
       "section":"Information",
       "selected":
       (((id->variables->section=="Information")||
         !id->variables->section)?
        "selected":""),
     ]) });

     if( sizeof( variables ) == 1 )
     {
       while( id->misc->orig )
         id = id->misc->orig;
       id->variables->info_section_is_it = "1";
       variables[0]->selected="selected";
     }

     int hassel;
     foreach( reverse(variables), mapping q )
     {
       if( hassel )
         q->selected = "";
       else
         hassel = strlen(q->selected);
     }
     hassel=0;
     foreach( reverse(variables), mapping q )
     {
       if( q->selected == "selected")
       {
         hassel = 1;
         break;
       }
     }
     if(!hassel)
       variables[0]->selected="selected";
     variables = reverse(variables);
     variables[0]->first = " first ";
     variables[-1]->last = " last=30 ";
     break;

   case "global-variables-sections":
     variables = get_variable_sections( roxen, m, id );
     variables[0]->last = "last";
     variables[-1]->first = "first";
     break;

   case "global-variables":
     variables = get_variable_maps( roxen, m, id, !!m->noset);
     break;


   case "configurations":
     variables = map( roxen->configurations,
                      lambda(object o ) {
                        return ([
                          "name":o->query_name(),
                          "sname":replace(lower_case(o->name),
                                          ({" ","/","%"}),
                                          ({"-","-","-"}) ),
                        ]);
                      } );

     sort(variables->name, variables);
     break;

   default:
     RXML.parse_error("Invalid output source: "+m->source+"\n");
  }
  m_delete( m, "source" );

#ifdef NSERIOUS
  return replace(do_output_tag( m, variables, c, id ), "Default Theme", "Toxic Orange");
#endif

  return do_output_tag( m, variables, c, id );
}

string container_theme_path( string t, mapping m, string c, object id )
{
  while( id->misc->orig ) id = id->misc->orig;
  if( glob( "*"+m->match, id->not_query ) )
    return c;
  return "";
}

string tag_theme_set( string t, mapping m, object id )
{
  if( !id->misc->cf_theme )
    id->misc->cf_theme = ([]);
  if( m->themefile )
    m->to = "/standard/themes/"+config_setting2( "theme" )+"/"+m->to;
  if( m->integer )
    m->to = (int)m->to;
  id->misc->cf_theme[ m->what ] = m->to;
  return "";
}

string container_rli( string t, mapping m, string c, object id )
{
  return "<tr>"
         "<td valign=top><img src=&usr.count-"+(++id->misc->_rul_cnt&3)+
         ";></td><td valign=top>"+ c+"</td></tr>\n";
}

string container_rul( string t, mapping m, string c, object id )
{
  id->misc->_rul_cnt = -1;
  return "<table>"+c+"</table>";
}

string container_cf_perm( string t, mapping m, string c, RequestID id )
{
  if( !id->misc->config_user ) return "";
  return CU_AUTH( m->perm )==!m->not ? c : "";
}

string container_cf_userwants( string t, mapping m, string c, RequestID id )
{
  return config_setting2( m->option ) ? c : "";
}
