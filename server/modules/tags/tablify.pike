// This is a roxen module. Copyright � 1996 - 2000, Roxen IS.

constant cvs_version = "$Id: tablify.pike,v 1.43 2000/02/24 03:54:42 nilsson Exp $";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "roxenlib";
inherit "state";

constant module_type = MODULE_PARSER;
constant module_name = "Tablify";
constant module_doc  = "This tag generates tables.<p>"
  "<tt>&lt;tablify help&gt;&lt;/tablify&gt;</tt> gives help.\n\n</p>";

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=(["tablify":({#"<desc cont>Transforms texts into tables. No attributes required.</desc>

<attr name=rowseparator value=string>Defines the rowseparator. Default is a newline.</attr>
<attr name=cellseparator value=string>Defines the cellseparaotr. Default is a tab.</attr>
<attr name=border value=int>Defines the width of the border. Default is 2 in
 nice and nicer modes. Otherwise undefined.</attr>
<attr name=cellspacing value=int>Defines the cellspacing attribute. Default is 0 in
 nice and nicer modes. Otherwise undefined.</attr>
<attr name=cellpadding value=int>Defines the cellpadding attribute. Default is 4 in
 nice and nicer modes. Otherwise undefined.</attr>
<attr name=interactive-sort>Makes it possible for the user to sort the table with
 respect to any column.</attr>
<attr name=sortcol value=int>Defines which column to sort the table with respect to.
 The leftmost column is number 1. Negative value indicate reverse sort order.</attr>
<attr name=min value=int>Indicates which of the inputed rows should be the first to
 be displayed. The first row is number 1.</attr>
<attr name=max value=int>Indicates which of the inputed rows should be the last to
 be displayed.</attr>
<attr name=negativecolor value=color>The color of negative values in economic fields. Default is #ff0000.</attr>
<attr name=cellalign value=left,center,right>Defines how the cell contents should be align by default.</attr>
<attr name=cellvalign value=top,middle,bottom>Defines how the cell contents should be verically aligned.</attr>
<hr>
<attr name=nice>Add some extra layout to the table. All attributes below
 only applies in nice or nicer mode.</attr>
<attr name=grid value=int>Draws a grid with the thickness given.</attr>
<attr name=notitle>Don't add a title to each column.</attr>
<attr name=bordercolor value=color>The colour of the border. Default is #000000.</attr>
<attr name=titlebgcolor value=color>The background colour of the title. Default is #112266.</attr>
<attr name=titlecolor value=color>The colour of the title. Default is #ffffff.</attr>
<attr name=modulo value=int>Defines how many rows in a row should have the same colour.</attr>
<attr name=oddbgcolor value=color>The first background color. Default is #ffffff.</attr>
<attr name=evenbgcolor value=color>The second background color. Default is #ddeeff.</attr>
<hr>
<attr name=nicer>Add some extra extra layout to the table. All attributes
 below only applies in nicer mode. Nicer requires the gtext module.</attr>
<attr name=noxml>Don't terminate the gifs with slashes.</attr>
<attr name=font value=text>Gtext font to write the column titles with. Default is 'lucida'.</attr>
<attr name=scale value=float>Size of the gtext font to write the column titles with. Default is 0.36</attr>
<attr name=textcolor value=color>The color of the text. This will also work with economic fields in any mode.
 Default is #000000.</attr>
<attr name=size value=int>The size of the table text. Default is 2.</attr>
<attr name=font value=string>The font of the table text. Default is 'helvetica,arial'</attr>",
  (["fields":#"<desc cont>The container 'fields' may be used inside the tablify container to describe
   the type of contents the fields in a column has. Avaiable fields are<br>

   <ul>
   <li>text (default)</li>
   <li>left</li>
   <li>center</li>
   <li>right</li>
   <li>num</li>
   <li>int</li>
   <li>economic-int</li>
   <li>float</li>
   <li>economic-float</li>
   </ul>

   All fields except text overrides the cellvalign attribute.</desc>


  <attr name=separator value=string>Defines the field type separator.</attr>

  The fields types are separated by
  <ol>
  <li>The value given in the separator attribute to fields.</li>
  <li>The value given in the cellseparator attribute to tablify.</li>
  <li>Tab.</li>
  </ol>"])
})]);
#endif

string encode_url(int col, int state, object stateobj, RequestID id){
  if(col==abs(state))
    state=-1*state;
  else
    state=col;

  return id->not_query+"?state="+
    stateobj->uri_encode(state);
}

string make_table(array subtitles, array table, mapping opt, RequestID id)
{
  string r = "",type;

  int m = (int)opt->modulo || 1;
  if(opt->nice || opt->nicer)
    r+="<table bgcolor=\""+(opt->bordercolor||"#000000")+"\" border=\"0\" "
       "cellspacing=\"0\" cellpadding=\""+(opt->border||"1")+"\">\n"
       "<tr><td>\n"
       "<table border=\""+(opt->grid||"0")+"\" cellspacing=\""+(opt->cellspacing||"0")+
       "\" cellpadding=\""+(opt->cellpadding||"4")+"\">\n";

  if (subtitles) {
    int col=0;
    if(opt->nice || opt->nicer)
      r+="<tr bgcolor=\""+(opt->titlebgcolor||"#112266")+"\">\n";
    else
      r+="<tr>";
    foreach(subtitles, string s) {
      col++;
      r+="<th align=\"left\">"+(opt["interactive-sort"]?"<a href=\""+encode_url(col,opt->sortcol||0,opt->state,id)+"\">":"");
      if(opt->nicer)
        r+="<gtext nfont=\""+(opt->font||"lucida")+"\" scale=\""+
	   (opt->scale||"0.36")+"\" fg=\""+(opt->titlecolor||"white")+"\" bg=\""+
	   (opt->titlebgcolor||"#112266")+"\""+(opt->noxml?" noxml":"")+">"+s+"</gtext>";
      else if(opt->nice)
        r+="<font color=\""+(opt->titlecolor||"#ffffff")+"\">"+s+"</font>";
      else
        r+=s;
      r+=(opt["interactive-sort"]?(abs(opt->sortcol||0)==col?"<img hspace=\"5\" src=\"internal-roxen-sort-"+
        (opt->sortcol<0?"asc":"desc")+"\" border=\"0\">":"")+
        "</a>":"")+"&nbsp;</th>";
    }
    if(col<id->misc->tmp_colmax) r+="<td colspan=\""+(id->misc->tmp_colmax-col)+"\">&nbsp;</td>";
    r += "</tr>\n";
  }

  for(int i = 0; i < sizeof(table); i++) {
    if(opt->nice || opt->nicer)
      r+="<tr bgcolor=\""+((i/m)%2?opt->evenbgcolor||"#ddeeff":opt->oddbgcolor||"#ffffff")+"\"";
    else
      r+="<tr";
    r+=opt->cellvalign?" valign=\""+opt->cellvalign+"\">":">";

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
            (type=="economic-float"?((int)a[0]<0?(opt->negativecolor||"#ff0000"):(opt->textcolor||"#000000")):
              (opt->textcolor||"#000000"))+
            "\""+(opt->nicer?(" size=\""+(opt->size||"2")+
            "\" face=\""+(opt->face||"helvetica,arial")+"\">"):">");
          nofont="</font>";
	}

        //The right way<tm> is to preparse the whole column and find the longest string of
        //decimals and use that to calculate the maximum width of the decimal cell, insted
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
            (type=="economic-int"?((int)s<0?(opt->negativecolor||"#ff0000"):(opt->textcolor||"#000000")):
              (opt->textcolor||"#000000"))+
            "\""+(opt->nicer?(" size=\""+(opt->size||"2")+
            "\" face=\""+(opt->face||"helvetica,arial")+"\">"):">");
          nofont="</font>";
	}

        r+="<td align=\"right\">"+font+(string)(int)round((float)s)+nofont;
	break;

      case "num":
        type="right";
      case "text":
      case "left":
      case "right":
      case "center":
      default:
        r += "<td align=\""+(type!="text"?type:(opt->cellalign||"left"))+"\">";
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
    return r+"</table></td></tr>\n</table>\n";

  m_delete(opt, "cellalign");
  m_delete(opt, "cellvalign");
  m_delete(opt, "fields");
  m_delete(opt, "state");
  return make_container("table",opt,r);
}

string _fields(string name, mapping arg, string q, mapping m)
{
  m->fields = q/(arg->separator||m->cellseparator||"\t");
  return "";
}

string container_tablify(string tag, mapping m, string q, RequestID id)
{
  array rows, res;
  string sep;

  q = parse_html(q, ([]), (["fields":_fields]), m);

  if(m->intable) {
    q=`-(q,"\n","\r","\t");
    m_delete(m, "rowseparator");
    m_delete(m, "cellseparator");
    if(!m->notitle) m+=(["notitle":1]);
    q=parse_html(q, ([]), (["table":lambda(string name, mapping arg, string q, mapping m) {
				      if(arg->border) m->border=arg->border;
				      if(arg->cellspacing) m->cellspacing=arg->cellspacing;
				      if(arg->cellpadding) m->cellpadding=arg->cellpadding;
				      return q;
				    },
			    "tr":lambda(string name, mapping arg, string q, mapping m) {
				   return q+"\n";
				 },
			    "td":lambda(string name, mapping arg, string q, mapping m) {
				   return q+"\t";
				 },
			    "th":lambda(string name, mapping arg, string q, mapping m) {
                                   if(m->notitle && m->notitle==1) m_delete(m, "notitle");
				   return q+"\t";
				 }
    ]), m);
  }

  sep = m->rowseparator||"\n";
  m_delete(m,"rowseparator");

  rows = (q / sep) - ({""});

  sep = m->cellseparator||"\t";
  m_delete(m,"cellseparator");

  array title;
  if(!m->notitle && sizeof(rows)>1) {
    title = rows[0]/sep;
    rows = rows[1..];
  }

  id->misc->tmp_colmax=0;
  rows = Array.map(rows,lambda(string r, string s){
			  array t=r/s;
			  if(sizeof(t)>id->misc->tmp_colmax) id->misc->tmp_colmax=sizeof(t);
			  return t;
			}, sep);

  if(m["interactive-sort"]) {
    m->state=Page_state(id);
    m->state->register_consumer((m->name || "tb")+sizeof(rows), id);
    m->sortcol=(int)m->sortcol;
    if(id->variables->state){
      m->state->uri_decode(id->variables->state);
      m->sortcol=m->state->get()||m->sortcol;
    }
  }

  if((int)m->sortcol) {
    int sortcol=abs((int)m->sortcol)-1,num=0;
    if(m->fields && sortcol+1<sizeof(m->fields)) {
      switch(m->fields[sortcol]) {
      case "num":
      case "int":
      case "economic-int":
      case "float":
      case "economic-float":
        rows = Array.map(rows, lambda(array a, int c) { return ({ (float)a[c] })+a; }, sortcol);
        sortcol=0;
        num=1;
      }
    }
    sort(column(rows,sortcol),rows);
    if((int)m->sortcol<0)
      rows=reverse(rows);
    if(num)
      rows = Array.map(rows, lambda(array a) { return a[1..]; });
  }

  if(m->min || m->max) {
    m->min=m->min?(int)m->min-1:0;
    m->max=m->max?(int)m->max-1:sizeof(rows)-1;
    if(m->max < m->min) RXML.parse_error("Min attribute greater than the max attribute.");
    rows = rows[m->min..m->max];
    m_delete(m,"min");
    m_delete(m,"max");
  }

  return make_table(title, rows, m, id);
}
