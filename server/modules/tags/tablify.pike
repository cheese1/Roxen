// This is a roxen module. Copyright � 1996 - 1999, Idonex AB.

constant cvs_version = "$Id: tablify.pike,v 1.31 1999/08/08 19:32:56 neotron Exp $";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "roxenlib";
inherit "state";

#define old_rxml_compat 1

mixed *register_module()
{
  return ({ 
    MODULE_PARSER,
    "Tablify", 
    "This tag generates tables.<p>"
    "<tt>&lt;tablify help&gt;&lt;/tablify&gt;</tt> gives help.\n\n<p>",
    0, 1, });
}

string encode_url(int col, int state, string state_id, object id){
  if(col==abs(state))
    state=-1*state;
  else
    state=col;

  return id->not_query+"?state="+
    replace(preview_altered_state(id, state_id, state),({"+","/","="}),({"-","!","*"}));
}


string html_nice_table(array subtitles, array table, mapping opt, object id)
{
  string r = "",type;

  int m = (int)opt->modulo || 1;
  if(opt->nice || opt->nicer)
    r+="<table bgcolor=\""+(opt->bordercolor||"#000000")+"\" border=\"0\" "
       "cellspacing=\"0\" cellpadding=\"1\">\n"
       "<tr><td>\n"
       "<table border=\""+(opt->border||"0")+"\" cellspacing=\""+(opt->cellspacing||"0")+
       "\" cellpadding=\""+(opt->cellpadding||"4")+"\">\n";

  if (subtitles) {
    int col=0;
    r += "<tr bgcolor=\""+(opt->titlebgcolor||"#112266")+"\">\n";
    foreach(subtitles, string s) {
      col++;
      r+="<th align=\"left\">"+(opt["interactive-sort"]?"<a href=\""+encode_url(col,opt->is,opt->state_id,id)+"\">":"");
      if(opt->nicer)
        r+="<gtext nfont=\""+(opt->font||"lucida")+"\" scale=\""+
	   (opt->scale||"0.36")+"\" fg=\""+(opt->titlecolor||"white")+"\" bg=\""+
	   (opt->titlebgcolor||"#27215b")+"\""+(opt->noxml?" noxml":"")+">"+s+"</gtext>";
      else
        r+="<font color=\""+(opt->titlecolor||"#ffffff")+"\">"+s+"</font>";
      r+=(opt["interactive-sort"]?(abs(opt->is)==col?"<img hspace=\"5\" src=\"internal-roxen-sort-"+
        (opt->is<0?"asc":"desc")+"\" border=\"0\">":"")+
        "</a>":"")+"&nbsp;</th>";
    }
    if(col<id->misc->tmp_colmax) r+="<td colspan=\""+(id->misc->tmp_colmax-col)+"\">&nbsp;</td>";
    r += "</tr>\n";
  }

  for(int i = 0; i < sizeof(table); i++) {
    if(opt->nice || opt->nicer)
      r+="<tr bgcolor=\""+((i/m)%2?opt->evenbgcolor||"#ddeeff":opt->oddbgcolor||"#ffffff")+"\">";
    else
      r+="<tr>";

    for(int j = 0; j < sizeof(table[i]); j++) {
      mixed s = table[i][j];
      type=arrayp(opt->fields) && j<sizeof(opt->fields)?opt->fields[j]:"text";
      switch(type){

      case "economic-float":
      case "float":
	array a = s/".";
        string font="",nofont="";
        if(opt->nicer || type=="economic-float"){
          font="<font color=\""+
            (type=="economic-float"?((int)a[0]<0?"#ff0000":"#000000"):(opt->textcolor||"#000000"))+
            "\""+(opt->nicer?(" size=\""+(opt->size||"2")+
            "\" face=\""+(opt->face||"helvetica,arial")+"\">"):">");
          nofont="</font>";
	}

        //The right way<tm> is to preparse the whole column and find the longest string of
        //decimals and use that to calculate the maximum with of the decimal cell, insted
        //of just saying widht=30, which easily produces an ugly result.
        r+="<td align=\"right\"><table border=\"0\" cellpadding=\"0\" cellspacing=\"0\"><tr><td align=\"right\">"+
          font+a[0]+nofont+"</td><td>"+font+"."+nofont+"</td><td align=\"left\" width=\"30\">"+font+
          (sizeof(a)>1?a[1]:"0")+nofont;

        r += "</td></tr></table>";
	break;

      case "economic-int":
      case "int":
        string font="",nofont="";
        if(opt->nicer || type=="economic-int"){
          font="<font color=\""+
            (type=="economic-int"?((int)s<0?"#ff0000":"#000000"):(opt->textcolor||"#000000"))+
            "\""+(opt->nicer?(" size=\""+(opt->size||"2")+
            "\" face=\""+(opt->face||"helvetica,arial")+"\">"):">");
          nofont="</font>";
	}

        r+="<td align=\"right\">"+font+(string)(int)round((float)s)+nofont;
	break;

#if old_rxml_compat
      case "num":
        type="right";
#endif
      case "text":
      case "left":
      case "right":
      case "center":
      default:
        r += "<td align=\""+(type!="text"?type:(opt->cellalign||"left"))+"\" valign=\""+(opt->cellvalign||"top")+"\">";
	if(opt->nicer) r += "<font color=\""+(opt->textcolor||"#000000")+"\" size=\""+(opt->size||"2")+
          "\" face=\""+(opt->face||"helvetica,arial")+"\">";
        r += s+(opt->nice||opt->nicer?"&nbsp;&nbsp;":"");
        if(opt->nicer) r+="</font>";
      }

      r += "</td>";
    }
    if(sizeof(table[i])<id->misc->tmp_colmax) r+="<td colspan=\""+(id->misc->tmp_colmax-sizeof(table[i]))+"\">&nbsp;</td>";
    r += "</tr>\n";
  }

  m_delete(id->misc, "tmp_colmax");
  if(opt->nice || opt->nicer)
    return r+"</table></td></tr>\n</table>"+(opt->noxml?"<br>":"<br />")+"\n";

  m_delete(opt, "cellalign");
  m_delete(opt, "cellvalign");
  m_delete(opt, "fields");
  return make_container("table",opt,r);
}

string container_fields(string name, mapping arg, string q, mapping m, mapping arg_list)
{
  arg_list->fields = q/(arg->separator||m->cellseparator||"\t");
  return "";
}

string tag_tablify(string tag, mapping m, string q, object id)
{
  array rows, res;
  string sep;

#if old_rxml_compat
  // RXML <1.4 compatibility stuff
  if(m->fgcolor0) {
    m->oddbgcolor=m->fgcolor0;
    m_delete(m, "fgcolor0");
    id->conf->api_functions()->old_rxml_warning[0](id, "tablify attribute fgcolor0","oddbgcolor");
  }
  if(m->fgcolor1) {
    m->evenbgcolor=m->fgcolor1;
    m_delete(m, "fgcolor1");
    id->conf->api_functions()->old_rxml_warning[0](id, "tablify attribute fgcolor1","evenbgcolor");
  }
  if(m->fgcolor) {
    m->textcolor=m->fgcolor;
    m_delete(m, "fgcolor");
    id->conf->api_functions()->old_rxml_warning[0](id, "tablify attribute fgcolor","textcolor");
  }
  if(m->rowalign) {
    m->cellalign=m->rowalign;
    m_delete(m, "rowalign");
    id->conf->api_functions()->old_rxml_warning[0](id, "tablify attribute rowalign","cellalign");
  }
  // When people have forgotten what bgcolor meant we can reuse it as evenbgcolor=oddbgcolor=m->bgcolor
  if(m->bgcolor) {
    m->bordercolor=m->bgcolor;
    m_delete(m, "bgcolor");
    id->conf->api_functions()->old_rxml_warning[0](id, "tablify attribute bgcolor","bordercolor");
  }
#endif

  if(m->help) return register_module()[2];

  if (m->preprocess || m->parse) {
    q = parse_rxml(q, id);
  }
  mapping arg_list = ([]);
  q = parse_html(q, ([]), (["fields":container_fields]), m, arg_list);

  sep = m->rowseparator||"\n";
  m_delete(m,"rowseparator");

  rows = (q / sep) - ({""});

  sep = m->cellseparator||"\t";

  array title;
  if((m->nice||m->nicer) && (!m->notitle)) {
    title = rows[0]/sep;
    rows = rows[1..];
  }

  if(m->min)
    rows = rows[((int)m->min)..];
  if(m->max)
    rows = rows[..((int)m->max-1)];

  id->misc->tmp_colmax=0;
  rows = Array.map(rows,lambda(string r, string s){
			  array t=r/s;
			  if(sizeof(t)>id->misc->tmp_colmax) id->misc->tmp_colmax=sizeof(t);
			  return t;
			}, sep);

  arg_list+=(["is":(int)m->sortcol]);
  if((int)m->sortcol>0) sort(column(rows,(int)m->sortcol-1),rows);
  if(m["interactive-sort"]) {
    string state_id="";
    state_id = register_state_consumer((m->name || "tb")+sizeof(rows), id);
    arg_list+=(["is":0,"state_id":state_id]);
    if(id->variables->state){
      decode_state(replace(id->variables->state,({"-","!","*"}),({"+","/","="})), id);
      arg_list->is=get_state(state_id,id);
    }
  }

  if(arg_list->is!=0) {
    sort(column(rows,abs(arg_list->is)-1),rows);
    if(arg_list->is<0)
      rows=reverse(rows);
  }

  return html_nice_table(title, rows, m + arg_list, id);
}

mapping query_container_callers()
{
  return ([ "tablify" : tag_tablify ]);
}

mapping query_tag_callers()
{
  return ([]);
}

